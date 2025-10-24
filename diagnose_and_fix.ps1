# Comprehensive diagnostic and fix script
# Run from security_automation directory

Write-Host "=== Terraform Diagnostic and Fix Script ===" -ForegroundColor Cyan
Write-Host ""

Push-Location
Set-Location -Path "terraform"

# Step 1: Check AWS credentials and configuration
Write-Host "[Step 1] Checking AWS Configuration..." -ForegroundColor Yellow
Write-Host ""

$identity = aws sts get-caller-identity 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: AWS credentials are expired or invalid!" -ForegroundColor Red
    Write-Host "  Please run: aws sso login" -ForegroundColor Yellow
    Pop-Location
    exit 1
}

Write-Host "  AWS Account/User:" -ForegroundColor Gray
$identityJson = $identity | ConvertFrom-Json
Write-Host "    Account: $($identityJson.Account)" -ForegroundColor White
Write-Host "    UserId: $($identityJson.UserId)" -ForegroundColor White
Write-Host ""

$region = aws configure get region
if (-not $region) { $region = "us-east-1" }
Write-Host "  AWS Region: $region" -ForegroundColor Gray
Write-Host ""

# Step 2: Check what actually exists in AWS
Write-Host "[Step 2] Checking existing AWS resources..." -ForegroundColor Yellow
Write-Host ""

Write-Host "  Load Balancers in region $region" ":" -ForegroundColor Gray
$albs = aws elbv2 describe-load-balancers --query 'LoadBalancers[*].LoadBalancerName' --output text 2>&1
if ($LASTEXITCODE -eq 0 -and $albs) {
    $albList = $albs -split '\s+'
    $albList | ForEach-Object { Write-Host "    - $_" -ForegroundColor White }

    if ($albList -contains "py-auto-ui-alb") {
        Write-Host "    FOUND: py-auto-ui-alb EXISTS" -ForegroundColor Green
    } else {
        Write-Host "    NOT FOUND: py-auto-ui-alb does not exist" -ForegroundColor Red
    }
} else {
    Write-Host "    No load balancers found (or error)" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "  Target Groups in region $region" ":" -ForegroundColor Gray
$tgs = aws elbv2 describe-target-groups --query 'TargetGroups[*].TargetGroupName' --output text 2>&1
if ($LASTEXITCODE -eq 0 -and $tgs) {
    $tgList = $tgs -split '\s+'
    $tgList | ForEach-Object { Write-Host "    - $_" -ForegroundColor White }

    if ($tgList -contains "py-auto-ui-tg") {
        Write-Host "    FOUND: py-auto-ui-tg EXISTS" -ForegroundColor Green
    } else {
        Write-Host "    NOT FOUND: py-auto-ui-tg does not exist" -ForegroundColor Red
    }
} else {
    Write-Host "    No target groups found (or error)" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "  DB Subnet Groups in region $region" ":" -ForegroundColor Gray
$dbSubnetGroups = aws rds describe-db-subnet-groups --query 'DBSubnetGroups[*].DBSubnetGroupName' --output text 2>&1
if ($LASTEXITCODE -eq 0 -and $dbSubnetGroups) {
    $dbsgList = $dbSubnetGroups -split '\s+'
    $dbsgList | ForEach-Object { Write-Host "    - $_" -ForegroundColor White }

    if ($dbsgList -contains "py-auto-ui-db-subnet-group") {
        Write-Host "    FOUND: py-auto-ui-db-subnet-group EXISTS" -ForegroundColor Green

        # Get VPC info
        $dbsgInfo = aws rds describe-db-subnet-groups --db-subnet-group-name py-auto-ui-db-subnet-group --query 'DBSubnetGroups[0].VpcId' --output text
        Write-Host "    VPC: $dbsgInfo" -ForegroundColor Gray
    } else {
        Write-Host "    NOT FOUND: py-auto-ui-db-subnet-group does not exist" -ForegroundColor Red
    }
} else {
    Write-Host "    No DB subnet groups found (or error)" -ForegroundColor Yellow
}
Write-Host ""

# Step 3: Check Terraform state
Write-Host "[Step 3] Checking Terraform state..." -ForegroundColor Yellow
Write-Host ""

$stateResources = terraform state list
Write-Host "  Resources in Terraform state:" -ForegroundColor Gray

$hasALB = $stateResources | Where-Object { $_ -like "*aws_lb.main*" }
$hasTG = $stateResources | Where-Object { $_ -like "*aws_lb_target_group.app*" }
$hasDBSG = $stateResources | Where-Object { $_ -like "*aws_db_subnet_group.db_subnet_group*" }
$hasSGRule = $stateResources | Where-Object { $_ -like "*aws_security_group_rule.db_from_ecs*" }

Write-Host "    ALB (aws_lb.main): $(if ($hasALB) { 'IN STATE' } else { 'NOT in state' })" -ForegroundColor $(if ($hasALB) { 'Green' } else { 'Red' })
Write-Host "    Target Group (aws_lb_target_group.app): $(if ($hasTG) { 'IN STATE' } else { 'NOT in state' })" -ForegroundColor $(if ($hasTG) { 'Green' } else { 'Red' })
Write-Host "    DB Subnet Group (aws_db_subnet_group.db_subnet_group): $(if ($hasDBSG) { 'IN STATE' } else { 'NOT in state' })" -ForegroundColor $(if ($hasDBSG) { 'Green' } else { 'Red' })
Write-Host "    Security Group Rule (aws_security_group_rule.db_from_ecs): $(if ($hasSGRule) { 'IN STATE' } else { 'NOT in state' })" -ForegroundColor $(if ($hasSGRule) { 'Green' } else { 'Red' })
Write-Host ""

# Step 4: Apply fixes
Write-Host "[Step 4] Applying fixes..." -ForegroundColor Yellow
Write-Host ""

# Fix security group rule if exists
if ($hasSGRule) {
    Write-Host "  Removing duplicate security group rule from Terraform state..." -ForegroundColor Gray
    terraform state rm aws_security_group_rule.db_from_ecs | Out-Null
    Write-Host "    Done!" -ForegroundColor Green
} else {
    Write-Host "  Security group rule not in state - no action needed" -ForegroundColor Gray
}

# Fix DB subnet group if VPC mismatch
if ($hasDBSG) {
    Write-Host "  Removing DB subnet group from Terraform state (VPC mismatch)..." -ForegroundColor Gray
    terraform state rm aws_db_subnet_group.db_subnet_group | Out-Null
    Write-Host "    Done!" -ForegroundColor Green
    Write-Host "    Note: Subnet group still exists in AWS in the old VPC" -ForegroundColor Yellow
} else {
    Write-Host "  DB subnet group not in state - no action needed" -ForegroundColor Gray
}

Write-Host ""
Write-Host "[Step 5] Running terraform plan..." -ForegroundColor Yellow
Write-Host ""
terraform plan

Write-Host ""
Write-Host "=== Diagnostic Complete ===" -ForegroundColor Cyan

Pop-Location
