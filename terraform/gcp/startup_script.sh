#!/bin/bash -xe

# Redirect all output to a log file for debugging
exec > >(tee /var/log/startup-script.log) 2>&1

echo "=== Starting application deployment on GCP Compute Engine ==="
echo "Timestamp: $(date)"

# Update and install dependencies for Debian
echo "Installing dependencies on Debian..."
apt-get update
apt-get install -y git python3-pip python3-venv nodejs npm default-mysql-client jq curl nginx certbot python3-certbot-nginx

# Install Google Cloud SDK if not present (usually pre-installed on GCP VMs)
if ! command -v gcloud &> /dev/null; then
    echo "Installing Google Cloud SDK..."
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    apt-get update && apt-get install -y google-cloud-sdk
fi

# Define app directory
APP_DIR="/opt/automation-ui"

# GCP Secret Manager configuration
SECRET_NAME="${secret_name}"
GCP_PROJECT="${gcp_project}"
DOMAIN_NAME="${domain_name}"
SSL_EMAIL="${ssl_email}"
ENABLE_SSL="${enable_ssl}"

# Function to get secret from GCP Secret Manager
get_secret() {
    gcloud secrets versions access latest --secret="$SECRET_NAME" --project="$GCP_PROJECT"
}

# Retry logic for getting secrets
echo "Retrieving secrets from GCP Secret Manager..."
MAX_RETRIES=30
RETRY_COUNT=0
SECRETS_JSON=""

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    SECRETS_JSON=$(get_secret 2>&1)
    if [ $? -eq 0 ] && [ -n "$SECRETS_JSON" ]; then
        echo "Successfully retrieved secrets."
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Attempt $RETRY_COUNT/$MAX_RETRIES failed. Retrying in 10 seconds..."
    sleep 10
done

if [ -z "$SECRETS_JSON" ]; then
    echo "ERROR: Failed to retrieve secrets after $MAX_RETRIES attempts."
    exit 1
fi

# Extract secrets from JSON
DB_HOST=$(echo "$SECRETS_JSON" | jq -r .db_host)
DB_PORT=$(echo "$SECRETS_JSON" | jq -r .db_port)
DB_NAME=$(echo "$SECRETS_JSON" | jq -r .db_name)
DB_USER=$(echo "$SECRETS_JSON" | jq -r .db_username)
DB_PASSWORD=$(echo "$SECRETS_JSON" | jq -r .db_password)
SECRET_KEY=$(echo "$SECRETS_JSON" | jq -r .secret_key)
GIT_REPO_URL=$(echo "$SECRETS_JSON" | jq -r .git_repo_url)

# Create application user if it doesn't exist
if ! id -u automation-user > /dev/null 2>&1; then
    echo "Creating automation-user..."
    useradd -m -s /bin/bash automation-user
fi

# Clone the application repository
echo "Cloning application repository..."
mkdir -p /opt
cd /opt

# If directory exists, remove it first
if [ -d "$APP_DIR" ]; then
    rm -rf "$APP_DIR"
fi

git clone "$GIT_REPO_URL" "$APP_DIR"
cd "$APP_DIR/app"

# Create .env file
echo "Creating .env configuration file..."
cat > .env << EOF
DB_HOST=$${DB_HOST}
DB_PORT=$${DB_PORT}
DB_NAME=$${DB_NAME}
DB_USER=$${DB_USER}
DB_PASSWORD=$${DB_PASSWORD}
SECRET_KEY=$${SECRET_KEY}
EOF

# Change ownership of app directory
chown -R automation-user:automation-user "$APP_DIR"

# Install Python dependencies
echo "Installing Python dependencies..."
sudo -u automation-user pip3 install --user -r requirements.txt --break-system-packages

# Verify gunicorn installation
echo "Verifying gunicorn installation..."
sudo -u automation-user python3 -m pip show gunicorn --break-system-packages || {
    echo "Gunicorn not found, installing explicitly..."
    sudo -u automation-user pip3 install --user gunicorn --break-system-packages
}

# Install Node.js dependencies and build TypeScript
echo "Installing Node.js dependencies..."
sudo -u automation-user npm install

echo "Building TypeScript..."
sudo -u automation-user npm run build

# Clean up package caches to free up space
echo "Cleaning up package caches..."
apt-get clean
sudo -u automation-user npm cache clean --force
rm -rf /home/automation-user/.cache/pip
rm -rf /var/cache/apt/archives/*

# Wait for Cloud SQL to be ready
echo "Waiting for Cloud SQL database to become available..."
MAX_DB_RETRIES=60
DB_RETRY_COUNT=0

while [ $DB_RETRY_COUNT -lt $MAX_DB_RETRIES ]; do
    if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1" 2>/dev/null; then
        echo "Database is ready!"
        break
    fi
    DB_RETRY_COUNT=$((DB_RETRY_COUNT + 1))
    echo "Database not ready yet. Attempt $DB_RETRY_COUNT/$MAX_DB_RETRIES. Waiting 5 seconds..."
    sleep 5
done

if [ $DB_RETRY_COUNT -eq $MAX_DB_RETRIES ]; then
    echo "ERROR: Database did not become available within the timeout period."
    exit 1
fi

# Run database setup script
echo "Running database setup script..."
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < database_setup.sql

if [ $? -eq 0 ]; then
    echo "Database setup completed successfully."
else
    echo "ERROR: Database setup failed."
    exit 1
fi

# Create systemd service for the Flask application
echo "Creating systemd service..."
cat > /etc/systemd/system/automation-ui.service << EOF
[Unit]
Description=Python Automation UI Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=automation-user
Group=automation-user
EnvironmentFile=$${APP_DIR}/app/.env
WorkingDirectory=$${APP_DIR}/app
Environment="PATH=/home/automation-user/.local/bin:/usr/local/bin:/usr/bin:/bin"
Environment="PYTHONPATH=/home/automation-user/.local/lib/python3.11/site-packages"
ExecStart=/usr/bin/python3 -m gunicorn --workers 3 --bind 127.0.0.1:5000 --timeout 120 --access-logfile - --error-logfile - app:app
Restart=always
RestartSec=10

# Security settings
NoNewPrivileges=true
PrivateTmp=true

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=automation-ui

[Install]
WantedBy=multi-user.target
EOF

# Start the Flask application
echo "Starting automation-ui service..."
systemctl daemon-reload
systemctl enable automation-ui.service
systemctl start automation-ui.service

# Wait for service to start
sleep 5

if ! systemctl is-active --quiet automation-ui.service; then
    echo "ERROR: Automation UI service failed to start!"
    journalctl -u automation-ui.service -n 50 --no-pager
    exit 1
fi

# Configure Nginx as reverse proxy
echo "Configuring Nginx..."

# Remove default site
rm -f /etc/nginx/sites-enabled/default

# Create Nginx configuration
cat > /etc/nginx/sites-available/automation-ui << 'NGINXEOF'
server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN_PLACEHOLDER;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logging
    access_log /var/log/nginx/automation-ui-access.log;
    error_log /var/log/nginx/automation-ui-error.log;

    # Proxy settings
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;

        # WebSocket support (if needed in future)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Static files (served directly by Nginx for better performance)
    location /static {
        alias /opt/automation-ui/app/static;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
NGINXEOF

# Get external IP
EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)

# Configure server_name based on whether SSL is enabled
if [ "$ENABLE_SSL" = "true" ] && [ -n "$DOMAIN_NAME" ]; then
    echo "SSL is enabled. Setting server_name to: $DOMAIN_NAME"
    sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN_NAME/g" /etc/nginx/sites-available/automation-ui
else
    echo "SSL not enabled. Setting server_name to: $EXTERNAL_IP _"
    sed -i "s/DOMAIN_PLACEHOLDER/$EXTERNAL_IP _/g" /etc/nginx/sites-available/automation-ui
fi

# Enable the site
ln -sf /etc/nginx/sites-available/automation-ui /etc/nginx/sites-enabled/

# Test Nginx configuration
echo "Testing Nginx configuration..."
nginx -t

if [ $? -ne 0 ]; then
    echo "ERROR: Nginx configuration test failed!"
    exit 1
fi

# Start Nginx
echo "Starting Nginx..."
systemctl restart nginx
systemctl enable nginx

# Setup SSL with Let's Encrypt if enabled
if [ "$ENABLE_SSL" = "true" ] && [ -n "$DOMAIN_NAME" ] && [ -n "$SSL_EMAIL" ]; then
    echo "Setting up SSL certificate with Let's Encrypt..."
    echo "Domain: $DOMAIN_NAME"
    echo "Email: $SSL_EMAIL"

    # Wait a bit for Nginx to be fully ready
    sleep 5

    # Run certbot
    certbot --nginx \
        --non-interactive \
        --agree-tos \
        --email "$SSL_EMAIL" \
        --domains "$DOMAIN_NAME" \
        --redirect

    if [ $? -eq 0 ]; then
        echo "SUCCESS: SSL certificate installed successfully!"

        # Setup automatic renewal
        systemctl enable certbot.timer
        systemctl start certbot.timer

        echo "SSL certificate auto-renewal enabled via systemd timer"
    else
        echo "WARNING: SSL certificate installation failed. Application is still accessible via HTTP."
        echo "Make sure your domain DNS points to: $EXTERNAL_IP"
        echo "You can manually run: certbot --nginx -d $DOMAIN_NAME"
    fi
else
    echo "SSL not configured. Application will be accessible via HTTP only."
    if [ "$ENABLE_SSL" = "true" ]; then
        echo "To enable SSL, you need to set domain_name and ssl_email variables."
    fi
fi

# Final service check
sleep 3

if systemctl is-active --quiet automation-ui.service && systemctl is-active --quiet nginx; then
    echo ""
    echo "=========================================="
    echo "Deployment complete!"
    echo "=========================================="

    if [ "$ENABLE_SSL" = "true" ] && [ -n "$DOMAIN_NAME" ]; then
        echo "HTTPS URL: https://$DOMAIN_NAME"
        echo "HTTP URL (redirects to HTTPS): http://$DOMAIN_NAME"
    else
        echo "Application URL: http://$EXTERNAL_IP"
    fi

    echo ""
    echo "Direct Flask access (if needed): http://$EXTERNAL_IP:5000"
    echo "SSH: ssh -i <key-file> automation-user@$EXTERNAL_IP"
    echo "=========================================="
else
    echo "ERROR: One or more services failed to start!"
    echo "Flask service status:"
    systemctl status automation-ui.service --no-pager
    echo ""
    echo "Nginx status:"
    systemctl status nginx --no-pager
    exit 1
fi

echo "=== Startup script completed successfully ==="
