# ECS Deployment Guide

Complete guide for deploying the Security Automation application to AWS ECS with Fargate.

## Architecture Overview

```
Internet
   ↓
Application Load Balancer (ALB)
   ↓
ECS Fargate Tasks (Auto-scaling)
   ↓
RDS MySQL Database (Private Subnet)
```

## Prerequisites

1. **AWS CLI configured** with appropriate credentials
2. **Docker installed** and running
3. **Terraform installed** (v1.0+)
4. **Git repository** with your code

## Step 1: Disable EC2 Deployment (Optional)

If you want to remove the EC2 instance and only use ECS:

```bash
cd terraform

# Comment out or remove the EC2 resources in main.tf
# - aws_instance.app_server
# - aws_key_pair.generated_key
# - tls_private_key.ec2_ssh_key
# - local_file.private_key_pem
```

Or keep both running during migration!

## Step 2: Deploy ECS Infrastructure

```bash
cd terraform

# Initialize Terraform (if not already done)
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply

# Note the outputs:
# - ecr_repository_url
# - alb_dns_name
# - ecs_cluster_name
```

This creates:
- ✅ ECR repository for Docker images
- ✅ ECS cluster
- ✅ ECS task definition
- ✅ Application Load Balancer
- ✅ ECS service (Fargate)
- ✅ CloudWatch log groups
- ✅ IAM roles and policies
- ✅ Security groups

## Step 3: Build and Push Docker Image

### Option A: Using PowerShell (Windows)

```powershell
cd c:\Users\kbigler\OneDrive - Cast & Crew\Desktop\security_automation

# Run the build script
.\build-and-push.ps1 -AwsRegion us-east-1
```

### Option B: Using Bash (Linux/Mac/WSL)

```bash
cd /path/to/security_automation

# Make script executable
chmod +x build-and-push.sh

# Run the build script
./build-and-push.sh us-east-1
```

### Option C: Manual Steps

```bash
# Get your AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
ECR_REPO="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/py-auto-ui-app"

# Authenticate to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO

# Build image
cd app
docker build -t py-auto-ui-app:latest .

# Tag and push
docker tag py-auto-ui-app:latest $ECR_REPO:latest
docker push $ECR_REPO:latest
```

## Step 4: Verify Deployment

### Check ECS Service Status

```bash
aws ecs describe-services \
  --cluster py-auto-ui-cluster \
  --services py-auto-ui-service \
  --region us-east-1
```

### View Application Logs

```bash
# Get the latest task ARN
TASK_ARN=$(aws ecs list-tasks --cluster py-auto-ui-cluster --service py-auto-ui-service --region us-east-1 --query 'taskArns[0]' --output text)

# View logs
aws logs tail /ecs/py-auto-ui --follow --region us-east-1
```

### Access the Application

```bash
# Get the ALB DNS name from Terraform output
terraform output alb_dns_name

# Or from AWS CLI
aws elbv2 describe-load-balancers \
  --names py-auto-ui-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text \
  --region us-east-1
```

Open in browser: `http://<alb-dns-name>`

## Step 5: Update Application

When you make code changes:

```bash
# 1. Commit your changes
git add .
git commit -m "Update application"
git push

# 2. Rebuild and push image
.\build-and-push.ps1

# 3. Force new deployment
aws ecs update-service \
  --cluster py-auto-ui-cluster \
  --service py-auto-ui-service \
  --force-new-deployment \
  --region us-east-1

# 4. Watch the deployment
aws ecs wait services-stable \
  --cluster py-auto-ui-cluster \
  --services py-auto-ui-service \
  --region us-east-1
```

## Monitoring & Debugging

### View ECS Task Status

```bash
# List running tasks
aws ecs list-tasks --cluster py-auto-ui-cluster --region us-east-1

# Describe a specific task
aws ecs describe-tasks \
  --cluster py-auto-ui-cluster \
  --tasks <task-arn> \
  --region us-east-1
```

### CloudWatch Logs

```bash
# Tail logs in real-time
aws logs tail /ecs/py-auto-ui --follow --region us-east-1

# Filter for errors
aws logs filter-log-events \
  --log-group-name /ecs/py-auto-ui \
  --filter-pattern "ERROR" \
  --region us-east-1
```

### Health Check Failures

If tasks keep failing health checks:

1. Check CloudWatch logs for errors
2. Verify database connectivity
3. Check security group rules
4. Verify Secrets Manager permissions

```bash
# Check task stopped reason
aws ecs describe-tasks \
  --cluster py-auto-ui-cluster \
  --tasks <task-arn> \
  --query 'tasks[0].stoppedReason' \
  --region us-east-1
```

## Scaling

### Manual Scaling

```bash
# Scale to 3 tasks
aws ecs update-service \
  --cluster py-auto-ui-cluster \
  --service py-auto-ui-service \
  --desired-count 3 \
  --region us-east-1
```

### Auto-Scaling (Add to Terraform)

```hcl
# Add to ecs.tf
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  name               = "cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
```

## Cost Optimization

### Current Configuration Costs

**Fargate Task (512 CPU, 1024 MB):**
- vCPU: $0.04048/hour × 0.5 = $0.02024/hour
- Memory: $0.004445/GB/hour × 1 = $0.004445/hour
- **Total per task:** ~$0.025/hour or **~$18/month** (1 task running 24/7)

**Application Load Balancer:**
- Fixed cost: **~$16.50/month**
- Data processing: ~$0.008/GB

**Total minimum cost:** ~**$35/month** (1 task)

### Optimization Tips

1. **Use Fargate Spot** for non-critical environments (70% discount)
2. **Scale to zero** during off-hours (requires custom solution)
3. **Use smaller task size** if 512 CPU is overkill
4. **Share ALB** with other services
5. **Use RDS Reserved Instances** (30-60% savings)

## Troubleshooting

### Tasks Won't Start

**Check ECR image:**
```bash
aws ecr describe-images \
  --repository-name py-auto-ui-app \
  --region us-east-1
```

**Check IAM permissions:**
```bash
# Task execution role needs:
# - AmazonECSTaskExecutionRolePolicy
# - Secrets Manager access
```

### Database Connection Issues

```bash
# Verify security group allows ECS tasks
aws ec2 describe-security-groups \
  --group-ids <db-security-group-id> \
  --region us-east-1

# Should have ingress rule from ECS tasks security group
```

### Load Balancer 503 Errors

1. Check target group health
2. Verify container port matches (5000)
3. Check health check path is correct (`/`)
4. Review task logs for startup errors

```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region us-east-1
```

## Rollback

If deployment fails:

```bash
# Option 1: Roll back to previous task definition
aws ecs update-service \
  --cluster py-auto-ui-cluster \
  --service py-auto-ui-service \
  --task-definition py-auto-ui-app:X \
  --region us-east-1

# Option 2: Use previous Docker image
# Tag previous image as latest and force new deployment
```

## Cleanup

To remove all ECS resources:

```bash
cd terraform

# Option 1: Destroy everything
terraform destroy

# Option 2: Just remove ECS (keep RDS)
# Delete ecs.tf file, then:
terraform apply
```

**Note:** This will:
- ✅ Delete all ECS tasks
- ✅ Delete the ECS service and cluster
- ✅ Delete the ALB
- ✅ Keep the ECR repository (contains your images)
- ✅ Keep RDS database

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy to ECS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Login to ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1

      - name: Build and push image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: py-auto-ui-app
          IMAGE_TAG: ${{ github.sha }}
        run: |
          cd app
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest

      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster py-auto-ui-cluster \
            --service py-auto-ui-service \
            --force-new-deployment
```

## Next Steps

- [ ] Set up custom domain with Route 53
- [ ] Add HTTPS with ACM certificate
- [ ] Configure auto-scaling
- [ ] Set up CloudWatch alarms
- [ ] Implement blue/green deployments
- [ ] Add WAF for additional security
- [ ] Set up VPC endpoints to reduce NAT Gateway costs

## Support

For issues:
1. Check CloudWatch logs first
2. Review ECS task events
3. Verify security groups and IAM roles
4. Check this guide's troubleshooting section
