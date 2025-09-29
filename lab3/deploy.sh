#!/bin/bash

PROJECT_NAME="fastapi-service-3"
STACK_NAME="fastapi-service-3"
REGION="us-east-1"

echo "=== FastAPI AWS Deployment ==="

# Clean up
echo "Cleaning previous builds..."
rm -rf package deployment-package.zip

# Create package directory
echo "Creating deployment package..."
mkdir -p package

# Install dependencies
echo "Installing dependencies..."
pip install fastapi mangum -t ./package/

# Copy Lambda function
echo "Copying Lambda function..."
cp lambda_function.py package/

# Create ZIP package
echo "Creating ZIP package..."
cd package
zip -r ../deployment-package.zip .
cd ..

# Get S3 bucket name
S3_BUCKET="${PROJECT_NAME}-code-$(aws sts get-caller-identity --query Account --output text)"
echo "S3 Bucket: $S3_BUCKET"

# Create S3 bucket if it doesn't exist
echo "Creating S3 bucket if it doesn't exist..."
aws s3api head-bucket --bucket $S3_BUCKET 2>/dev/null || aws s3 mb s3://$S3_BUCKET --region $REGION

# Upload to S3
echo "Uploading to S3..."
aws s3 cp deployment-package.zip s3://$S3_BUCKET/fastapi-lambda.zip

# Verify upload
echo "Verifying S3 upload..."
aws s3api head-object --bucket $S3_BUCKET --key fastapi-lambda.zip

# Deploy CloudFormation
echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file template.yaml \
    --stack-name $STACK_NAME \
    --parameter-overrides ProjectName=$PROJECT_NAME \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION

# Check if deployment was successful
if [ $? -eq 0 ]; then
    echo "Stack deployment successful"
else
    echo "Stack deployment failed. Checking events..."
    aws cloudformation describe-stack-events --stack-name $STACK_NAME --query 'StackEvents[?ResourceStatus==`CREATE_FAILED` || ResourceStatus==`UPDATE_FAILED`]'
    exit 1
fi

# Get outputs
API_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
    --output text \
    --region $REGION)

LAMBDA_NAME=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`LambdaFunctionName`].OutputValue' \
    --output text \
    --region $REGION)

S3_BUCKET_OUT=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
    --output text \
    --region $REGION)

echo "=== Deployment Complete ==="
echo "API URL: $API_URL"
echo "Lambda Function: $LAMBDA_NAME"
echo "S3 Bucket: $S3_BUCKET_OUT"

# Test endpoints only if API_URL is not empty
if [ "$API_URL" != "None" ] && [ -n "$API_URL" ]; then
    echo ""
    echo "=== Testing Endpoints ==="
    echo "Root endpoint:"
    curl -s $API_URL/ | python3 -m json.tool || echo "Failed to get root endpoint"

    echo -e "\nHealth check:"
    curl -s $API_URL/health | python3 -m json.tool || echo "Failed to get health endpoint"
else
    echo "API URL not available - skipping endpoint tests"
fi