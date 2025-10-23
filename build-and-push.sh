#!/bin/bash
set -e

# Build and Push Docker Image to ECR
# Usage: ./build-and-push.sh [aws-region] [aws-account-id] [git-branch]
# Examples:
#   ./build-and-push.sh                    # Uses defaults (main/master branch)
#   ./build-and-push.sh us-east-1 "" dev   # Deploy from dev branch
#   ./build-and-push.sh us-east-1 "" main  # Deploy from main branch

AWS_REGION="${1:-us-east-1}"
AWS_ACCOUNT_ID="${2}"
GIT_BRANCH="${3}"
PROJECT_NAME="py-auto-ui"

# Get AWS account ID if not provided
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "Getting AWS account ID..."
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
fi

ECR_REPOSITORY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT_NAME}-app"

# Detect current branch if not specified
if [ -z "$GIT_BRANCH" ]; then
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
fi

# Get git commit SHA
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "manual")

echo "=========================================="
echo "Building and pushing Docker image"
echo "=========================================="
echo "AWS Region: $AWS_REGION"
echo "AWS Account: $AWS_ACCOUNT_ID"
echo "ECR Repository: $ECR_REPOSITORY"
echo "Git Branch: $GIT_BRANCH"
echo "Git SHA: $GIT_SHA"
echo "=========================================="

# Authenticate Docker to ECR
echo "Authenticating to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY

# Build the Docker image
echo "Building Docker image from branch: $GIT_BRANCH..."
cd app
docker build -t ${PROJECT_NAME}-app:latest .

# Tag the image with multiple tags
echo "Tagging image..."
docker tag ${PROJECT_NAME}-app:latest $ECR_REPOSITORY:latest
docker tag ${PROJECT_NAME}-app:latest $ECR_REPOSITORY:$GIT_SHA
docker tag ${PROJECT_NAME}-app:latest $ECR_REPOSITORY:$GIT_BRANCH
docker tag ${PROJECT_NAME}-app:latest $ECR_REPOSITORY:${GIT_BRANCH}-${GIT_SHA}

# Push the image with all tags
echo "Pushing image to ECR..."
docker push $ECR_REPOSITORY:latest
docker push $ECR_REPOSITORY:$GIT_SHA
docker push $ECR_REPOSITORY:$GIT_BRANCH
docker push $ECR_REPOSITORY:${GIT_BRANCH}-${GIT_SHA}

echo "=========================================="
echo "✅ Image pushed successfully!"
echo "=========================================="
echo "Image tags pushed:"
echo "  - $ECR_REPOSITORY:latest"
echo "  - $ECR_REPOSITORY:$GIT_BRANCH"
echo "  - $ECR_REPOSITORY:$GIT_SHA"
echo "  - $ECR_REPOSITORY:${GIT_BRANCH}-${GIT_SHA}"
echo ""
echo "To deploy to ECS:"
echo ""
echo "Using 'latest' tag:"
echo "  aws ecs update-service --cluster ${PROJECT_NAME}-cluster --service ${PROJECT_NAME}-service --force-new-deployment --region $AWS_REGION"
echo ""
echo "Using '$GIT_BRANCH' tag:"
echo "  cd terraform"
echo "  terraform apply -var=\"docker_image_tag=$GIT_BRANCH\""
echo ""
echo "Using specific commit '$GIT_SHA':"
echo "  cd terraform"
echo "  terraform apply -var=\"docker_image_tag=$GIT_SHA\""
