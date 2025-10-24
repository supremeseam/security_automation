# Docker Deployment Guide

This guide covers running the Security Automation application using Docker.

## Prerequisites

- Docker installed (version 20.10+)
- Docker Compose installed (version 2.0+)

## Quick Start (Local Development)

### 1. Set up environment variables

```bash
cp .env.docker .env
# Edit .env with your configuration
```

### 2. Build and start containers

```bash
docker-compose up -d
```

### 3. Access the application

Open your browser to: http://localhost:5000

Default login:
- Username: `admin`
- Password: `admin123`

### 4. View logs

```bash
# All services
docker-compose logs -f

# Just web app
docker-compose logs -f web

# Just database
docker-compose logs -f db
```

### 5. Stop containers

```bash
docker-compose down

# To also remove volumes (database data)
docker-compose down -v
```

---

## Production Deployment on EC2

### Option 1: Docker Compose on EC2

1. **Install Docker on EC2 (Amazon Linux 2023)**

```bash
# SSH into EC2
ssh -i your-key.pem ec2-user@<instance-ip>

# Install Docker
sudo dnf update -y
sudo dnf install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Log out and back in for group changes to take effect
exit
```

2. **Clone repository and deploy**

```bash
# SSH back in
ssh -i your-key.pem ec2-user@<instance-ip>

# Clone repo
git clone <your-repo-url> /home/ec2-user/automation-ui
cd /home/ec2-user/automation-ui

# Create .env file with production values
cp .env.docker .env
nano .env  # Edit with production credentials

# Start services
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs -f
```

3. **Set up systemd service for auto-start**

```bash
sudo tee /etc/systemd/system/automation-ui-docker.service > /dev/null <<EOF
[Unit]
Description=Automation UI Docker Compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ec2-user/automation-ui
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
User=ec2-user

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable automation-ui-docker
sudo systemctl start automation-ui-docker
```

---

### Option 2: Push to ECR and Use ECS

See the ECS deployment section in the main README.

---

## Docker Commands Cheat Sheet

### Build and Run
```bash
# Build image
docker build -t automation-ui ./app

# Run container
docker run -d -p 5000:5000 --env-file .env automation-ui

# Run with interactive shell
docker run -it automation-ui /bin/bash
```

### Management
```bash
# List containers
docker ps

# Stop container
docker stop <container-id>

# Remove container
docker rm <container-id>

# View logs
docker logs <container-id>

# Execute command in container
docker exec -it <container-id> /bin/bash
```

### Cleanup
```bash
# Remove unused images
docker image prune

# Remove all stopped containers
docker container prune

# Remove unused volumes
docker volume prune

# Nuclear option (remove everything)
docker system prune -a
```

---

## Troubleshooting

### Database connection issues

```bash
# Check if database is healthy
docker-compose ps

# Check database logs
docker-compose logs db

# Connect to database directly
docker exec -it automation-db mysql -u dbadmin -p
```

### Application not starting

```bash
# Check app logs
docker-compose logs web

# Check if port 5000 is available
netstat -tlnp | grep 5000

# Restart services
docker-compose restart web
```

### Need to rebuild after code changes

```bash
# Rebuild and restart
docker-compose up -d --build

# Force rebuild without cache
docker-compose build --no-cache
docker-compose up -d
```

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_HOST` | Database hostname | `db` |
| `DB_PORT` | Database port | `3306` |
| `DB_NAME` | Database name | `automation_ui` |
| `DB_USER` | Database username | `dbadmin` |
| `DB_PASSWORD` | Database password | Required |
| `SECRET_KEY` | Flask secret key | Required |

---

## Security Best Practices

1. **Change default passwords** - Never use defaults in production
2. **Use secrets management** - Store credentials in AWS Secrets Manager
3. **Limit network exposure** - Use security groups to restrict access
4. **Keep images updated** - Regularly rebuild with latest base images
5. **Scan for vulnerabilities** - Use `docker scan` or AWS ECR scanning
6. **Use non-root user** - Already configured in Dockerfile
7. **Enable HTTPS** - Use nginx reverse proxy or ALB with SSL

---

## Monitoring

### Health Checks

Both containers have health checks configured:

```bash
# Check health status
docker-compose ps

# Manual health check
curl http://localhost:5000/
```

### Resource Usage

```bash
# Container stats
docker stats

# Specific container
docker stats automation-web
```

---

## Backup and Restore

### Backup Database

```bash
# Export database
docker exec automation-db mysqldump -u dbadmin -p automation_ui > backup.sql

# Or backup entire volume
docker run --rm --volumes-from automation-db -v $(pwd):/backup ubuntu tar czf /backup/mysql-backup.tar.gz /var/lib/mysql
```

### Restore Database

```bash
# Import database
docker exec -i automation-db mysql -u dbadmin -p automation_ui < backup.sql
```

---

## Next Steps

- Set up CI/CD pipeline to build and push images
- Configure AWS ECR for private image registry
- Deploy to ECS/EKS for production scalability
- Add nginx reverse proxy for SSL termination
- Configure CloudWatch logs integration
