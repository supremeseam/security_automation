# Correct fix script based on actual Terraform state analysis
# The ALB and Target Group exist in AWS but NOT in Terraform state
# Run from security_automation directory after refreshing AWS credentials

Write-Host "=== Correct Terraform State Fix ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Analysis: ALB and Target Group exist in AWS but not in Terraform state" -ForegroundColor Yellow
Write-Host ""

Push-Location
Set-Location -Path "terraform"

# Option 1: Import existing resources (if you want to keep them)
Write-Host "Do you want to:" -ForegroundColor Cyan
Write-Host "  [1] Import existing ALB and Target Group into Terraform (keep existing resources)" -ForegroundColor White
Write-Host "  [2] Delete existing ALB and Target Group from AWS and let Terraform create new ones" -ForegroundColor White
Write-Host "  [3] Rename Terraform resources to avoid conflict" -ForegroundColor White
$choice = Read-Host "Enter choice (1-3)"

if ($choice -eq "1") {
    Write-Host ""
    Write-Host "Importing existing resources..." -ForegroundColor Yellow

    # Import ALB
    Write-Host "Getting ALB ARN..." -ForegroundColor Gray
    $albArn = aws elbv2 describe-load-balancers --names py-auto-ui-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text
    if ($albArn -and $LASTEXITCODE -eq 0) {
        Write-Host "  Importing ALB: $albArn" -ForegroundColor Gray
        terraform import aws_lb.main $albArn
        Write-Host "  ALB imported successfully!" -ForegroundColor Green
    } else {
        Write-Host "  ERROR: Could not find ALB 'py-auto-ui-alb'" -ForegroundColor Red
    }

    # Import Target Group
    Write-Host "Getting Target Group ARN..." -ForegroundColor Gray
    $tgArn = aws elbv2 describe-target-groups --names py-auto-ui-tg --query 'TargetGroups[0].TargetGroupArn' --output text
    if ($tgArn -and $LASTEXITCODE -eq 0) {
        Write-Host "  Importing Target Group: $tgArn" -ForegroundColor Gray
        terraform import aws_lb_target_group.app $tgArn
        Write-Host "  Target Group imported successfully!" -ForegroundColor Green
    } else {
        Write-Host "  ERROR: Could not find Target Group 'py-auto-ui-tg'" -ForegroundColor Red
    }

} elseif ($choice -eq "2") {
    Write-Host ""
    Write-Host "To delete existing resources from AWS, run these commands:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  # Get the Target Group ARN first" -ForegroundColor Gray
    Write-Host "  `$tgArn = aws elbv2 describe-target-groups --names py-auto-ui-tg --query 'TargetGroups[0].TargetGroupArn' --output text" -ForegroundColor White
    Write-Host "  aws elbv2 delete-target-group --target-group-arn `$tgArn" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Get the ALB ARN" -ForegroundColor Gray
    Write-Host "  `$albArn = aws elbv2 describe-load-balancers --names py-auto-ui-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text" -ForegroundColor White
    Write-Host "  aws elbv2 delete-load-balancer --load-balancer-arn `$albArn" -ForegroundColor White
    Write-Host ""
    Write-Host "After deletion, run: terraform apply" -ForegroundColor Yellow
    Write-Host ""
    Pop-Location
    exit

} elseif ($choice -eq "3") {
    Write-Host ""
    Write-Host "To rename resources in Terraform, edit ecs.tf:" -ForegroundColor Yellow
    Write-Host "  - Change the 'name' parameter in aws_lb.main (line ~263)" -ForegroundColor White
    Write-Host "  - Change the 'name' parameter in aws_lb_target_group.app (line ~277)" -ForegroundColor White
    Write-Host "  Example: py-auto-ui-alb-v2, py-auto-ui-tg-v2" -ForegroundColor White
    Write-Host ""
    Pop-Location
    exit
}

Write-Host ""
Write-Host "Fixing security group rule..." -ForegroundColor Yellow
Write-Host "  Removing duplicate security group rule from Terraform state..." -ForegroundColor Gray
terraform state rm aws_security_group_rule.db_from_ecs 2>&1 | Out-Null
Write-Host "  Done! Rule stays in AWS." -ForegroundColor Green

Write-Host ""
Write-Host "Fixing DB subnet group..." -ForegroundColor Yellow

# Check what VPC the subnet group is currently in
$subnetGroupInfo = aws rds describe-db-subnet-groups --db-subnet-group-name py-auto-ui-db-subnet-group 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  DB subnet group exists in AWS" -ForegroundColor Gray
    Write-Host "  Options:" -ForegroundColor Gray
    Write-Host "    a) Remove from Terraform state (keeps in AWS)" -ForegroundColor White
    Write-Host "    b) Destroy and recreate with correct VPC" -ForegroundColor White
    $dbChoice = Read-Host "  Choice (a/b)"

    if ($dbChoice -eq "a" -or $dbChoice -eq "A") {
        terraform state rm aws_db_subnet_group.db_subnet_group
        Write-Host "  Removed from Terraform state" -ForegroundColor Green
    } else {
        Write-Host "  Run: terraform destroy -target=aws_db_subnet_group.db_subnet_group" -ForegroundColor Yellow
        Write-Host "  Then: terraform apply" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Running terraform plan..." -ForegroundColor Cyan
terraform plan

Write-Host ""
Write-Host "Fix complete!" -ForegroundColor Green

Pop-Location
