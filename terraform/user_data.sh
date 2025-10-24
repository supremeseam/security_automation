#!/bin/bash -xe

# Redirect all output to a log file for debugging. This is crucial.
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Update and install dependencies
echo "Installing dependencies on Amazon Linux 2023..."
dnf update -y
dnf install -y git python3-pip nodejs mariadb105 unzip jq

# Install pip for python3
# On AL2023, python3-pip is sufficient and get-pip.py is not needed.

# Install AWS CLI v2 (needed for secrets manager)
# AL2023 comes with AWS CLI v2, so we just ensure it's up-to-date.
echo "AWS CLI is pre-installed. Skipping manual installation."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Define app directory
APP_DIR="/opt/automation-ui"

# Get secrets from AWS Secrets Manager
SECRET_ARN="${secret_arn}"
AWS_REGION="${aws_region}"

get_secret() {
    aws secretsmanager get-secret-value --secret-id $SECRET_ARN --region $AWS_REGION --query SecretString --output text
}

# Retry logic for getting secrets (in case secret version isn't ready yet)
echo "Retrieving secrets from AWS Secrets Manager..."
MAX_RETRIES=30
RETRY_COUNT=0
SECRETS_JSON=""

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    SECRETS_JSON=$(get_secret)
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

# Extract secrets
DB_HOST=$(echo "$SECRETS_JSON" | jq -r .db_host)
DB_PORT=$(echo "$SECRETS_JSON" | jq -r .db_port)
DB_NAME=$(echo "$SECRETS_JSON" | jq -r .db_name)
DB_USER=$(echo "$SECRETS_JSON" | jq -r .db_username)
DB_PASSWORD=$(echo "$SECRETS_JSON" | jq -r .db_password)
SECRET_KEY=$(echo "$SECRETS_JSON" | jq -r .secret_key)
GIT_REPO_URL=$(echo "$SECRETS_JSON" | jq -r .git_repo_url)

# Clone the application repository
cd /opt
git clone $GIT_REPO_URL $APP_DIR
cd $APP_DIR/app

# Create .env file
cat > .env << EOF
DB_HOST=$${DB_HOST}
DB_PORT=$${DB_PORT}
DB_NAME=$${DB_NAME}
DB_USER=$${DB_USER}
DB_PASSWORD=$${DB_PASSWORD}
SECRET_KEY=$${SECRET_KEY}
EOF

# Install Python and Node.js dependencies
pip3 install -r requirements.txt
npm install
npm run build

# Wait for DB to be ready and run setup script
echo "Waiting for database to become available..."
while ! mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD -e "SELECT 1"; do
    sleep 5
done

echo "Database is up. Running setup script."
mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME < database_setup.sql

# Create a systemd service to run the Flask app
cat > /etc/systemd/system/automation-ui.service << EOF
[Unit]
Description=Python Automation UI Service
After=network.target

[Service]
User=ec2-user
Group=ec2-user
EnvironmentFile=$${APP_DIR}/app/.env
WorkingDirectory=$${APP_DIR}/app
ExecStart=/usr/bin/python3 $${APP_DIR}/app/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Change ownership of the app directory to the user that will run the service
chown -R ec2-user:ec2-user $${APP_DIR}

# Start and enable the service
systemctl daemon-reload
systemctl start automation-ui.service
systemctl enable automation-ui.service