# Simple fix script - addresses the actual issues
# Based on confirmation that ALB and Target Group do NOT exist in AWS
# Run from security_automation directory after refreshing AWS credentials

Write-Host "=== Simple Terraform Fix ===" -ForegroundColor Cyan
Write-Host ""

Push-Location
Set-Location -Path "terraform"

Write-Host "[1/3] Removing duplicate security group rule from Terraform state..." -ForegroundColor Yellow
Write-Host "  (The rule exists in AWS and will stay there)" -ForegroundColor Gray
terraform state rm aws_security_group_rule.db_from_ecs 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Success!" -ForegroundColor Green
} else {
    Write-Host "  Note: Rule may not exist in state" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[2/3] Removing DB subnet group from Terraform state..." -ForegroundColor Yellow
Write-Host "  (VPC mismatch - subnet group exists in different VPC)" -ForegroundColor Gray
terraform state rm aws_db_subnet_group.db_subnet_group 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Success!" -ForegroundColor Green
} else {
    Write-Host "  Note: Resource may not exist in state" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[3/3] About ALB and Target Group errors..." -ForegroundColor Yellow
Write-Host "  You confirmed these DON'T exist in AWS." -ForegroundColor Gray
Write-Host "  The error suggests Terraform thinks they exist but they don't." -ForegroundColor Gray
Write-Host "  This might be:" -ForegroundColor Gray
Write-Host "    - A caching issue" -ForegroundColor White
Write-Host "    - Wrong AWS region" -ForegroundColor White
Write-Host "    - Wrong AWS account" -ForegroundColor White
Write-Host ""

# Check current AWS identity and region
Write-Host "Checking AWS configuration..." -ForegroundColor Cyan
$identity = aws sts get-caller-identity 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  AWS Identity:" -ForegroundColor Gray
    $identity | Write-Host
} else {
    Write-Host "  ERROR: Cannot verify AWS identity (credentials may be expired)" -ForegroundColor Red
}

Write-Host ""
$region = aws configure get region
if ($region) {
    Write-Host "  AWS Region: $region" -ForegroundColor Gray
} else {
    Write-Host "  WARNING: No default region configured" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Running terraform plan..." -ForegroundColor Cyan
Write-Host ""
terraform plan

Write-Host ""
Write-Host "If you still see ALB/Target Group errors:" -ForegroundColor Yellow
Write-Host "  1. Verify you're in the correct AWS region" -ForegroundColor White
Write-Host "  2. Try: terraform refresh" -ForegroundColor White
Write-Host "  3. Check if resources exist with slightly different names:" -ForegroundColor White
Write-Host "     aws elbv2 describe-load-balancers --output table" -ForegroundColor Gray
Write-Host ""

Pop-Location
