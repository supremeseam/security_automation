#!/bin/bash
# Comprehensive diagnostic and fix script
# Run from security_automation directory

echo "=== Terraform Diagnostic and Fix Script ==="
echo ""

# Change to terraform directory
cd terraform || exit 1

# Step 1: Check AWS credentials and configuration
echo "[Step 1] Checking AWS Configuration..."
echo ""

if ! identity=$(aws sts get-caller-identity 2>&1); then
    echo "  ERROR: AWS credentials are expired or invalid!"
    echo "  Please run: aws sso login"
    exit 1
fi

echo "  AWS Account/User:"
account=$(echo "$identity" | jq -r '.Account')
user_id=$(echo "$identity" | jq -r '.UserId')
echo "    Account: $account"
echo "    UserId: $user_id"
echo ""

region=$(aws configure get region)
if [ -z "$region" ]; then
    region="us-east-1"
fi
echo "  AWS Region: $region"
echo ""

# Step 2: Check what actually exists in AWS
echo "[Step 2] Checking existing AWS resources..."
echo ""

echo "  Load Balancers in region $region:"
if albs=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[*].LoadBalancerName' --output text 2>&1); then
    if [ -n "$albs" ]; then
        echo "$albs" | tr '\t' '\n' | while read -r alb; do
            echo "    - $alb"
        done

        if echo "$albs" | grep -q "py-auto-ui-alb"; then
            echo "    FOUND: py-auto-ui-alb EXISTS"
        else
            echo "    NOT FOUND: py-auto-ui-alb does not exist"
        fi
    else
        echo "    No load balancers found"
    fi
else
    echo "    Error checking load balancers"
fi
echo ""

echo "  Target Groups in region $region:"
if tgs=$(aws elbv2 describe-target-groups --query 'TargetGroups[*].TargetGroupName' --output text 2>&1); then
    if [ -n "$tgs" ]; then
        echo "$tgs" | tr '\t' '\n' | while read -r tg; do
            echo "    - $tg"
        done

        if echo "$tgs" | grep -q "py-auto-ui-tg"; then
            echo "    FOUND: py-auto-ui-tg EXISTS"
        else
            echo "    NOT FOUND: py-auto-ui-tg does not exist"
        fi
    else
        echo "    No target groups found"
    fi
else
    echo "    Error checking target groups"
fi
echo ""

echo "  DB Subnet Groups in region $region:"
if dbsgs=$(aws rds describe-db-subnet-groups --query 'DBSubnetGroups[*].DBSubnetGroupName' --output text 2>&1); then
    if [ -n "$dbsgs" ]; then
        echo "$dbsgs" | tr '\t' '\n' | while read -r dbsg; do
            echo "    - $dbsg"
        done

        if echo "$dbsgs" | grep -q "py-auto-ui-db-subnet-group"; then
            echo "    FOUND: py-auto-ui-db-subnet-group EXISTS"

            # Get VPC info
            vpc_id=$(aws rds describe-db-subnet-groups --db-subnet-group-name py-auto-ui-db-subnet-group --query 'DBSubnetGroups[0].VpcId' --output text)
            echo "    VPC: $vpc_id"
        else
            echo "    NOT FOUND: py-auto-ui-db-subnet-group does not exist"
        fi
    else
        echo "    No DB subnet groups found"
    fi
else
    echo "    Error checking DB subnet groups"
fi
echo ""

# Step 3: Check Terraform state
echo "[Step 3] Checking Terraform state..."
echo ""

state_resources=$(terraform state list)
echo "  Resources in Terraform state:"

has_alb=$(echo "$state_resources" | grep -c "aws_lb.main" || true)
has_tg=$(echo "$state_resources" | grep -c "aws_lb_target_group.app" || true)
has_dbsg=$(echo "$state_resources" | grep -c "aws_db_subnet_group.db_subnet_group" || true)
has_sg_rule=$(echo "$state_resources" | grep -c "aws_security_group_rule.db_from_ecs" || true)

if [ "$has_alb" -gt 0 ]; then
    echo "    ALB (aws_lb.main): IN STATE"
else
    echo "    ALB (aws_lb.main): NOT in state"
fi

if [ "$has_tg" -gt 0 ]; then
    echo "    Target Group (aws_lb_target_group.app): IN STATE"
else
    echo "    Target Group (aws_lb_target_group.app): NOT in state"
fi

if [ "$has_dbsg" -gt 0 ]; then
    echo "    DB Subnet Group (aws_db_subnet_group.db_subnet_group): IN STATE"
else
    echo "    DB Subnet Group (aws_db_subnet_group.db_subnet_group): NOT in state"
fi

if [ "$has_sg_rule" -gt 0 ]; then
    echo "    Security Group Rule (aws_security_group_rule.db_from_ecs): IN STATE"
else
    echo "    Security Group Rule (aws_security_group_rule.db_from_ecs): NOT in state"
fi
echo ""

# Step 4: Apply fixes
echo "[Step 4] Applying fixes..."
echo ""

# Fix security group rule if exists
if [ "$has_sg_rule" -gt 0 ]; then
    echo "  Removing duplicate security group rule from Terraform state..."
    terraform state rm aws_security_group_rule.db_from_ecs > /dev/null 2>&1
    echo "    Done!"
else
    echo "  Security group rule not in state - no action needed"
fi

# Fix DB subnet group if VPC mismatch
if [ "$has_dbsg" -gt 0 ]; then
    echo "  Removing DB subnet group from Terraform state (VPC mismatch)..."
    terraform state rm aws_db_subnet_group.db_subnet_group > /dev/null 2>&1
    echo "    Done!"
    echo "    Note: Subnet group still exists in AWS in the old VPC"
else
    echo "  DB subnet group not in state - no action needed"
fi

echo ""
echo "[Step 5] Running terraform plan..."
echo ""
terraform plan

echo ""
echo "=== Diagnostic Complete ==="
