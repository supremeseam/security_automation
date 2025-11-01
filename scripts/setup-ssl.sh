#!/bin/bash
# Manual SSL Setup Script for automation.anchortechconsultants.com

set -e

DOMAIN_NAME="automation.anchortechconsultants.com"
EMAIL="admin@automation.anchortechconsultants.com"

echo "============================================"
echo "SSL Certificate Setup"
echo "============================================"
echo "Domain: $DOMAIN_NAME"
echo "Email: $EMAIL"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

# Check DNS resolution
echo "1. Checking DNS resolution..."
RESOLVED_IP=$(dig +short $DOMAIN_NAME | tail -n1)
CURRENT_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "   Domain resolves to: $RESOLVED_IP"
echo "   Instance IP is: $CURRENT_IP"

if [ "$RESOLVED_IP" != "$CURRENT_IP" ]; then
    echo "   WARNING: DNS mismatch! SSL certificate generation may fail."
    echo "   Update your DNS A record to point to: $CURRENT_IP"
    read -p "   Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "   ✓ DNS is correctly configured"
fi

# Check if Nginx is running
echo ""
echo "2. Checking Nginx status..."
if systemctl is-active --quiet nginx; then
    echo "   ✓ Nginx is running"
else
    echo "   ✗ Nginx is not running. Starting..."
    systemctl start nginx
fi

# Check if certbot is installed
echo ""
echo "3. Checking Certbot installation..."
if command -v certbot &> /dev/null; then
    CERTBOT_PATH=$(which certbot)
    echo "   ✓ Certbot found at: $CERTBOT_PATH"
else
    echo "   ✗ Certbot not found. Installing..."
    python3 -m pip install certbot certbot-nginx
    CERTBOT_PATH=$(which certbot)
    echo "   ✓ Certbot installed at: $CERTBOT_PATH"
fi

# Check current certificate status
echo ""
echo "4. Checking existing certificates..."
if [ -d "/etc/letsencrypt/live/$DOMAIN_NAME" ]; then
    echo "   Certificate already exists for $DOMAIN_NAME"
    certbot certificates
    read -p "   Renew certificate? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        certbot renew --force-renewal --cert-name $DOMAIN_NAME
    fi
else
    echo "   No existing certificate found"
fi

# Obtain SSL certificate
echo ""
echo "5. Obtaining SSL certificate from Let's Encrypt..."
certbot certonly --nginx \
    --non-interactive \
    --agree-tos \
    --email $EMAIL \
    --domains $DOMAIN_NAME \
    --keep-until-expiring

if [ $? -eq 0 ]; then
    echo "   ✓ SSL certificate obtained successfully!"
else
    echo "   ✗ Failed to obtain SSL certificate"
    echo ""
    echo "   Troubleshooting:"
    echo "   1. Check DNS: nslookup $DOMAIN_NAME"
    echo "   2. Check if port 80 is accessible from the internet"
    echo "   3. Check Nginx logs: sudo tail -f /var/log/nginx/error.log"
    echo "   4. Check Certbot logs: sudo cat /var/log/letsencrypt/letsencrypt.log"
    exit 1
fi

# Verify certificate files exist
echo ""
echo "6. Verifying certificate files..."
if [ -f "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" ] && [ -f "/etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem" ]; then
    echo "   ✓ Certificate files found"
    ls -la /etc/letsencrypt/live/$DOMAIN_NAME/
else
    echo "   ✗ Certificate files not found"
    exit 1
fi

# Update Nginx configuration for HTTPS
echo ""
echo "7. Updating Nginx configuration for HTTPS..."
cat > /etc/nginx/conf.d/automation-ui.conf << 'NGINXHTTPS'
# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name automation.anchortechconsultants.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name automation.anchortechconsultants.com;

    ssl_certificate /etc/letsencrypt/live/automation.anchortechconsultants.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/automation.anchortechconsultants.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    access_log /var/log/nginx/automation-ui-access.log;
    error_log /var/log/nginx/automation-ui-error.log;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    client_max_body_size 10M;
}
NGINXHTTPS

echo "   ✓ Nginx configuration updated"

# Test Nginx configuration
echo ""
echo "8. Testing Nginx configuration..."
nginx -t

if [ $? -eq 0 ]; then
    echo "   ✓ Nginx configuration is valid"
else
    echo "   ✗ Nginx configuration has errors"
    exit 1
fi

# Reload Nginx
echo ""
echo "9. Reloading Nginx..."
systemctl reload nginx

if [ $? -eq 0 ]; then
    echo "   ✓ Nginx reloaded successfully"
else
    echo "   ✗ Failed to reload Nginx"
    exit 1
fi

# Verify HTTPS is listening
echo ""
echo "10. Verifying services..."
sleep 2

HTTP_LISTENING=$(netstat -tlnp | grep ':80 ' | grep nginx || true)
HTTPS_LISTENING=$(netstat -tlnp | grep ':443' | grep nginx || true)

if [ -n "$HTTP_LISTENING" ]; then
    echo "   ✓ HTTP (port 80) is listening"
else
    echo "   ✗ HTTP (port 80) is NOT listening"
fi

if [ -n "$HTTPS_LISTENING" ]; then
    echo "   ✓ HTTPS (port 443) is listening"
else
    echo "   ✗ HTTPS (port 443) is NOT listening"
fi

# Set up automatic renewal cron job
echo ""
echo "11. Setting up automatic certificate renewal..."
CRON_JOB="0 0,12 * * * $CERTBOT_PATH renew --quiet --post-hook 'systemctl reload nginx'"
(crontab -l 2>/dev/null | grep -v "certbot renew"; echo "$CRON_JOB") | crontab -
echo "   ✓ Cron job added for automatic renewal (twice daily)"

# Test SSL certificate
echo ""
echo "============================================"
echo "SSL Setup Complete!"
echo "============================================"
echo ""
echo "Your application should now be accessible at:"
echo "   https://$DOMAIN_NAME"
echo ""
echo "Certificate details:"
certbot certificates
echo ""
echo "Next steps:"
echo "1. Test your site: https://$DOMAIN_NAME"
echo "2. Verify SSL: https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN_NAME"
echo "3. Check certificate expiry: sudo certbot certificates"
echo ""
echo "Troubleshooting commands:"
echo "- Check Nginx logs: sudo tail -f /var/log/nginx/automation-ui-error.log"
echo "- Check certificate: sudo certbot certificates"
echo "- Renew certificate: sudo certbot renew --dry-run"
echo "- Reload Nginx: sudo systemctl reload nginx"
echo "============================================"
