#!/bin/bash
# Simple fix script - addresses the actual issues
# Based on confirmation that ALB and Target Group do NOT exist in AWS
# Run from security_automation directory after refreshing AWS credentials

echo "=== Simple Terraform Fix ==="
echo ""

cd terraform || exit 1

echo "[1/3] Removing duplicate security group rule from Terraform state..."
echo "  (The rule exists in AWS and will stay there)"
if terraform state rm aws_security_group_rule.db_from_ecs > /dev/null 2>&1; then
    echo "  Success!"
else
    echo "  Note: Rule may not exist in state"
fi

echo ""
echo "[2/3] Removing DB subnet group from Terraform state..."
echo "  (VPC mismatch - subnet group exists in different VPC)"
if terraform state rm aws_db_subnet_group.db_subnet_group > /dev/null 2>&1; then
    echo "  Success!"
else
    echo "  Note: Resource may not exist in state"
fi

echo ""
echo "[3/3] About ALB and Target Group errors..."
echo "  You confirmed these DON'T exist in AWS."
echo "  The error suggests Terraform thinks they exist but they don't."
echo "  This might be:"
echo "    - A caching issue"
echo "    - Wrong AWS region"
echo "    - Wrong AWS account"
echo ""

# Check current AWS identity and region
echo "Checking AWS configuration..."
if identity=$(aws sts get-caller-identity 2>&1); then
    echo "  AWS Identity:"
    echo "$identity" | jq '.'
else
    echo "  ERROR: Cannot verify AWS identity (credentials may be expired)"
fi

echo ""
region=$(aws configure get region)
if [ -n "$region" ]; then
    echo "  AWS Region: $region"
else
    echo "  WARNING: No default region configured"
fi

echo ""
echo "Running terraform plan..."
echo ""
terraform plan

echo ""
echo "If you still see ALB/Target Group errors:"
echo "  1. Verify you're in the correct AWS region"
echo "  2. Try: terraform refresh"
echo "  3. Check if resources exist with slightly different names:"
echo "     aws elbv2 describe-load-balancers --output table"
echo ""
