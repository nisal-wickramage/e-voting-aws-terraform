#!/bin/bash
# LocalStack Environment Setup
# Source this file to configure AWS credentials for LocalStack deployment
# Usage: source .localstack-setup.sh

export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_REGION="us-east-1"

echo "✓ LocalStack environment configured:"
echo "  AWS_ENDPOINT_URL=$AWS_ENDPOINT_URL"
echo "  AWS_REGION=$AWS_REGION"
echo "  AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID"
echo ""
echo "Ready to run: terragrunt run-all plan"
