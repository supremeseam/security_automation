# SSL Certificate and Domain Setup

This guide explains how to set up SSL certificates and configure your domain for the automation application.

## Quick Reference

If SSL certificate generation failed during deployment (common if DNS wasn't ready), run these commands on the EC2 instance:

```bash
# 1. Obtain SSL certificate
sudo certbot certonly --nginx \
    --non-interactive \
    --agree-tos \
    --email admin@automation.anchortechconsultants.com \
    --domains automation.anchortechconsultants.com

# 2. Update Nginx config for HTTPS
sudo tee /etc/nginx/conf.d/automation-ui.conf << 'EOF'
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

server {
    listen 443 ssl http2;
    server_name automation.anchortechconsultants.com;

    ssl_certificate /etc/letsencrypt/live/automation.anchortechconsultants.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/automation.anchortechconsultants.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# 3. Test and reload Nginx
sudo nginx -t && sudo systemctl reload nginx
```

## Overview

The infrastructure has been configured to automatically:
- Install Nginx as a reverse proxy
- Obtain SSL certificates from Let's Encrypt
- Configure HTTPS with automatic HTTP → HTTPS redirect
- Set up automatic certificate renewal (twice daily checks)

## Domain Configuration

**Domain:** automation.anchortechconsultants.com

## Deployment Steps

### 1. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

After deployment, Terraform will output:
- EC2 public IP address
- HTTPS URL
- DNS configuration instructions

### 2. Configure DNS

**IMPORTANT:** You must configure your DNS **before** the SSL certificate can be issued.

In your domain registrar (where anchortechconsultants.com is hosted):

1. Create an **A Record**:
   - **Type:** A
   - **Name:** automation
   - **Value:** [EC2 Public IP from Terraform output]
   - **TTL:** 300 (or default)

2. Wait for DNS propagation (typically 5-15 minutes)

3. Verify DNS is working:
   ```bash
   nslookup automation.anchortechconsultants.com
   ```

### 3. SSL Certificate Generation

The SSL certificate will be automatically obtained during EC2 instance initialization:

1. The user_data script installs Certbot
2. Once DNS is propagated, Certbot requests a certificate from Let's Encrypt
3. Nginx is automatically configured with HTTPS
4. HTTP traffic is redirected to HTTPS

**Note:** If DNS is not configured when the instance starts, the SSL certificate generation will fail, but Nginx will still serve HTTP traffic. You can manually obtain the certificate later (see Troubleshooting).

### 4. Access Your Application

Once DNS propagates and SSL is configured:

- **HTTPS URL:** https://automation.anchortechconsultants.com
- **HTTP URL:** http://automation.anchortechconsultants.com (redirects to HTTPS)

## Configuration Files

### Terraform Variables

Key variables in `terraform/variables.tf`:

```hcl
variable "domain_name" {
  default = "automation.anchortechconsultants.com"
}

variable "ssl_email" {
  default = ""  # Defaults to admin@domain_name if not set
}
```

### Nginx Configuration

Nginx configuration is automatically generated during deployment:
- **Location:** `/etc/nginx/conf.d/automation-ui.conf`
- **Logs:** `/var/log/nginx/automation-ui-*.log`

### SSL Certificate

Let's Encrypt certificates are stored at:
- **Certificate:** `/etc/letsencrypt/live/automation.anchortechconsultants.com/fullchain.pem`
- **Private Key:** `/etc/letsencrypt/live/automation.anchortechconsultants.com/privkey.pem`

## Certificate Renewal

Certificates are automatically renewed via cron job:
- **Schedule:** Twice daily (midnight and noon)
- **Command:** `certbot renew --quiet --post-hook 'systemctl reload nginx'`
- **Certificate Validity:** 90 days (renewed when <30 days remain)

To manually check renewal status:
```bash
sudo certbot renew --dry-run
```

## Security Features

The SSL configuration includes:

- **TLS 1.2 and 1.3** only
- **Strong cipher suites**
- **HSTS** (HTTP Strict Transport Security)
- **Security headers:**
  - X-Frame-Options: SAMEORIGIN
  - X-Content-Type-Options: nosniff
  - X-XSS-Protection: 1; mode=block

## Troubleshooting

### SSL Certificate Failed to Generate

If the SSL certificate wasn't generated during initial deployment (common if DNS wasn't configured yet):

#### Step 1: Verify DNS is pointing to the correct IP

```bash
nslookup automation.anchortechconsultants.com
```

#### Step 2: SSH into the EC2 instance

```bash
ssh -i terraform/py-auto-ui-key.pem ec2-user@<EC2_IP>
```

#### Step 3: Obtain SSL Certificate

```bash
sudo certbot certonly --nginx \
    --non-interactive \
    --agree-tos \
    --email admin@automation.anchortechconsultants.com \
    --domains automation.anchortechconsultants.com
```

#### Step 4: Update Nginx Configuration for HTTPS

```bash
sudo tee /etc/nginx/conf.d/automation-ui.conf << 'EOF'
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

server {
    listen 443 ssl http2;
    server_name automation.anchortechconsultants.com;

    ssl_certificate /etc/letsencrypt/live/automation.anchortechconsultants.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/automation.anchortechconsultants.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
```

#### Step 5: Test and Reload Nginx

```bash
# Test Nginx configuration
sudo nginx -t

# Reload Nginx with new configuration
sudo systemctl reload nginx

# Verify HTTPS is listening
sudo netstat -tlnp | grep nginx
```

You should see Nginx listening on both port 80 (HTTP) and port 443 (HTTPS).

#### Step 6: Test HTTPS Access

Visit https://automation.anchortechconsultants.com in your browser. The connection should now be secure with no warnings.

### Check SSL Certificate Status

```bash
sudo certbot certificates
```

### View Nginx Logs

```bash
# Access logs
sudo tail -f /var/log/nginx/automation-ui-access.log

# Error logs
sudo tail -f /var/log/nginx/automation-ui-error.log

# Nginx status
sudo systemctl status nginx
```

### View User Data Logs

To see the deployment script output:
```bash
sudo cat /var/log/user-data.log
```

### Test SSL Configuration

Use SSL Labs to test your SSL configuration:
https://www.ssllabs.com/ssltest/analyze.html?d=automation.anchortechconsultants.com

## AWS Cognito Integration

With proper SSL configured, you can now use this domain with AWS Cognito:

1. **Allowed callback URLs:**
   - https://automation.anchortechconsultants.com/callback
   - https://automation.anchortechconsultants.com/oauth2/callback

2. **Allowed sign-out URLs:**
   - https://automation.anchortechconsultants.com/logout
   - https://automation.anchortechconsultants.com

3. **Allowed OAuth flows:**
   - Authorization code grant
   - Implicit grant (if needed)

## Updating the Domain

To change the domain name:

1. Update `terraform/variables.tf`:
   ```hcl
   variable "domain_name" {
     default = "new-domain.example.com"
   }
   ```

2. Redeploy:
   ```bash
   terraform apply
   ```

3. Update DNS to point to the new or existing EC2 IP

## Cost Considerations

- **Let's Encrypt SSL Certificates:** FREE
- **Nginx:** FREE (open-source)
- **Domain Name:** ~$10-15/year (managed externally)
- **AWS Resources:** Standard EC2/RDS costs (no additional SSL costs)

## Support

For issues:
1. Check `/var/log/user-data.log` for deployment issues
2. Check `/var/log/nginx/automation-ui-error.log` for application errors
3. Run `sudo systemctl status nginx` and `sudo systemctl status automation-ui`
4. Verify DNS configuration with `nslookup` or `dig`
