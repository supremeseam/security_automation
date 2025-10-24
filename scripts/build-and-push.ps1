# PowerShell script for Windows
# Build and Push Docker Image to ECR
#
# Usage:
#   .\build-and-push.ps1                              # Uses current branch
#   .\build-and-push.ps1 -GitBranch dev               # Build from dev branch
#   .\build-and-push.ps1 -GitBranch main              # Build from main branch

param(
    [string]$AwsRegion = "us-east-1",
    [string]$AwsAccountId = "",
    [string]$GitBranch = ""
)

$ProjectName = "py-auto-ui"

# Get AWS account ID if not provided
if ([string]::IsNullOrEmpty($AwsAccountId)) {
    Write-Host "Getting AWS account ID..."
    $AwsAccountId = (aws sts get-caller-identity --query Account --output text)
}

$EcrRepository = "$AwsAccountId.dkr.ecr.$AwsRegion.amazonaws.com/$ProjectName-app"

# Detect current branch if not specified
if ([string]::IsNullOrEmpty($GitBranch)) {
    try {
        $GitBranch = git rev-parse --abbrev-ref HEAD 2>$null
        if ([string]::IsNullOrEmpty($GitBranch)) {
            $GitBranch = "main"
        }
    } catch {
        $GitBranch = "main"
    }
}

# Get git commit SHA
try {
    $GitSha = git rev-parse --short HEAD 2>$null
    if ([string]::IsNullOrEmpty($GitSha)) {
        $GitSha = "manual"
    }
} catch {
    $GitSha = "manual"
}

Write-Host "=========================================="
Write-Host "Building and pushing Docker image"
Write-Host "=========================================="
Write-Host "AWS Region: $AwsRegion"
Write-Host "AWS Account: $AwsAccountId"
Write-Host "ECR Repository: $EcrRepository"
Write-Host "Git Branch: $GitBranch"
Write-Host "Git SHA: $GitSha"
Write-Host "=========================================="

# Authenticate Docker to ECR
Write-Host "Authenticating to ECR..."
aws ecr get-login-password --region $AwsRegion | docker login --username AWS --password-stdin $EcrRepository

# Build the Docker image
Write-Host "Building Docker image from branch: $GitBranch..."
Push-Location app
docker build -t "${ProjectName}-app:latest" .

# Tag the image with multiple tags
Write-Host "Tagging image..."
docker tag "${ProjectName}-app:latest" "${EcrRepository}:latest"
docker tag "${ProjectName}-app:latest" "${EcrRepository}:$GitSha"
docker tag "${ProjectName}-app:latest" "${EcrRepository}:$GitBranch"
docker tag "${ProjectName}-app:latest" "${EcrRepository}:${GitBranch}-${GitSha}"

# Push the image with all tags
Write-Host "Pushing image to ECR..."
docker push "${EcrRepository}:latest"
docker push "${EcrRepository}:$GitSha"
docker push "${EcrRepository}:$GitBranch"
docker push "${EcrRepository}:${GitBranch}-${GitSha}"

Pop-Location

Write-Host "=========================================="
Write-Host "✅ Image pushed successfully!"
Write-Host "=========================================="
Write-Host "Image tags pushed:"
Write-Host "  - ${EcrRepository}:latest"
Write-Host "  - ${EcrRepository}:$GitBranch"
Write-Host "  - ${EcrRepository}:$GitSha"
Write-Host "  - ${EcrRepository}:${GitBranch}-${GitSha}"
Write-Host ""
Write-Host "To deploy to ECS:"
Write-Host ""
Write-Host "Using 'latest' tag:"
Write-Host "  aws ecs update-service --cluster ${ProjectName}-cluster --service ${ProjectName}-service --force-new-deployment --region $AwsRegion"
Write-Host ""
Write-Host "Using '$GitBranch' tag:"
Write-Host "  cd terraform"
Write-Host "  terraform apply -var=`"docker_image_tag=$GitBranch`""
Write-Host ""
Write-Host "Using specific commit '$GitSha':"
Write-Host "  cd terraform"
Write-Host "  terraform apply -var=`"docker_image_tag=$GitSha`""
