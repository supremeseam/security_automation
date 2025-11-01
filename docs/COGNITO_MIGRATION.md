# AWS Cognito Authentication Migration Guide

This guide explains how to migrate from database-based authentication to AWS Cognito OAuth2 authentication.

## Overview

**Benefits of Cognito:**
- **No password management**: Cognito handles password hashing, storage, and reset
- **Built-in security**: MFA, account recovery, password policies
- **Scalable**: No database user table management
- **OAuth2 standard**: Industry-standard authentication flow
- **Hosted UI**: Ready-to-use login/signup pages
- **Federation**: Can integrate with Google, Facebook, etc. (optional)

## Architecture Changes

### Before (Database Auth):
```
User → Flask Login Form → Database (users table) → Session
```

### After (Cognito Auth):
```
User → Cognito Hosted UI → OAuth2 Callback → JWT Token → Session
```

## Migration Steps

### Step 1: Deploy Cognito Infrastructure

```bash
cd terraform
terraform apply
```

This will create:
- Cognito User Pool
- App Client
- Hosted UI Domain
- Update Secrets Manager with Cognito config

### Step 2: Get Cognito Configuration

After deployment, run:
```bash
terraform output cognito_info
```

Save the following values:
- User Pool ID
- App Client ID
- Cognito Domain
- Login URL

### Step 3: Update Application Code

Replace the current `app.py` with Cognito-enabled version:

```bash
cd app
mv app.py app_old.py
mv app_cognito.py app.py
```

### Step 4: Update Environment Variables

The `.env` file now needs these additional variables (automatically populated from Secrets Manager):

```bash
# Existing variables
DB_HOST=...
DB_PORT=...
DB_NAME=...
DB_USER=...
DB_PASSWORD=...
SECRET_KEY=...

# New Cognito variables (added automatically)
COGNITO_USER_POOL_ID=us-east-1_XXXXXXXXX
COGNITO_CLIENT_ID=XXXXXXXXXXXXXXXXXXXXXXXXXX
COGNITO_DOMAIN=py-auto-ui-auth-xxxxxxxx.auth.us-east-1.amazoncognito.com
COGNITO_REGION=us-east-1
APP_DOMAIN=automation.anchortechconsultants.com
```

### Step 5: Update user_data.sh (Optional)

If you want automatic deployment with Cognito, the user_data.sh script already handles this through Secrets Manager.

### Step 6: Restart the Application

```bash
sudo systemctl restart automation-ui
```

### Step 7: Create Users in Cognito

#### Option A: AWS Console

1. Go to AWS Cognito Console
2. Select your User Pool
3. Click "Create user"
4. Enter email and temporary password
5. User will be prompted to change password on first login

#### Option B: AWS CLI

```bash
aws cognito-idp admin-create-user \
    --user-pool-id <USER_POOL_ID> \
    --username user@example.com \
    --user-attributes Name=email,Value=user@example.com Name=name,Value="Full Name" \
    --temporary-password TempPassword123! \
    --message-action SUPPRESS
```

#### Option C: Terraform (Recommended for initial users)

Add to `cognito.tf`:

```hcl
resource "aws_cognito_user" "admin" {
  user_pool_id = aws_cognito_user_pool.main.id
  username     = "admin@anchortechconsultants.com"

  attributes = {
    email          = "admin@anchortechconsultants.com"
    email_verified = true
    name           = "Admin User"
  }

  # User will receive email with temporary password
}
```

### Step 8: Test Authentication Flow

1. Access: https://automation.anchortechconsultants.com
2. You'll be redirected to Cognito Hosted UI
3. Sign in with your Cognito credentials
4. After successful login, you'll be redirected back to the app

## Authentication Flow Details

### Login Flow

```
1. User visits https://automation.anchortechconsultants.com
2. App detects no session → redirects to /login
3. /login redirects to Cognito Hosted UI
4. User enters credentials on Cognito page
5. Cognito redirects to https://automation.anchortechconsultants.com/callback?code=XXXXX
6. App exchanges code for tokens (ID token, Access token, Refresh token)
7. App verifies ID token using JWKS
8. App creates session with user data
9. User is redirected to main app
```

### Logout Flow

```
1. User clicks logout
2. App clears session
3. App redirects to Cognito logout URL
4. Cognito clears its session
5. User is redirected back to app homepage
```

## Database Changes

### What Stays:
- `automation_logs` table (execution history)
- Database connection for logging

### What's Removed:
- `users` table (authentication moved to Cognito)
- Password hashing/verification logic
- User registration endpoints

### Optional: Keep User Table for Metadata

If you want to store additional user metadata not in Cognito:

```sql
-- Modified users table (no passwords)
CREATE TABLE user_metadata (
    cognito_sub VARCHAR(255) PRIMARY KEY,  -- Cognito user ID
    username VARCHAR(100),
    preferences JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP
);
```

## Code Changes Summary

### Files Added:
- `app/cognito_auth.py` - Cognito authentication module
- `app/app_cognito.py` - Flask app with Cognito auth
- `terraform/cognito.tf` - Cognito infrastructure

### Files Modified:
- `app/requirements.txt` - Added Cognito dependencies
- `terraform/outputs.tf` - Added Cognito outputs

### Files Backup:
- `app/app.py` → `app/app_old.py` (database auth version)

## Cognito User Management

### Create User

```bash
aws cognito-idp admin-create-user \
    --user-pool-id <USER_POOL_ID> \
    --username user@example.com \
    --user-attributes Name=email,Value=user@example.com \
    --temporary-password TempPassword123!
```

### Reset Password

```bash
aws cognito-idp admin-set-user-password \
    --user-pool-id <USER_POOL_ID> \
    --username user@example.com \
    --password NewPassword123! \
    --permanent
```

### Disable User

```bash
aws cognito-idp admin-disable-user \
    --user-pool-id <USER_POOL_ID> \
    --username user@example.com
```

### Enable User

```bash
aws cognito-idp admin-enable-user \
    --user-pool-id <USER_POOL_ID> \
    --username user@example.com
```

### List Users

```bash
aws cognito-idp list-users \
    --user-pool-id <USER_POOL_ID>
```

## Security Configuration

### Password Policy

The Cognito User Pool is configured with:
- Minimum 8 characters
- Require uppercase
- Require lowercase
- Require numbers
- Require symbols

### MFA (Multi-Factor Authentication)

MFA is set to **OPTIONAL** by default. To make it required:

1. Go to AWS Cognito Console
2. Select your User Pool
3. MFA and verifications → Edit
4. Select "Required"
5. Choose: SMS, TOTP, or both

### Advanced Security

Advanced Security Mode is **ENFORCED**, providing:
- Compromised credentials detection
- Adaptive authentication
- Risk-based access control

## Troubleshooting

### Issue: "Token verification failed"

**Cause:** Clock skew or invalid token

**Solution:**
```bash
# Check system time on EC2
date
# If incorrect, sync time
sudo chronyc makestep
```

### Issue: "Redirect URI mismatch"

**Cause:** Callback URL not matching configured URLs

**Solution:**
Check Cognito App Client settings match your domain:
- https://automation.anchortechconsultants.com/callback
- https://automation.anchortechconsultants.com/oauth2/callback

### Issue: "User pool domain not available"

**Cause:** Domain name already taken

**Solution:**
Terraform will automatically generate a unique suffix. If deploying manually, choose a different domain prefix.

### Issue: Cannot access Cognito Hosted UI

**Cause:** DNS or SSL issues

**Solution:**
1. Verify DNS is configured correctly
2. Verify SSL certificate is valid
3. Check security group allows HTTPS (443)

## Testing

### Test Authentication Flow

```bash
# 1. Get login URL
terraform output cognito_login_url

# 2. Open in browser
# You should see Cognito Hosted UI

# 3. Sign in with test user

# 4. Verify redirect to app
# Should redirect to https://automation.anchortechconsultants.com/callback
```

### Test Token Verification

```python
# Test script: test_cognito.py
import os
from cognito_auth import CognitoAuth

cognito = CognitoAuth()
cognito.init_app(None)  # Initialize without Flask app

# Test token verification
id_token = "YOUR_ID_TOKEN_HERE"
user_data = cognito.verify_token(id_token)
print(f"User: {user_data}")
```

## Rollback Plan

If you need to roll back to database authentication:

```bash
cd app
mv app.py app_cognito_backup.py
mv app_old.py app.py
sudo systemctl restart automation-ui
```

## Cost Considerations

### Cognito Pricing (as of 2024):
- **Free Tier**: 50,000 MAU (Monthly Active Users)
- **Beyond Free Tier**: $0.0055 per MAU

For a small team (< 50 users), Cognito is effectively **FREE**.

### Comparison:
- **Database Auth**: Free (using existing RDS)
- **Cognito**: Free for <50K MAU, more secure, less maintenance

## Next Steps

After migration:

1. **Enable MFA** for all users
2. **Set up CloudWatch alerts** for failed login attempts
3. **Configure custom email templates** (optional)
4. **Add social identity providers** (optional)
   - Google
   - Facebook
   - Amazon
5. **Implement token refresh** for long sessions

## Additional Resources

- [AWS Cognito Documentation](https://docs.aws.amazon.com/cognito/)
- [OAuth 2.0 Flow](https://oauth.net/2/)
- [JWT Token Structure](https://jwt.io/)
- [Cognito Hosted UI Customization](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-app-ui-customization.html)

## Support

For issues or questions:
1. Check CloudWatch Logs: `/aws/cognito/user-pool/<POOL_ID>`
2. Check application logs: `sudo journalctl -u automation-ui -f`
3. Review Cognito User Pool events in AWS Console
