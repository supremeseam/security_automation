# Troubleshooting Guide

## Service Stuck in "Activating" State

If `systemctl status automation-ui` shows the service is "activating" for a long time, follow these steps:

### Step 1: Check Real-Time Logs

```bash
# Watch logs in real-time
sudo journalctl -u automation-ui -f

# Or last 100 lines
sudo journalctl -u automation-ui -n 100 --no-pager

# Errors only
sudo journalctl -u automation-ui -p err -n 50 --no-pager
```

### Step 2: Common Issues

#### Issue 1: Missing Python Dependencies

**Symptoms:** Import errors, ModuleNotFoundError

**Fix:**
```bash
cd /opt/automation-ui/app
sudo -u ec2-user pip3 install --user -r requirements.txt
sudo systemctl restart automation-ui
```

#### Issue 2: Missing Environment Variables

**Symptoms:** KeyError, "COGNITO_USER_POOL_ID not found"

**Check:**
```bash
sudo cat /opt/automation-ui/app/.env
```

**Fix:** Add missing Cognito variables:
```bash
sudo tee -a /opt/automation-ui/app/.env << 'EOF'
COGNITO_USER_POOL_ID=your_pool_id_here
COGNITO_CLIENT_ID=your_client_id_here
COGNITO_DOMAIN=your-domain.auth.us-east-1.amazoncognito.com
COGNITO_REGION=us-east-1
APP_DOMAIN=automation.anchortechconsultants.com
EOF

sudo systemctl restart automation-ui
```

#### Issue 3: Syntax Error in Code

**Symptoms:** SyntaxError, IndentationError

**Fix:** Check which version of Python is being used and verify the code syntax:
```bash
python3 -m py_compile /opt/automation-ui/app/app.py
```

#### Issue 4: Port Already in Use

**Symptoms:** "Address already in use"

**Check:**
```bash
sudo netstat -tlnp | grep :5000
```

**Fix:**
```bash
# Kill process using port 5000
sudo kill $(sudo lsof -t -i:5000)
sudo systemctl restart automation-ui
```

### Step 3: Manual Test

Try running the app manually to see detailed errors:

```bash
cd /opt/automation-ui/app

# Load environment variables
source .env

# Try to run the app manually
sudo -u ec2-user python3 app.py
```

Press Ctrl+C to stop, then restart the service:
```bash
sudo systemctl restart automation-ui
```

### Step 4: Check Service Configuration

```bash
# View service file
sudo cat /etc/systemd/system/automation-ui.service

# Check if gunicorn is installed
sudo -u ec2-user pip3 show gunicorn

# Check gunicorn path
which gunicorn
/home/ec2-user/.local/bin/gunicorn  # Should be here
```

### Step 5: Reset Service

If all else fails, reset the service:

```bash
# Stop service
sudo systemctl stop automation-ui

# Check if any processes are still running
ps aux | grep app.py
ps aux | grep gunicorn

# Kill any remaining processes
sudo pkill -f app.py
sudo pkill -f gunicorn

# Start service
sudo systemctl start automation-ui

# Check status
sudo systemctl status automation-ui --no-pager
```

## Specific Error Messages

### "No module named 'cognito_auth'"

**Cause:** cognito_auth.py not in the same directory as app.py

**Fix:**
```bash
cd /opt/automation-ui/app
ls -la cognito_auth.py app.py
# Both should be in the same directory

# If cognito_auth.py is missing, you need to deploy it
```

### "No module named 'jose'"

**Cause:** python-jose not installed

**Fix:**
```bash
sudo -u ec2-user pip3 install --user 'python-jose[cryptography]'
sudo systemctl restart automation-ui
```

### "No module named 'boto3'"

**Cause:** boto3 not installed

**Fix:**
```bash
sudo -u ec2-user pip3 install --user boto3
sudo systemctl restart automation-ui
```

### "COGNITO_USER_POOL_ID environment variable not set"

**Cause:** Missing Cognito configuration in .env

**Fix:**
```bash
# Get values from Terraform
cd /path/to/terraform
terraform output cognito_user_pool_id
terraform output cognito_client_id

# Add to .env
sudo nano /opt/automation-ui/app/.env
# Add the COGNITO_* variables
```

### "Connection refused" or "Cannot connect to database"

**Cause:** Database not accessible

**Fix:**
```bash
# Check database connection from EC2
mysql -h <DB_HOST> -u <DB_USER> -p<DB_PASSWORD> -e "SELECT 1"

# Verify RDS security group allows EC2 access
# Check .env has correct DB credentials
```

## Switching Back to Database Auth

If Cognito version has issues, switch back to database authentication:

```bash
cd /opt/automation-ui/app
sudo cp app_database.py app.py
sudo systemctl restart automation-ui
sudo systemctl status automation-ui --no-pager
```

## Complete Service Restart

Full restart procedure:

```bash
# 1. Stop service
sudo systemctl stop automation-ui

# 2. Kill any hanging processes
sudo pkill -f "gunicorn.*app:app"
sudo pkill -f "python.*app.py"

# 3. Check nothing is listening on port 5000
sudo netstat -tlnp | grep :5000

# 4. Reload systemd
sudo systemctl daemon-reload

# 5. Start service
sudo systemctl start automation-ui

# 6. Check status
sudo systemctl status automation-ui --no-pager

# 7. Follow logs
sudo journalctl -u automation-ui -f
```

## Check Dependencies Installation

```bash
cd /opt/automation-ui/app

# Check what's installed for ec2-user
sudo -u ec2-user pip3 list | grep -E '(boto3|jose|jwt|requests)'

# Should show:
# boto3        1.34.0
# pyjwt        2.8.0
# python-jose  3.3.0
# requests     2.31.0

# If missing, reinstall all
sudo -u ec2-user pip3 install --user -r requirements.txt --force-reinstall
```

## Verify File Permissions

```bash
# Check ownership
ls -la /opt/automation-ui/app/

# app.py and cognito_auth.py should be readable
# If not, fix permissions
sudo chown -R ec2-user:ec2-user /opt/automation-ui/
```

## Emergency Commands

### Quick Diagnostic Script

```bash
#!/bin/bash
echo "=== Service Status ==="
sudo systemctl status automation-ui --no-pager | head -20

echo -e "\n=== Recent Logs ==="
sudo journalctl -u automation-ui -n 20 --no-pager

echo -e "\n=== Port 5000 ==="
sudo netstat -tlnp | grep :5000

echo -e "\n=== App Files ==="
ls -la /opt/automation-ui/app/*.py

echo -e "\n=== Environment ==="
sudo cat /opt/automation-ui/app/.env | grep -v PASSWORD | grep -v SECRET

echo -e "\n=== Python Packages ==="
sudo -u ec2-user pip3 list | grep -E '(boto3|jose|jwt|Flask|gunicorn)'
```

Save as `diagnose.sh`, then run:
```bash
bash diagnose.sh
```

## Getting More Help

If issues persist:

1. **Collect logs:**
   ```bash
   sudo journalctl -u automation-ui -n 500 > ~/automation-ui.log
   ```

2. **Check Nginx:**
   ```bash
   sudo systemctl status nginx
   sudo tail -n 100 /var/log/nginx/automation-ui-error.log
   ```

3. **Verify DNS and SSL:**
   ```bash
   nslookup automation.anchortechconsultants.com
   curl -I https://automation.anchortechconsultants.com
   ```

4. **Review user-data log** (initial deployment):
   ```bash
   sudo cat /var/log/user-data.log
   ```
