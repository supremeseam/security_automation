#!/bin/bash
# Script to import existing AWS resources into Terraform state

echo "Importing existing AWS resources into Terraform state..."

# Change to terraform directory
cd terraform || exit 1
echo "Working directory: $(pwd)"

# Import ECR Repository
echo ""
echo "Importing ECR repository..."
terraform import aws_ecr_repository.automation_ui py-auto-ui-app

# Import IAM Roles
echo ""
echo "Importing IAM roles..."
terraform import aws_iam_role.ecs_task_execution_role py-auto-ui-ecs-task-execution-role
terraform import aws_iam_role.ecs_task_role py-auto-ui-ecs-task-role
terraform import aws_iam_role.ecs_worker_task_role py-auto-ui-ecs-worker-task-role

# Import ALB
echo ""
echo "Importing ALB..."
alb_arn=$(aws elbv2 describe-load-balancers --names py-auto-ui-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text)
if [ -n "$alb_arn" ] && [ "$alb_arn" != "None" ]; then
    terraform import aws_lb.main "$alb_arn"
else
    echo "Warning: Could not find ALB ARN for py-auto-ui-alb"
fi

# Import Target Group
echo ""
echo "Importing target group..."
tg_arn=$(aws elbv2 describe-target-groups --names py-auto-ui-tg --query 'TargetGroups[0].TargetGroupArn' --output text)
if [ -n "$tg_arn" ] && [ "$tg_arn" != "None" ]; then
    terraform import aws_lb_target_group.app "$tg_arn"
else
    echo "Warning: Could not find target group ARN for py-auto-ui-tg"
fi

# Import DB Subnet Group
echo ""
echo "Importing DB subnet group..."
terraform import aws_db_subnet_group.db_subnet_group py-auto-ui-db-subnet-group

# Note about security group rules
echo ""
echo "Note: For the security group rule, you may need to either:"
echo "1. Remove it from Terraform and let AWS manage it"
echo "2. Import it using: terraform import aws_security_group_rule.db_from_ecs 'sg-<id>_ingress_tcp_3306_3306_sg-<source-sg-id>'"
echo ""
echo "Import complete! Run 'terraform plan' to verify everything is in sync."
