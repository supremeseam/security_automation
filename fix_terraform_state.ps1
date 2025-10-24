# Script to fix Terraform state issues
# Run this from the security_automation directory after refreshing AWS credentials

Write-Host "=== Terraform State Fix Script ===" -ForegroundColor Cyan
Write-Host ""

# Change to terraform directory
Push-Location
Set-Location -Path "terraform"
Write-Host "Working directory: $(Get-Location)" -ForegroundColor Gray
Write-Host ""

# Step 1: Import ALB
Write-Host "[1/5] Importing ALB..." -ForegroundColor Yellow
try {
    $albArn = aws elbv2 describe-load-balancers --names py-auto-ui-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text
    if ($albArn -and $albArn -ne "None" -and $LASTEXITCODE -eq 0) {
        Write-Host "  Found ALB ARN: $albArn" -ForegroundColor Gray
        terraform import aws_lb.main $albArn
        Write-Host "  ALB imported successfully" -ForegroundColor Green
    } else {
        Write-Host "  Warning: Could not find ALB" -ForegroundColor Red
    }
} catch {
    Write-Host "  Error: $_" -ForegroundColor Red
}
Write-Host ""

# Step 2: Import Target Group
Write-Host "[2/5] Importing Target Group..." -ForegroundColor Yellow
try {
    $tgArn = aws elbv2 describe-target-groups --names py-auto-ui-tg --query 'TargetGroups[0].TargetGroupArn' --output text
    if ($tgArn -and $tgArn -ne "None" -and $LASTEXITCODE -eq 0) {
        Write-Host "  Found Target Group ARN: $tgArn" -ForegroundColor Gray
        terraform import aws_lb_target_group.app $tgArn
        Write-Host "  Target Group imported successfully" -ForegroundColor Green
    } else {
        Write-Host "  Warning: Could not find Target Group" -ForegroundColor Red
    }
} catch {
    Write-Host "  Error: $_" -ForegroundColor Red
}
Write-Host ""

# Step 3: Handle Security Group Rule
Write-Host "[3/5] Handling duplicate Security Group Rule..." -ForegroundColor Yellow
Write-Host "  The security group rule already exists in AWS." -ForegroundColor Gray
Write-Host "  Options:" -ForegroundColor Gray
Write-Host "    a) Remove from Terraform state (recommended if rule is correct)" -ForegroundColor White
Write-Host "    b) Import it into Terraform state" -ForegroundColor White
Write-Host ""
$choice = Read-Host "  Remove the duplicate rule from Terraform state? (y/n)"
if ($choice -eq 'y' -or $choice -eq 'Y') {
    Write-Host "  Removing aws_security_group_rule.db_from_ecs from state..." -ForegroundColor Gray
    terraform state rm aws_security_group_rule.db_from_ecs
    Write-Host "  Rule removed from state. It will remain in AWS but won't be managed by Terraform." -ForegroundColor Green
} else {
    Write-Host "  Skipping. You can manually import it later if needed." -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Handle DB Subnet Group VPC Mismatch
Write-Host "[4/5] Handling DB Subnet Group VPC mismatch..." -ForegroundColor Yellow
Write-Host "  The existing DB subnet group is in a different VPC." -ForegroundColor Gray
Write-Host "  Options:" -ForegroundColor Gray
Write-Host "    a) Remove the old DB subnet group and recreate (will affect DB)" -ForegroundColor White
Write-Host "    b) Remove from Terraform state and manage manually" -ForegroundColor White
Write-Host "    c) Check if DB instance exists and plan accordingly" -ForegroundColor White
Write-Host ""

# Check if DB instance exists
$dbExists = $false
try {
    $dbInstance = aws rds describe-db-instances --db-instance-identifier py-auto-ui-db --query 'DBInstances[0].DBInstanceIdentifier' --output text 2>$null
    if ($dbInstance -eq "py-auto-ui-db") {
        $dbExists = $true
        Write-Host "  WARNING: DB instance 'py-auto-ui-db' exists!" -ForegroundColor Red
        Write-Host "  Modifying the subnet group may cause downtime." -ForegroundColor Red
    }
} catch {
    Write-Host "  DB instance does not exist or cannot be accessed." -ForegroundColor Gray
}
Write-Host ""

$dbChoice = Read-Host "  Remove DB subnet group from Terraform state? (y/n)"
if ($dbChoice -eq 'y' -or $dbChoice -eq 'Y') {
    Write-Host "  Removing aws_db_subnet_group.db_subnet_group from state..." -ForegroundColor Gray
    terraform state rm aws_db_subnet_group.db_subnet_group
    Write-Host "  DB subnet group removed from state." -ForegroundColor Green

    if ($dbExists) {
        Write-Host "  Note: The DB instance still uses the old subnet group." -ForegroundColor Yellow
        Write-Host "  You may need to manually recreate the DB in the new VPC." -ForegroundColor Yellow
    }
} else {
    Write-Host "  Keeping DB subnet group in state. You'll need to manually fix the VPC mismatch." -ForegroundColor Yellow
}
Write-Host ""

# Step 5: Verify with terraform plan
Write-Host "[5/5] Running terraform plan to verify..." -ForegroundColor Yellow
Write-Host ""
terraform plan
Write-Host ""

Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "1. Check the terraform plan output above" -ForegroundColor White
Write-Host "2. If you see remaining errors, review the suggestions below:" -ForegroundColor White
Write-Host "   - For DB subnet group: Consider creating new DB in the new VPC" -ForegroundColor White
Write-Host "   - For security rules: They may need manual reconciliation" -ForegroundColor White
Write-Host ""
Write-Host "Script complete!" -ForegroundColor Green

Pop-Location
