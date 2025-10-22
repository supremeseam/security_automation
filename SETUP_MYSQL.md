# MySQL Database Setup Guide

This guide will help you set up the MySQL database for the Python Automation UI.

## Prerequisites

- MySQL Server running at `10.20.72.84:3306`
- MySQL client or admin access to execute SQL scripts
- Database credentials (username and password)

## Step 1: Run the Database Setup Script

Connect to your MySQL server and run the setup script:

### Option A: Using MySQL Command Line

```bash
mysql -h 10.20.72.84 -P 3306 -u your_username -p < database_setup.sql
```

### Option B: Using MySQL Workbench or phpMyAdmin

1. Open MySQL Workbench or phpMyAdmin
2. Connect to `10.20.72.84:3306`
3. Open and execute the [database_setup.sql](database_setup.sql) file

### What the script does:

1. Creates database: `automation_ui`
2. Creates `users` table with the following structure:
   - `id` - Primary key
   - `username` - Unique username
   - `password_hash` - Bcrypt hashed password
   - `email` - User email
   - `full_name` - User's full name
   - `is_active` - Account status
   - `created_at` - Account creation timestamp
   - `last_login` - Last login timestamp

3. Creates `automation_logs` table to track automation executions:
   - Logs which user ran which automation
   - Stores parameters, success status, and output
   - Tracks execution time

4. Inserts two default users:
   - **Username:** `admin` | **Password:** `admin123`
   - **Username:** `user` | **Password:** `password`

## Step 2: Configure Database Connection

Create a `.env` file in the project root by copying the example:

```bash
cp .env.example .env
```

Edit the `.env` file with your database credentials:

```env
# Database Configuration
DB_HOST=10.20.72.84
DB_PORT=3306
DB_NAME=automation_ui
DB_USER=your_mysql_username
DB_PASSWORD=your_mysql_password

# Flask Secret Key (change this to a random string)
SECRET_KEY=your-random-secret-key-here
```

### Generate a secure SECRET_KEY

You can generate a secure random key using Python:

```bash
python -c "import secrets; print(secrets.token_hex(32))"
```

## Step 3: Install Python Dependencies

Install all required packages:

```bash
pip install -r requirements.txt
```

This will install:
- Flask
- Flask-CORS
- Flask-Login
- mysql-connector-python
- python-dotenv
- bcrypt

## Step 4: Test Database Connection

You can test the database connection by running the app:

```bash
python app.py
```

If successful, you should see:

```
============================================================
Python Automation UI Server
============================================================
Database: 10.20.72.84:3306/automation_ui
Server: http://localhost:5000
============================================================

Default credentials:
  Username: admin | Password: admin123
  Username: user  | Password: password
============================================================
```

## Step 5: Access the Application

1. Open your browser to: `http://localhost:5000`
2. You'll be redirected to the login page
3. Log in with:
   - **Username:** admin
   - **Password:** admin123

## Managing Users

### Add a New User (via MySQL)

```sql
USE automation_ui;

-- Generate password hash in Python first:
-- import bcrypt
-- bcrypt.hashpw('your_password'.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

INSERT INTO users (username, password_hash, email, full_name)
VALUES ('newuser', '$2b$12$your_bcrypt_hash_here', 'newuser@example.com', 'New User');
```

### Generate Password Hash

Use this Python script to generate a bcrypt hash:

```python
import bcrypt

password = "your_password_here"
hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
print(hashed.decode('utf-8'))
```

### Deactivate a User

```sql
UPDATE users SET is_active = FALSE WHERE username = 'username';
```

### Reactivate a User

```sql
UPDATE users SET is_active = TRUE WHERE username = 'username';
```

### Change User Password

```python
import bcrypt

# Generate new password hash
new_password = "new_password_here"
hashed = bcrypt.hashpw(new_password.encode('utf-8'), bcrypt.gensalt())
print(hashed.decode('utf-8'))
```

Then update in MySQL:

```sql
UPDATE users SET password_hash = '$2b$12$new_hash_here' WHERE username = 'username';
```

## Viewing Automation Logs

Query the automation logs:

```sql
USE automation_ui;

-- View all automation runs
SELECT
    al.id,
    u.username,
    al.automation_name,
    al.success,
    al.execution_time,
    al.created_at
FROM automation_logs al
JOIN users u ON al.user_id = u.id
ORDER BY al.created_at DESC
LIMIT 50;

-- View logs for a specific user
SELECT * FROM automation_logs
WHERE user_id = (SELECT id FROM users WHERE username = 'admin')
ORDER BY created_at DESC;

-- View success rate by automation
SELECT
    automation_name,
    COUNT(*) as total_runs,
    SUM(CASE WHEN success = TRUE THEN 1 ELSE 0 END) as successful,
    AVG(execution_time) as avg_execution_time
FROM automation_logs
GROUP BY automation_name;
```

## Troubleshooting

### Connection Refused

- Verify MySQL server is running
- Check firewall allows connections to port 3306
- Verify hostname/IP address is correct

### Authentication Failed

- Check username and password in `.env` file
- Verify user has permissions on the `automation_ui` database

### Tables Not Found

- Make sure you ran the `database_setup.sql` script
- Check you're connected to the correct database

### Password Hash Errors

- Ensure bcrypt package is installed: `pip install bcrypt`
- Verify password hashes in database are valid bcrypt hashes

## Security Recommendations

1. **Change Default Passwords**: Immediately change the default admin password
2. **Use Strong Passwords**: Require complex passwords for all users
3. **Secure .env File**: Never commit `.env` to version control
4. **Database Permissions**: Create a dedicated MySQL user with minimal permissions
5. **Enable SSL**: Use SSL/TLS for database connections in production
6. **Regular Backups**: Set up automated backups of the database
7. **Audit Logs**: Regularly review automation logs for suspicious activity

## Production Deployment

For production environments:

1. Use a strong `SECRET_KEY`
2. Set `debug=False` in app.py
3. Use a production-grade WSGI server (gunicorn, uWSGI)
4. Enable HTTPS
5. Implement rate limiting
6. Set up database connection pooling
7. Configure proper database backups

## Need Help?

If you encounter issues:
1. Check the console output when starting the application
2. Verify database credentials in `.env`
3. Test MySQL connection separately
4. Check Python error messages

For common issues, see the main [README.md](README.md).
