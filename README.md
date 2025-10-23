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
│   ├── README.md      # Detailed project documentation
│   ├── SETUP_MYSQL.md # MySQL setup guide
│   └── DEPLOYMENT_ISSUES_FIXED.md
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

4. **Access your application**
   - The EC2 instance public IP will be output after deployment
   - Application runs on port 5000
   - SSH access available using the generated PEM key

## Infrastructure Components

- **VPC**: Isolated network with public and private subnets
- **EC2 Instance**: Amazon Linux 2023 running Flask application
- **RDS MySQL**: Managed database in private subnet
- **Secrets Manager**: Secure storage for credentials
- **IAM Roles**: Least-privilege access for EC2 instance
- **Security Groups**: Network access controls

## Application Features

- Web-based automation interface
- MySQL database backend
- Automated scripts for:
  - Data backup
  - Email notifications
  - File organization

## Security Notes

- Database is in private subnet (not publicly accessible)
- Credentials stored in AWS Secrets Manager
- Security groups restrict access appropriately
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

## Documentation

See [docs/](docs/) directory for detailed documentation:
- [Full README](docs/README.md) - Comprehensive project documentation
- [MySQL Setup Guide](docs/SETUP_MYSQL.md) - Database configuration
- [Deployment Issues](docs/DEPLOYMENT_ISSUES_FIXED.md) - Troubleshooting guide

## License

[Your License Here]
