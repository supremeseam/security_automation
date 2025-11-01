# Cognito Setup - Copy/Paste Commands

Quick copy-paste commands for setting up AWS Cognito authentication.

## Prerequisites

- Terraform deployed with Cognito resources
- SSL certificate configured
- SSH access to EC2 instance

## Step 1: Deploy Cognito (Local Machine)

```bash
cd terraform
terraform apply
```

## Step 2: Get Cognito Details (Local Machine)

```bash
# Get User Pool ID and other info
terraform output cognito_info

# Save these values:
export USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
export CLIENT_ID=$(terraform output -raw cognito_client_id)
export EC2_IP=$(terraform output -raw ec2_public_ip)

echo "User Pool ID: $USER_POOL_ID"
echo "Client ID: $CLIENT_ID"
echo "EC2 IP: $EC2_IP"
```

## Step 3: Create Admin User (Local Machine)

Replace with your email:

```bash
aws cognito-idp admin-create-user \
    --user-pool-id $USER_POOL_ID \
    --username admin@anchortechconsultants.com \
    --user-attributes \
        Name=email,Value=admin@anchortechconsultants.com \
        Name=name,Value="Admin User" \
        Name=email_verified,Value=true \
    --temporary-password "TempPassword123!" \
    --message-action SUPPRESS
```

Set permanent password:

```bash
aws cognito-idp admin-set-user-password \
    --user-pool-id $USER_POOL_ID \
    --username admin@anchortechconsultants.com \
    --password "YourSecurePassword123!" \
    --permanent
```

## Step 4: Enable Cognito on EC2 (On EC2 Instance)

### Connect to EC2:

```bash
ssh -i terraform/py-auto-ui-key.pem ec2-user@$EC2_IP
```

### Switch to Cognito Authentication:

```bash
# Navigate to app directory
cd /opt/automation-ui/app

# Backup current app.py (database auth)
sudo cp app.py app_database.py

# Enable Cognito version
sudo cp app_cognito.py app.py

# Restart application
sudo systemctl restart automation-ui

# Verify it's running
sudo systemctl status automation-ui --no-pager | head -20

# Check logs for any errors
sudo journalctl -u automation-ui -n 50 --no-pager
```

### One-Line Command (Alternative):

```bash
cd /opt/automation-ui/app && \
sudo cp app.py app_database.py && \
sudo cp app_cognito.py app.py && \
sudo systemctl restart automation-ui && \
sleep 2 && \
sudo systemctl status automation-ui --no-pager | head -20
```

## Step 5: Verify Environment Variables (On EC2)

```bash
# Check Cognito env vars are set
sudo cat /opt/automation-ui/app/.env | grep COGNITO

# Should show:
# COGNITO_USER_POOL_ID=us-east-1_XXXXXXXXX
# COGNITO_CLIENT_ID=XXXXXXXXXXXXXXXXXXXXXXXXXX
# COGNITO_DOMAIN=py-auto-ui-auth-xxxxxxxx.auth.us-east-1.amazoncognito.com
# COGNITO_REGION=us-east-1
# APP_DOMAIN=automation.anchortechconsultants.com
```

If these are missing, you need to update the .env file manually or redeploy.

## Step 6: Test Login

1. Open browser: https://automation.anchortechconsultants.com
2. You'll be redirected to Cognito Hosted UI
3. Login with the credentials you created
4. You should be redirected back to the app

## Troubleshooting Commands

### Check Application Logs

```bash
# Real-time logs
sudo journalctl -u automation-ui -f

# Last 100 lines
sudo journalctl -u automation-ui -n 100 --no-pager

# Errors only
sudo journalctl -u automation-ui -p err --no-pager
```

### Check Application Status

```bash
sudo systemctl status automation-ui
```

### Restart Application

```bash
sudo systemctl restart automation-ui
```

### Check Nginx

```bash
# Nginx status
sudo systemctl status nginx

# Nginx config test
sudo nginx -t

# Nginx logs
sudo tail -f /var/log/nginx/automation-ui-error.log
```

### Verify Cognito Configuration

```bash
# On your local machine
terraform output cognito_info
```

### Test JWKS Endpoint

```bash
# Replace with your User Pool ID
curl -s "https://cognito-idp.us-east-1.amazonaws.com/<USER_POOL_ID>/.well-known/jwks.json" | jq .
```

## Rollback to Database Authentication

If you need to switch back:

```bash
# On EC2 instance
cd /opt/automation-ui/app
sudo cp app.py app_cognito_backup.py
sudo cp app_database.py app.py
sudo systemctl restart automation-ui
sudo systemctl status automation-ui --no-pager | head -20
```

## User Management Commands

### Create Additional User

```bash
aws cognito-idp admin-create-user \
    --user-pool-id $USER_POOL_ID \
    --username user@example.com \
    --user-attributes Name=email,Value=user@example.com Name=name,Value="User Name" \
    --temporary-password "Temp123!"
```

### Reset User Password

```bash
aws cognito-idp admin-set-user-password \
    --user-pool-id $USER_POOL_ID \
    --username user@example.com \
    --password "NewPassword123!" \
    --permanent
```

### List All Users

```bash
aws cognito-idp list-users --user-pool-id $USER_POOL_ID
```

### Disable User

```bash
aws cognito-idp admin-disable-user \
    --user-pool-id $USER_POOL_ID \
    --username user@example.com
```

### Enable User

```bash
aws cognito-idp admin-enable-user \
    --user-pool-id $USER_POOL_ID \
    --username user@example.com
```

### Delete User

```bash
aws cognito-idp admin-delete-user \
    --user-pool-id $USER_POOL_ID \
    --username user@example.com
```

## Common Issues

### Issue: "Redirect URI mismatch"

**Fix:** Verify callback URLs in Cognito App Client match your domain:
- https://automation.anchortechconsultants.com/callback
- https://automation.anchortechconsultants.com/oauth2/callback

### Issue: "Token verification failed"

**Fix:** Check system time is synchronized:
```bash
# On EC2
date
sudo chronyc makestep
```

### Issue: "COGNITO environment variables not found"

**Fix:** Add them to .env file:
```bash
# On EC2
sudo tee -a /opt/automation-ui/app/.env << EOF
COGNITO_USER_POOL_ID=<YOUR_USER_POOL_ID>
COGNITO_CLIENT_ID=<YOUR_CLIENT_ID>
COGNITO_DOMAIN=<YOUR_COGNITO_DOMAIN>
COGNITO_REGION=us-east-1
APP_DOMAIN=automation.anchortechconsultants.com
EOF

sudo systemctl restart automation-ui
```

### Issue: Application won't start

**Check logs:**
```bash
sudo journalctl -u automation-ui -n 100 --no-pager
```

**Common causes:**
- Missing Python dependencies (re-run pip install)
- Environment variables not set
- Syntax error in code

**Fix missing dependencies:**
```bash
cd /opt/automation-ui/app
sudo -u ec2-user pip3 install --user -r requirements.txt
sudo systemctl restart automation-ui
```

## Verification Checklist

- [ ] Terraform apply completed successfully
- [ ] Cognito User Pool created
- [ ] Admin user created in Cognito
- [ ] SSH into EC2 successful
- [ ] app_cognito.py copied to app.py
- [ ] Application restarted without errors
- [ ] COGNITO env vars present in .env
- [ ] Can access https://automation.anchortechconsultants.com
- [ ] Redirected to Cognito Hosted UI
- [ ] Successfully logged in
- [ ] Redirected back to application

## Next Steps

After successful setup:

1. **Create additional users** for your team
2. **Enable MFA** for sensitive accounts
3. **Customize Cognito Hosted UI** (optional)
4. **Set up CloudWatch alerts** for failed logins
5. **Test automation workflows** with Cognito auth

## Reference

- Login URL: `terraform output cognito_login_url`
- User Pool: `terraform output cognito_user_pool_id`
- Full guide: [COGNITO_MIGRATION.md](COGNITO_MIGRATION.md)
- Quick start: [COGNITO_QUICK_START.md](COGNITO_QUICK_START.md)
