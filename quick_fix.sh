#!/bin/bash
# Quick fix script - automatically makes safe choices
# Run this from the security_automation directory after refreshing AWS credentials

echo "=== Quick Terraform Fix ==="
echo ""

cd terraform || exit 1

echo "Step 1: Importing ALB..."
alb_arn=$(aws elbv2 describe-load-balancers --names py-auto-ui-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null)
if [ -n "$alb_arn" ] && [ "$alb_arn" != "None" ]; then
    terraform import aws_lb.main "$alb_arn" > /dev/null 2>&1
    echo "  ALB imported"
fi

echo "Step 2: Importing Target Group..."
tg_arn=$(aws elbv2 describe-target-groups --names py-auto-ui-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)
if [ -n "$tg_arn" ] && [ "$tg_arn" != "None" ]; then
    terraform import aws_lb_target_group.app "$tg_arn" > /dev/null 2>&1
    echo "  Target Group imported"
fi

echo "Step 3: Removing duplicate security group rule from state..."
terraform state rm aws_security_group_rule.db_from_ecs > /dev/null 2>&1
echo "  Security group rule removed from Terraform (exists in AWS)"

echo "Step 4: Removing DB subnet group from state..."
terraform state rm aws_db_subnet_group.db_subnet_group > /dev/null 2>&1
echo "  DB subnet group removed from Terraform (exists in AWS)"

echo ""
echo "Running terraform plan..."
terraform plan
