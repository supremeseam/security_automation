# Terraform Resource Import Instructions

Your Terraform apply failed because resources already exist in AWS. You need to import them into your Terraform state.

## Prerequisites

1. **Refresh AWS Credentials** - Your credentials are currently expired:
   ```bash
   aws sso login
   # or whatever command you use to authenticate
   ```

## Import Commands

Run these commands from the `terraform` directory:

```bash
cd terraform

# Import ECR Repository
terraform import aws_ecr_repository.automation_ui py-auto-ui-app

# Import IAM Roles
terraform import aws_iam_role.ecs_task_execution_role py-auto-ui-ecs-task-execution-role
terraform import aws_iam_role.ecs_task_role py-auto-ui-ecs-task-role
terraform import aws_iam_role.ecs_worker_task_role py-auto-ui-ecs-worker-task-role

# Import DB Subnet Group
terraform import aws_db_subnet_group.db_subnet_group py-auto-ui-db-subnet-group
```

## For ALB and Target Group

You need the ARNs for these. Get them with:

```bash
# Get ALB ARN
aws elbv2 describe-load-balancers --names py-auto-ui-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text

# Then import (replace <ALB_ARN> with actual ARN)
terraform import aws_lb.main <ALB_ARN>

# Get Target Group ARN
aws elbv2 describe-target-groups --names py-auto-ui-tg --query 'TargetGroups[0].TargetGroupArn' --output text

# Then import (replace <TG_ARN> with actual ARN)
terraform import aws_lb_target_group.app <TG_ARN>
```

## For Security Group Rule

The security group rule already exists. You have three options:

### Option 1: Remove from Terraform (Recommended if it's already configured correctly)
Comment out or remove the `aws_security_group_rule.db_from_ecs` resource in [ecs.tf:362](terraform/ecs.tf#L362)

### Option 2: Import it
```bash
# Find the rule details first
terraform import aws_security_group_rule.db_from_ecs 'sg-0d4c39568dfb37732_ingress_tcp_3306_3306_sg-0b020bbdb4514cade'
```

### Option 3: Delete and recreate
Manually delete the rule in AWS console and let Terraform recreate it.

## After Importing

Run to verify everything is synchronized:
```bash
terraform plan
```

If `terraform plan` shows no changes, everything is imported correctly!

## Alternative: Destroy and Recreate (CAUTION)

If you don't need the existing resources, you can destroy them in AWS first:

```bash
# Remove resources from AWS (CAUTION: This deletes them!)
terraform destroy -target=aws_ecr_repository.automation_ui
# ... etc for each resource
```

Then run `terraform apply` to create fresh resources.

## PowerShell Script

Alternatively, run the automated import script:
```powershell
.\import_resources.ps1
```

This will import most resources automatically (requires valid AWS credentials).
