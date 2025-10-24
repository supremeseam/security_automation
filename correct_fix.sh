#!/bin/bash
# Correct fix script based on actual Terraform state analysis
# The ALB and Target Group exist in AWS but NOT in Terraform state
# Run from security_automation directory after refreshing AWS credentials

echo "=== Correct Terraform State Fix ==="
echo ""
echo "Analysis: ALB and Target Group exist in AWS but not in Terraform state"
echo ""

cd terraform || exit 1

# Option menu
echo "Do you want to:"
echo "  [1] Import existing ALB and Target Group into Terraform (keep existing resources)"
echo "  [2] Delete existing ALB and Target Group from AWS and let Terraform create new ones"
echo "  [3] Rename Terraform resources to avoid conflict"
read -p "Enter choice (1-3): " choice

if [ "$choice" = "1" ]; then
    echo ""
    echo "Importing existing resources..."

    # Import ALB
    echo "Getting ALB ARN..."
    alb_arn=$(aws elbv2 describe-load-balancers --names py-auto-ui-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text)
    if [ -n "$alb_arn" ] && [ "$alb_arn" != "None" ]; then
        echo "  Importing ALB: $alb_arn"
        terraform import aws_lb.main "$alb_arn"
        echo "  ALB imported successfully!"
    else
        echo "  ERROR: Could not find ALB 'py-auto-ui-alb'"
    fi

    # Import Target Group
    echo "Getting Target Group ARN..."
    tg_arn=$(aws elbv2 describe-target-groups --names py-auto-ui-tg --query 'TargetGroups[0].TargetGroupArn' --output text)
    if [ -n "$tg_arn" ] && [ "$tg_arn" != "None" ]; then
        echo "  Importing Target Group: $tg_arn"
        terraform import aws_lb_target_group.app "$tg_arn"
        echo "  Target Group imported successfully!"
    else
        echo "  ERROR: Could not find Target Group 'py-auto-ui-tg'"
    fi

elif [ "$choice" = "2" ]; then
    echo ""
    echo "To delete existing resources from AWS, run these commands:"
    echo ""
    echo "  # Get the Target Group ARN first"
    echo "  tg_arn=\$(aws elbv2 describe-target-groups --names py-auto-ui-tg --query 'TargetGroups[0].TargetGroupArn' --output text)"
    echo "  aws elbv2 delete-target-group --target-group-arn \$tg_arn"
    echo ""
    echo "  # Get the ALB ARN"
    echo "  alb_arn=\$(aws elbv2 describe-load-balancers --names py-auto-ui-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text)"
    echo "  aws elbv2 delete-load-balancer --load-balancer-arn \$alb_arn"
    echo ""
    echo "After deletion, run: terraform apply"
    echo ""
    exit 0

elif [ "$choice" = "3" ]; then
    echo ""
    echo "To rename resources in Terraform, edit ecs.tf:"
    echo "  - Change the 'name' parameter in aws_lb.main (line ~263)"
    echo "  - Change the 'name' parameter in aws_lb_target_group.app (line ~277)"
    echo "  Example: py-auto-ui-alb-v2, py-auto-ui-tg-v2"
    echo ""
    exit 0
fi

echo ""
echo "Fixing security group rule..."
echo "  Removing duplicate security group rule from Terraform state..."
terraform state rm aws_security_group_rule.db_from_ecs > /dev/null 2>&1
echo "  Done! Rule stays in AWS."

echo ""
echo "Fixing DB subnet group..."

# Check what VPC the subnet group is currently in
if aws rds describe-db-subnet-groups --db-subnet-group-name py-auto-ui-db-subnet-group > /dev/null 2>&1; then
    echo "  DB subnet group exists in AWS"
    echo "  Options:"
    echo "    a) Remove from Terraform state (keeps in AWS)"
    echo "    b) Destroy and recreate with correct VPC"
    read -p "  Choice (a/b): " db_choice

    if [ "$db_choice" = "a" ] || [ "$db_choice" = "A" ]; then
        terraform state rm aws_db_subnet_group.db_subnet_group
        echo "  Removed from Terraform state"
    else
        echo "  Run: terraform destroy -target=aws_db_subnet_group.db_subnet_group"
        echo "  Then: terraform apply"
    fi
fi

echo ""
echo "Running terraform plan..."
terraform plan

echo ""
echo "Fix complete!"
