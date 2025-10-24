#!/bin/bash
# Script to import existing AWS resources into Terraform state

echo "Importing existing AWS resources into Terraform state..."

# Import ECR Repository
echo "Importing ECR repository..."
terraform import aws_ecr_repository.automation_ui py-auto-ui-app

# Import IAM Roles
echo "Importing IAM roles..."
terraform import aws_iam_role.ecs_task_execution_role py-auto-ui-ecs-task-execution-role
terraform import aws_iam_role.ecs_task_role py-auto-ui-ecs-task-role
terraform import aws_iam_role.ecs_worker_task_role py-auto-ui-ecs-worker-task-role

# Import ALB (you'll need the ALB ARN - get it from AWS Console or CLI)
echo "Importing ALB..."
ALB_ARN=$(aws elbv2 describe-load-balancers --names py-auto-ui-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text)
if [ ! -z "$ALB_ARN" ]; then
  terraform import aws_lb.main "$ALB_ARN"
else
  echo "Warning: Could not find ALB ARN for py-auto-ui-alb"
fi

# Import Target Group (you'll need the target group ARN)
echo "Importing target group..."
TG_ARN=$(aws elbv2 describe-target-groups --names py-auto-ui-tg --query 'TargetGroups[0].TargetGroupArn' --output text)
if [ ! -z "$TG_ARN" ]; then
  terraform import aws_lb_target_group.app "$TG_ARN"
else
  echo "Warning: Could not find target group ARN for py-auto-ui-tg"
fi

# Import DB Subnet Group
echo "Importing DB subnet group..."
terraform import aws_db_subnet_group.db_subnet_group py-auto-ui-db-subnet-group

# Note: Security group rules are trickier - you may need to manually handle this
echo ""
echo "Note: For the security group rule, you may need to either:"
echo "1. Remove it from Terraform and let AWS manage it"
echo "2. Import it using: terraform import aws_security_group_rule.db_from_ecs sg-<id>_ingress_tcp_3306_3306_sg-<source-sg-id>"
echo ""
echo "Import complete! Run 'terraform plan' to verify everything is in sync."
