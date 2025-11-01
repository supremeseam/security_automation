# AWS Cognito Quick Start Guide

Quick reference for deploying and using AWS Cognito authentication.

## 1. Deploy Cognito Infrastructure

```bash
cd terraform
terraform apply
```

## 2. Get Cognito Configuration

```bash
terraform output cognito_info
```

Save these values:
- User Pool ID
- App Client ID
- Login URL

## 3. Create Your First User

### Using AWS CLI:

```bash
aws cognito-idp admin-create-user \
    --user-pool-id <YOUR_USER_POOL_ID> \
    --username admin@anchortechconsultants.com \
    --user-attributes \
        Name=email,Value=admin@anchortechconsultants.com \
        Name=name,Value="Admin User" \
        Name=email_verified,Value=true \
    --temporary-password "TempPassword123!" \
    --message-action SUPPRESS

# Set permanent password
aws cognito-idp admin-set-user-password \
    --user-pool-id <YOUR_USER_POOL_ID> \
    --username admin@anchortechconsultants.com \
    --password "YourSecurePassword123!" \
    --permanent
```

### Using AWS Console:

1. Go to AWS Cognito Console
2. Select your User Pool (py-auto-ui-user-pool)
3. Click "Create user"
4. Enter email and set password

## 4. Enable Cognito in Application

### Option A: Use Cognito Version Directly

```bash
# SSH into EC2
ssh -i terraform/py-auto-ui-key.pem ec2-user@<EC2_IP>

# Switch to Cognito version
cd /opt/automation-ui/app
sudo mv app.py app_database.py
sudo mv app_cognito.py app.py

# Restart application
sudo systemctl restart automation-ui
```

### Option B: One-Liner Command

```bash
# SSH into EC2
ssh -i terraform/py-auto-ui-key.pem ec2-user@<EC2_IP>

# Switch to Cognito and restart
cd /opt/automation-ui/app && sudo cp app.py app_database.py && sudo cp app_cognito.py app.py && sudo systemctl restart automation-ui && sudo systemctl status automation-ui --no-pager
```

## 5. Test Login

1. Visit: https://automation.anchortechconsultants.com
2. Click "Login" or you'll be automatically redirected
3. Sign in with your Cognito credentials
4. You should be redirected back to the app

## Common Commands

### Create User

```bash
aws cognito-idp admin-create-user \
    --user-pool-id <POOL_ID> \
    --username user@example.com \
    --user-attributes Name=email,Value=user@example.com Name=name,Value="User Name" \
    --temporary-password "Temp123!"
```

### Reset Password

```bash
aws cognito-idp admin-set-user-password \
    --user-pool-id <POOL_ID> \
    --username user@example.com \
    --password "NewPassword123!" \
    --permanent
```

### List Users

```bash
aws cognito-idp list-users --user-pool-id <POOL_ID>
```

### Disable User

```bash
aws cognito-idp admin-disable-user \
    --user-pool-id <POOL_ID> \
    --username user@example.com
```

### Enable User

```bash
aws cognito-idp admin-enable-user \
    --user-pool-id <POOL_ID> \
    --username user@example.com
```

## Troubleshooting

### Check Application Logs

```bash
sudo journalctl -u automation-ui -f
```

### Check Environment Variables

```bash
sudo cat /opt/automation-ui/app/.env | grep COGNITO
```

Should show:
```
COGNITO_USER_POOL_ID=us-east-1_XXXXXXXXX
COGNITO_CLIENT_ID=XXXXXXXXXXXXXXXXXXXXXXXXXX
COGNITO_DOMAIN=py-auto-ui-auth-xxxxxxxx.auth.us-east-1.amazoncognito.com
COGNITO_REGION=us-east-1
APP_DOMAIN=automation.anchortechconsultants.com
```

### Check Cognito Configuration

```bash
terraform output cognito_info
```

### Test Token Verification

```bash
# Check if JWKS URL is accessible
curl https://cognito-idp.us-east-1.amazonaws.com/<USER_POOL_ID>/.well-known/jwks.json
```

## URLs

- **Application**: https://automation.anchortechconsultants.com
- **Login (Cognito)**: See `terraform output cognito_login_url`
- **AWS Console**: https://console.aws.amazon.com/cognito/

## Security Best Practices

1. **Enable MFA** for admin users
2. **Use strong passwords** (8+ chars, mixed case, numbers, symbols)
3. **Monitor failed login attempts** in CloudWatch
4. **Regularly review user access**
5. **Keep temporary passwords short-lived**

## Rollback to Database Auth

```bash
# SSH into EC2
ssh -i terraform/py-auto-ui-key.pem ec2-user@<EC2_IP>

# Switch back to database auth
cd /opt/automation-ui/app && sudo cp app.py app_cognito_backup.py && sudo cp app_database.py app.py && sudo systemctl restart automation-ui
```

## Getting Help

- **Full Guide**: [COGNITO_MIGRATION.md](COGNITO_MIGRATION.md)
- **Application Logs**: `sudo journalctl -u automation-ui -f`
- **Cognito Logs**: CloudWatch Logs → `/aws/cognito/user-pool/<POOL_ID>`
- **AWS Support**: https://console.aws.amazon.com/support/
