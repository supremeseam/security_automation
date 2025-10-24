# Manual Fix Commands for Terraform State Issues

## Problem Summary

You have 4 resources that already exist in AWS but aren't in your Terraform state:
1. ALB (Load Balancer)
2. Target Group
3. Security Group Rule (duplicate)
4. DB Subnet Group (VPC mismatch)

## Prerequisites

**IMPORTANT: Refresh your AWS credentials first!**
```bash
aws sso login
# or your authentication method
```

## Solution 1: Quick Automated Fix (Recommended)

Run this script which will:
- Import the ALB and Target Group
- Remove the duplicate security group rule from Terraform (keeps it in AWS)
- Remove the DB subnet group from Terraform (keeps it in AWS)

```powershell
.\quick_fix.ps1
```

## Solution 2: Manual Step-by-Step Fix

If you prefer to do it manually, follow these commands from the `terraform` directory:

```bash
cd terraform
```

### 1. Import ALB
```bash
# Get the ALB ARN
aws elbv2 describe-load-balancers --names py-auto-ui-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text

# Import it (replace <ARN> with the actual ARN from above)
terraform import aws_lb.main <ARN>
```

### 2. Import Target Group
```bash
# Get the Target Group ARN
aws elbv2 describe-target-groups --names py-auto-ui-tg --query 'TargetGroups[0].TargetGroupArn' --output text

# Import it (replace <ARN> with the actual ARN from above)
terraform import aws_lb_target_group.app <ARN>
```

### 3. Fix Security Group Rule (Choose ONE option)

**Option A: Remove from Terraform (Recommended)**
```bash
# Remove from Terraform state - rule stays in AWS
terraform state rm aws_security_group_rule.db_from_ecs
```

**Option B: Comment out in code**
Edit [ecs.tf:362-370](terraform/ecs.tf#L362) and comment out or delete the resource:
```hcl
# resource "aws_security_group_rule" "db_from_ecs" {
#   type                     = "ingress"
#   from_port                = 3306
#   to_port                  = 3306
#   protocol                 = "tcp"
#   security_group_id        = aws_security_group.db_sg.id
#   source_security_group_id = aws_security_group.ecs_tasks.id
#   description              = "Allow MySQL from ECS tasks"
# }
```

### 4. Fix DB Subnet Group VPC Mismatch (Choose ONE option)

**Option A: Remove from Terraform (Recommended for now)**
```bash
# Remove from Terraform state - subnet group stays in AWS
terraform state rm aws_db_subnet_group.db_subnet_group
```

**Option B: Destroy and recreate (CAUTION: Affects DB)**
```bash
# First, check if DB instance exists
aws rds describe-db-instances --db-instance-identifier py-auto-ui-db

# If DB exists, you'll need to delete it first (CAUTION: DATA LOSS)
# terraform destroy -target=aws_db_instance.automation_db
# terraform destroy -target=aws_db_subnet_group.db_subnet_group

# Then recreate everything
# terraform apply
```

**Option C: Update Terraform to use existing VPC**
Check what VPC the existing subnet group is in, and update your Terraform to match.

### 5. Verify
```bash
terraform plan
```

If you see "No changes" or only expected changes, you're good!

## Understanding the Issues

### Why ALB and Target Group?
These resources were created previously. Importing them tells Terraform "this resource exists, manage it from now on."

### Why remove Security Group Rule?
It already exists and is working. Rather than trying to import it (complex), we just tell Terraform to ignore it.

### Why DB Subnet Group VPC mismatch?
The existing subnet group references subnets in a different VPC than your current Terraform config. This usually happens when:
- You recreated your VPC
- You're deploying to a different environment
- Previous resources were in a different VPC

**Removing it from Terraform state** means Terraform won't manage it, but it stays in AWS.

## After Fixing

Once `terraform plan` shows no errors (or only expected changes):

```bash
terraform apply
```

## Need Help?

If you still see errors after running these commands, check:
1. Are your AWS credentials valid? (`aws sts get-caller-identity`)
2. Are you in the correct AWS account/region?
3. Do you have permissions to modify these resources?

Run the interactive fix script for guided help:
```powershell
.\fix_terraform_state.ps1
```
