#!/bin/bash

# Script to create EC2 key pair
# Run this after refreshing your AWS credentials

echo "Creating EC2 key pair 'ec2-key-pair'..."

aws ec2 create-key-pair \
  --key-name ec2-key-pair \
  --region us-east-1 \
  --query 'KeyMaterial' \
  --output text > ec2-key-pair.pem

if [ $? -eq 0 ]; then
  echo "✓ Key pair created successfully!"
  echo "✓ Private key saved to ec2-key-pair.pem"

  # Set proper permissions on Linux/Mac
  if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "win32" ]]; then
    chmod 400 ec2-key-pair.pem
    echo "✓ Set permissions to 400"
  fi

  echo ""
  echo "Next steps:"
  echo "1. Run: terraform apply"
  echo "2. To SSH later: ssh -i ec2-key-pair.pem ec2-user@<instance-ip>"
else
  echo "✗ Failed to create key pair"
  echo "Make sure your AWS credentials are valid"
  exit 1
fi
