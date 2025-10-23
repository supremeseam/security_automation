# Branch-Based Deployments

Deploy different git branches (dev, staging, prod) to ECS with proper image tagging.

## 🎯 Quick Reference

### Deploy from Dev Branch

**Windows:**
```powershell
# Switch to dev branch
git checkout dev

# Build and push
.\build-and-push.ps1 -GitBranch dev

# Deploy to ECS
cd terraform
terraform apply -var="docker_image_tag=dev" -var="environment=dev"
```

**Linux/Mac:**
```bash
# Switch to dev branch
git checkout dev

# Build and push
./build-and-push.sh us-east-1 "" dev

# Deploy to ECS
cd terraform
terraform apply -var="docker_image_tag=dev" -var="environment=dev"
```

### Deploy from Main Branch

**Windows:**
```powershell
git checkout main
.\build-and-push.ps1 -GitBranch main
cd terraform
terraform apply -var="docker_image_tag=main" -var="environment=prod"
```

**Linux/Mac:**
```bash
git checkout main
./build-and-push.sh us-east-1 "" main
cd terraform
terraform apply -var="docker_image_tag=main" -var="environment=prod"
```

---

## 📦 Image Tagging Strategy

When you run `build-and-push`, it creates **4 Docker image tags**:

| Tag | Example | Use Case |
|-----|---------|----------|
| `latest` | `latest` | Always points to most recent build |
| `<branch>` | `dev`, `main` | Deploy specific branch |
| `<sha>` | `a1b2c3d` | Pin to specific commit |
| `<branch>-<sha>` | `dev-a1b2c3d` | Full traceability |

### Example:
```bash
# On dev branch with commit a1b2c3d
.\build-and-push.ps1 -GitBranch dev

# Creates:
# - your-account.dkr.ecr.us-east-1.amazonaws.com/py-auto-ui-app:latest
# - your-account.dkr.ecr.us-east-1.amazonaws.com/py-auto-ui-app:dev
# - your-account.dkr.ecr.us-east-1.amazonaws.com/py-auto-ui-app:a1b2c3d
# - your-account.dkr.ecr.us-east-1.amazonaws.com/py-auto-ui-app:dev-a1b2c3d
```

---

## 🏗️ Multi-Environment Setup

### Recommended Git Branch Strategy

```
main (production)
  ↑
staging (pre-production testing)
  ↑
dev (development/feature branches)
```

### Terraform Workspaces (Optional)

For completely separate environments:

```bash
# Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Use workspaces
terraform workspace select dev
terraform apply -var="docker_image_tag=dev"

terraform workspace select prod
terraform apply -var="docker_image_tag=main"
```

---

## 📋 Common Workflows

### Workflow 1: Deploy Dev to Test

```bash
# 1. Make changes on dev branch
git checkout dev
# ... make code changes ...
git add .
git commit -m "Add new feature"
git push origin dev

# 2. Build and push dev image
.\build-and-push.ps1 -GitBranch dev

# 3. Deploy to dev environment
cd terraform
terraform apply -var="docker_image_tag=dev" -var="environment=dev"
```

### Workflow 2: Promote Dev to Production

```bash
# 1. Merge dev to main
git checkout main
git merge dev
git push origin main

# 2. Build and push production image
.\build-and-push.ps1 -GitBranch main

# 3. Deploy to production
cd terraform
terraform apply -var="docker_image_tag=main" -var="environment=prod"
```

### Workflow 3: Rollback to Previous Version

```bash
# List available images
aws ecr describe-images --repository-name py-auto-ui-app --region us-east-1

# Deploy specific commit
cd terraform
terraform apply -var="docker_image_tag=a1b2c3d"

# Or use branch tag
terraform apply -var="docker_image_tag=main"
```

### Workflow 4: Quick Hotfix

```bash
# 1. Create hotfix branch
git checkout -b hotfix/critical-bug main

# 2. Fix the bug
# ... make changes ...
git commit -am "Fix critical bug"

# 3. Build and test
.\build-and-push.ps1 -GitBranch hotfix/critical-bug
terraform apply -var="docker_image_tag=hotfix-critical-bug"

# 4. Merge to main and redeploy
git checkout main
git merge hotfix/critical-bug
git push origin main
.\build-and-push.ps1 -GitBranch main
terraform apply -var="docker_image_tag=main"
```

---

## 🔍 Verify Deployment

### Check which image is currently deployed

```bash
# Get current task definition
aws ecs describe-services \
  --cluster py-auto-ui-cluster \
  --services py-auto-ui-service \
  --query 'services[0].taskDefinition' \
  --output text

# View task definition image
aws ecs describe-task-definition \
  --task-definition <task-def-arn> \
  --query 'taskDefinition.containerDefinitions[0].image'
```

### List all available images

```bash
# List all images with tags
aws ecr describe-images \
  --repository-name py-auto-ui-app \
  --region us-east-1 \
  --query 'sort_by(imageDetails, &imagePushedAt)[*].[imageTags[0], imagePushedAt]' \
  --output table
```

---

## 🎛️ Advanced: Environment-Specific Configuration

### Using Terraform Variables

Create environment-specific tfvars files:

**`terraform/dev.tfvars`:**
```hcl
environment        = "dev"
docker_image_tag   = "dev"
db_instance_class  = "db.t3.micro"
```

**`terraform/prod.tfvars`:**
```hcl
environment        = "prod"
docker_image_tag   = "main"
db_instance_class  = "db.t3.small"
```

**Deploy:**
```bash
# Dev
terraform apply -var-file="dev.tfvars"

# Prod
terraform apply -var-file="prod.tfvars"
```

---

## 🚨 Important Notes

### Always Tag Your Commits
```bash
# Tag releases
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# Build with tag
.\build-and-push.ps1
# Creates image with tag: v1.0.0
```

### Never Deploy `latest` to Production
```bash
# ❌ BAD - Can't roll back
terraform apply

# ✅ GOOD - Specific version
terraform apply -var="docker_image_tag=v1.0.0"
```

### Keep Images Clean
```bash
# ECR has a lifecycle policy (keeps last 10 images)
# Older images are automatically deleted

# Manual cleanup if needed
aws ecr batch-delete-image \
  --repository-name py-auto-ui-app \
  --image-ids imageTag=old-tag
```

---

## 🔄 CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy to Dev

on:
  push:
    branches: [dev]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Build and push
        run: ./build-and-push.sh us-east-1 "" dev

      - name: Deploy to ECS
        run: |
          cd terraform
          terraform init
          terraform apply -auto-approve \
            -var="docker_image_tag=dev" \
            -var="environment=dev"
```

---

## 📊 Monitoring Different Environments

### CloudWatch Log Groups by Branch

If you want separate logs per environment, update `ecs.tf`:

```hcl
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = var.environment == "prod" ? 30 : 7
}
```

### View logs:
```bash
# Dev logs
aws logs tail /ecs/py-auto-ui-dev --follow

# Prod logs
aws logs tail /ecs/py-auto-ui-prod --follow
```

---

## 🆘 Troubleshooting

### Wrong image deployed?
```bash
# Check what's running
aws ecs describe-tasks \
  --cluster py-auto-ui-cluster \
  --tasks $(aws ecs list-tasks --cluster py-auto-ui-cluster --service py-auto-ui-service --query 'taskArns[0]' --output text) \
  --query 'tasks[0].containers[0].image'
```

### Image not found?
```bash
# Verify image exists
aws ecr describe-images \
  --repository-name py-auto-ui-app \
  --image-ids imageTag=dev
```

### Force re-deploy specific tag
```bash
cd terraform
terraform apply -var="docker_image_tag=dev" -replace="aws_ecs_task_definition.app"
```

---

## ✅ Best Practices

1. **Always use specific tags in production** - Never deploy `:latest`
2. **Test in dev before promoting** - Always test changes in dev first
3. **Use semantic versioning** - Tag releases as v1.0.0, v1.1.0, etc.
4. **Document deployments** - Keep track of what's deployed where
5. **Automate with CI/CD** - Reduce human error
6. **Monitor after deploy** - Watch logs for 5-10 minutes after deployment
7. **Have a rollback plan** - Know how to quickly revert

---

## 🎯 Quick Commands Cheat Sheet

```bash
# Build from current branch
.\build-and-push.ps1

# Build from specific branch
.\build-and-push.ps1 -GitBranch dev

# Deploy with branch tag
terraform apply -var="docker_image_tag=dev"

# Deploy with commit SHA
terraform apply -var="docker_image_tag=a1b2c3d"

# Force new deployment (same image)
aws ecs update-service --cluster py-auto-ui-cluster --service py-auto-ui-service --force-new-deployment

# View available images
aws ecr describe-images --repository-name py-auto-ui-app --query 'imageDetails[*].imageTags' --output table

# Check current deployment
aws ecs describe-services --cluster py-auto-ui-cluster --services py-auto-ui-service --query 'services[0].deployments'
```

---

Happy deploying! 🚀
