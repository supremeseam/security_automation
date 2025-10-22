# Python Automation UI

A user-friendly web interface that allows non-technical users to run Python automation scripts without dealing with command-line interfaces.

**⚠️ NOTE:** This is an example repository for demonstration purposes. It contains test credentials and secrets used to deploy a test instance. Do not use these credentials in production environments.

## Features

- Clean, intuitive web interface
- MySQL database authentication with session management
- User login/logout with secure password hashing (bcrypt)
- Automatic logging of all automation runs to database
- Dynamic parameter forms based on script configuration
- Support for different input types (text, select, textarea, checkbox)
- Real-time script execution with output display
- Easy to add new automation scripts
- TypeScript frontend for type safety
- Python Flask backend for reliable script execution

## Project Structure

```
python-automation-ui/
├── app.py                      # Flask backend server
├── database_setup.sql          # MySQL database schema
├── .env.example                # Environment variables template
├── automations_config.json     # Configuration for available automations
├── requirements.txt            # Python dependencies
├── package.json                # Node.js dependencies (for TypeScript)
├── tsconfig.json               # TypeScript configuration
├── scripts/                    # Python automation scripts
│   ├── file_organizer.py
│   ├── email_sender.py
│   └── data_backup.py
├── src/                        # TypeScript source files
│   └── app.ts
├── static/                     # Static assets
│   ├── css/
│   │   └── style.css
│   └── js/                     # Compiled TypeScript
│       └── app.js
└── templates/                  # HTML templates
    ├── index.html
    └── login.html
```

## Setup Instructions

### Prerequisites

- Python 3.8 or higher
- MySQL server (running at 10.20.72.84:3306 or configure your own)
- Node.js 16 or higher (for TypeScript compilation)
- pip (Python package manager)
- npm (Node.js package manager)

### Installation

1. **Setup MySQL Database:**

Run the SQL script on your MySQL server:

```bash
mysql -h 10.20.72.84 -P 3306 -u your_username -p < database_setup.sql
```

This creates:
- Database: `automation_ui`
- Table: `users` (with default users: admin/admin123 and user/password)
- Table: `automation_logs` (tracks all automation runs)

2. **Configure Environment Variables:**

Copy the example file and edit with your database credentials:

```bash
cp .env.example .env
```

Edit `.env`:
```
DB_HOST=10.20.72.84
DB_PORT=3306
DB_NAME=automation_ui
DB_USER=root
DB_PASSWORD=your_password
SECRET_KEY=your_random_secret_key
```

3. **Install Python dependencies:**

```bash
pip install -r requirements.txt
```

4. **Install Node.js dependencies:**

```bash
npm install
```

5. **Compile TypeScript:**

```bash
npm run build
```

## Running the Application

1. **Start the Flask server:**

```bash
python app.py
```

2. **Open your browser:**

Navigate to `http://localhost:5000`

3. **Login:**

Use one of the default accounts:
- Username: `admin` Password: `admin123`
- Username: `user` Password: `password`

The application is now running!

## How to Use

1. **Login:** Enter your username and password
2. **Select an Automation:** Choose from the dropdown menu of available automations
3. **Fill Parameters:** Enter the required parameters in the dynamically generated form
4. **Run:** Click the "Run Automation" button
5. **View Output:** See the results in the output section below
6. **Logout:** Click the logout button in the top right when finished

All automation runs are logged to the database with user info, parameters, execution time, and results.

## Adding New Automations

To add a new automation script, follow these steps:

### 1. Create Your Python Script

Create a new Python script in the `scripts/` directory:

```python
#!/usr/bin/env python3
import argparse

def main():
    parser = argparse.ArgumentParser(description='Your script description')
    parser.add_argument('--param1', required=True, help='Parameter 1')
    parser.add_argument('--param2', required=False, help='Parameter 2')

    args = parser.parse_args()

    # Your automation logic here
    print("Automation completed successfully!")

    return 0

if __name__ == '__main__':
    exit(main())
```

### 2. Update Configuration

Add your automation to `automations_config.json`:

```json
{
  "id": "your_automation_id",
  "name": "Your Automation Name",
  "description": "Brief description of what your automation does",
  "script": "scripts/your_script.py",
  "parameters": [
    {
      "name": "param1",
      "label": "Parameter 1 Label",
      "type": "text",
      "required": true,
      "placeholder": "Enter value..."
    }
  ]
}
```

### Parameter Types

The UI supports the following parameter types:

- **text**: Single-line text input
- **textarea**: Multi-line text input
- **select**: Dropdown selection (requires `options` array)
- **checkbox**: Boolean checkbox (use with `action='store_true'` in argparse)

### Parameter Configuration

Each parameter in the configuration can have:

- `name`: Parameter name (matches argparse argument)
- `label`: Display label in the UI
- `type`: Input type (text, textarea, select, checkbox)
- `required`: Whether the parameter is required (true/false)
- `placeholder`: Placeholder text for input fields (optional)
- `options`: Array of options for select dropdowns (required for select type)
- `default`: Default value (optional)

## Example Automations Included

### 1. File Organizer

Organizes files in a directory by extension, date, or size.

**Parameters:**
- Source Folder: Path to the folder to organize
- Organize By: Method (extension, date, size)

### 2. Bulk Email Sender

Simulates sending emails to multiple recipients (demo version).

**Parameters:**
- Recipients: Comma-separated email addresses
- Subject: Email subject line
- Message: Email body text

### 3. Data Backup

Creates backups of files with optional compression.

**Parameters:**
- Source: Path to backup
- Destination: Backup destination path
- Compress: Whether to compress the backup (checkbox)

## Development

### Watch Mode for TypeScript

For development, you can run TypeScript in watch mode:

```bash
npm run watch
```

This will automatically recompile TypeScript files when they change.

### Flask Debug Mode

The Flask server runs in debug mode by default, which means:
- Automatic reloading when Python files change
- Detailed error messages
- Debug toolbar (if installed)

## Database Management

### View Automation Logs

Query the logs in MySQL:

```sql
SELECT u.username, al.automation_name, al.success, al.execution_time, al.created_at
FROM automation_logs al
JOIN users u ON al.user_id = u.id
ORDER BY al.created_at DESC
LIMIT 50;
```

### Add New Users

```sql
-- Generate password hash first with Python:
-- import bcrypt; print(bcrypt.hashpw(b'password', bcrypt.gensalt()).decode())

INSERT INTO users (username, password_hash, email, full_name)
VALUES ('newuser', '$2b$12$your_hash_here', 'user@example.com', 'Full Name');
```

### Change User Password

```python
# Generate new hash
import bcrypt
new_hash = bcrypt.hashpw(b'new_password', bcrypt.gensalt()).decode()
print(new_hash)
```

Then update in MySQL:
```sql
UPDATE users SET password_hash = '$2b$12$new_hash' WHERE username = 'username';
```

## Security Considerations

**Important:** Consider these security measures for production:

1. **Change Default Passwords:** Immediately change admin/user passwords after setup
2. **Secure .env File:** Never commit .env to version control
3. **Input Validation:** Validate all user inputs on the backend
4. **Path Restrictions:** Limit file system access to specific directories
5. **Sandboxing:** Run scripts in isolated environments
6. **Timeout Limits:** Configure appropriate timeout limits for long-running scripts
7. **HTTPS:** Use HTTPS in production environments
8. **Rate Limiting:** Implement rate limiting to prevent abuse
9. **Database Backups:** Regular backups of automation_ui database

## Troubleshooting

## Future Security Enhancements (#TODO)

While the current security considerations provide a good baseline, the following enhancements should be implemented for a production-ready, security-hardened application:

1.  **Role-Based Access Control (RBAC):**
    - Implement a more granular permission system. Instead of just `admin` and `user`, define roles that can be assigned to users.
    - Restrict access to specific automation scripts based on user roles. For example, only users in the "IT-Admin" role can run the "User Offboarding" script.
    - This can be managed via new tables in the database (`roles`, `user_roles`, `role_permissions`).

2.  **Backend Input Sanitization and Validation:**
    - **Path Traversal Prevention:** In `app.py`, strictly validate all parameters that are file or directory paths (e.g., `source_folder`, `destination`). Ensure the resolved absolute path is within a pre-defined, whitelisted base directory to prevent scripts from accessing unintended parts of the filesystem.
    - **Command Injection Prevention:** Ensure that all calls to `subprocess` in the backend use an array of arguments (e.g., `subprocess.run(['python', script_path, '--param', value])`) and **never** use `shell=True` with user-provided input. This prevents users from injecting malicious shell commands.

3.  **Enhanced Logging and Auditing:**
    - Expand the `automation_logs` table to include the source IP address of the user running the script.
    - Implement an "audit trail" that logs security-sensitive events like failed login attempts, password changes, and permission modifications.

4.  **Frontend Security Hardening:**
    - **Content Security Policy (CSP):** Implement a strict CSP via HTTP headers to mitigate XSS and other injection attacks by defining which dynamic resources are allowed to load.
    - **Output Encoding:** While the frontend currently escapes HTML in the output, ensure this is consistently applied, especially if new features are added that render script output. The output should be treated as plain text, not HTML.

5.  **Secrets Management:**
    - For a production environment, integrate a dedicated secrets management tool (like HashiCorp Vault, AWS Secrets Manager, or Azure Key Vault) instead of relying solely on `.env` files. This provides better security, auditing, and rotation capabilities for database credentials and the `SECRET_KEY`.

### Database Connection Failed

Check that:
- MySQL server is running at the configured host/port
- Credentials in `.env` are correct
- User has permissions on `automation_ui` database
- Firewall allows connections to MySQL port

### Login Issues

- Verify users exist in database: `SELECT * FROM users;`
- Check password hashes are valid bcrypt hashes
- Ensure `is_active` is TRUE for the user

### Port Already in Use

If port 5000 is already in use, modify the port in `app.py`:

```python
app.run(debug=True, host='0.0.0.0', port=5001)  # Change port number
```

### TypeScript Compilation Errors

Make sure you have the correct TypeScript version:

```bash
npm install typescript@latest
npm run build
```

### Python Script Not Found

Ensure your script paths in `automations_config.json` are relative to the project root.

### Permission Errors

On Unix systems, make sure your Python scripts are executable:

```bash
chmod +x scripts/*.py
```

## Contributing

To contribute to this project:

1. Add your automation script following the guidelines above
2. Update the configuration file
3. Test thoroughly with various inputs
4. Update documentation if needed

## License

MIT License - Feel free to use and modify for your needs.

## Support

For issues or questions, please check the troubleshooting section or create an issue in the project repository.
