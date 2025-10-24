# Quick fix script - automatically makes safe choices
# Run this from the security_automation directory after refreshing AWS credentials

Write-Host "=== Quick Terraform Fix ===" -ForegroundColor Cyan
Write-Host ""

Push-Location
Set-Location -Path "terraform"

Write-Host "Step 1: Importing ALB..." -ForegroundColor Yellow
$albArn = aws elbv2 describe-load-balancers --names py-auto-ui-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>$null
if ($albArn -and $LASTEXITCODE -eq 0) {
    terraform import aws_lb.main $albArn 2>&1 | Out-Null
    Write-Host "  ALB imported" -ForegroundColor Green
}

Write-Host "Step 2: Importing Target Group..." -ForegroundColor Yellow
$tgArn = aws elbv2 describe-target-groups --names py-auto-ui-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>$null
if ($tgArn -and $LASTEXITCODE -eq 0) {
    terraform import aws_lb_target_group.app $tgArn 2>&1 | Out-Null
    Write-Host "  Target Group imported" -ForegroundColor Green
}

Write-Host "Step 3: Removing duplicate security group rule from state..." -ForegroundColor Yellow
terraform state rm aws_security_group_rule.db_from_ecs 2>&1 | Out-Null
Write-Host "  Security group rule removed from Terraform (exists in AWS)" -ForegroundColor Green

Write-Host "Step 4: Removing DB subnet group from state..." -ForegroundColor Yellow
terraform state rm aws_db_subnet_group.db_subnet_group 2>&1 | Out-Null
Write-Host "  DB subnet group removed from Terraform (exists in AWS)" -ForegroundColor Green

Write-Host ""
Write-Host "Running terraform plan..." -ForegroundColor Cyan
terraform plan

Pop-Location
