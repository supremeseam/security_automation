# Security Automation Infrastructure

AWS infrastructure for deploying a Python-based automation UI application with MySQL database backend.

## Project Structure

```
security_automation/
├── terraform/          # Infrastructure as Code
│   ├── main.tf        # Main Terraform configuration
│   ├── variables.tf   # Variable definitions
│   ├── outputs.tf     # Output definitions
│   ├── user_data.sh   # EC2 initialization script
│   ├── terraform.tfvars.example  # Example variables file
│   └── create-key-pair.sh        # SSH key generation script
│
├── app/               # Application code
│   ├── app.py         # Main Flask application
│   ├── app.ts         # TypeScript frontend
│   ├── requirements.txt   # Python dependencies
│   ├── package.json       # Node.js dependencies
│   ├── tsconfig.json      # TypeScript configuration
│   ├── database_setup.sql # Database schema
│   ├── scripts/           # Automation scripts
│   │   ├── data_backup.py
│   │   ├── email_sender.py
│   │   └── file_organizer.py
│   ├── static/            # Static assets
│   ├── templates/         # HTML templates
│   └── config/            # Application configuration
│       └── automations_config.json
│
├── docs/              # Documentation
│   └── SETUP_MYSQL.md
│
├── .env.example       # Example environment variables
└── .gitignore         # Git ignore rules
```

## Quick Start

### Prerequisites
- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- Git repository URL for your application code

### Deployment Steps

1. **Clone this repository**
   ```bash
   git clone https://github.com/supremeseam/security_automation.git
   cd security_automation
   ```

2. **Configure Terraform variables**
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Initialize and deploy**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Configure DNS for your domain**
   ```bash
   # Get the EC2 public IP from Terraform output
   # Configure DNS A record: automation.anchortechconsultants.com -> EC2_IP
   ```

5. **Set up SSL certificate** (if not automatically configured)
   - See [SSL Setup Guide](docs/SSL_SETUP.md) for detailed instructions
   - Quick fix commands included in the documentation

6. **Access your application**
   - HTTPS URL: https://automation.anchortechconsultants.com
   - HTTP redirects to HTTPS automatically
   - SSH access available using the generated PEM key

## Infrastructure Components

- **VPC**: Isolated network with public and private subnets
- **EC2 Instance**: Amazon Linux 2023 running Flask application behind Nginx
- **Nginx**: Reverse proxy with SSL/TLS termination
- **SSL/TLS**: Let's Encrypt certificates with automatic renewal
- **AWS Cognito**: OAuth2 authentication with hosted UI (optional)
- **RDS MySQL**: Managed database in private subnet
- **Secrets Manager**: Secure storage for credentials
- **IAM Roles**: Least-privilege access for EC2 instance
- **Security Groups**: Network access controls (HTTP, HTTPS, SSH)

## Application Features

- Web-based automation interface
- MySQL database backend
- Automated scripts for:
  - Data backup
  - Email notifications
  - File organization

## Security Notes

- **SSL/TLS**: All traffic encrypted with Let's Encrypt certificates
- **HSTS**: HTTP Strict Transport Security enabled
- **Database**: In private subnet (not publicly accessible)
- **Credentials**: Stored in AWS Secrets Manager
- **Reverse Proxy**: Flask app only accessible via Nginx (localhost)
- **Security Groups**: HTTP (80), HTTPS (443), and SSH (22) configured
- **WARNING**: SSH (port 22) is currently open to 0.0.0.0/0 - restrict this in production

## Maintenance

### Update Application Code
SSH into the EC2 instance and pull latest changes:
```bash
ssh -i terraform/py-auto-ui-key.pem ec2-user@<instance-ip>
cd /opt/automation-ui
git pull
sudo systemctl restart automation-ui
```

### View Application Logs
```bash
sudo journalctl -u automation-ui -f
```

### View User Data Execution Log
```bash
sudo cat /var/log/user-data.log
```

## Authentication

The application supports two authentication methods:

### Option 1: AWS Cognito (Recommended)
- OAuth2-based authentication
- Hosted UI for login/signup
- No password management required
- Built-in MFA and security features
- See [Cognito Migration Guide](docs/COGNITO_MIGRATION.md)

### Option 2: Database Authentication (Legacy)
- Traditional username/password
- Stored in MySQL database
- Requires manual user management

To switch between methods, see the migration guide.

## Documentation

See [docs/](docs/) directory for detailed documentation:
- [Cognito Setup Commands](docs/COGNITO_SETUP_COMMANDS.md) - **Quick copy-paste commands** ⚡
- [Cognito Quick Start](docs/COGNITO_QUICK_START.md) - Fast setup guide
- [Cognito Migration Guide](docs/COGNITO_MIGRATION.md) - Complete AWS Cognito guide
- [SSL Setup Guide](docs/SSL_SETUP.md) - SSL certificate and domain configuration
- [MySQL Setup Guide](docs/SETUP_MYSQL.md) - Database configuration

## License

MIT
