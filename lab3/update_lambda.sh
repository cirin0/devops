#!/bin/bash

PROJECT_NAME="fastapi-service-3"
REGION="us-east-1"

echo "=== Updating Lambda Function ==="

# Clean up previous package
echo "Cleaning up..."
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

# Get S3 bucket name and Lambda function name
S3_BUCKET="${PROJECT_NAME}-code-$(aws sts get-caller-identity --query Account --output text)"
LAMBDA_FUNCTION="${PROJECT_NAME}-function"

echo "S3 Bucket: $S3_BUCKET"
echo "Lambda Function: $LAMBDA_FUNCTION"

# Upload to S3
echo "Uploading to S3..."
aws s3 cp deployment-package.zip s3://$S3_BUCKET/fastapi-lambda.zip

# Update Lambda function code
echo "Updating Lambda function..."
aws lambda update-function-code \
    --function-name $LAMBDA_FUNCTION \
    --s3-bucket $S3_BUCKET \
    --s3-key fastapi-lambda.zip \
    --region $REGION

# Wait for update to complete
echo "Waiting for function update to complete..."
aws lambda wait function-updated --function-name $LAMBDA_FUNCTION --region $REGION

echo "=== Lambda Update Complete ==="

# Get API URL
API_URL=$(aws cloudformation describe-stacks \
    --stack-name $PROJECT_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
    --output text \
    --region $REGION)

echo "API URL: $API_URL"
echo "Documentation: ${API_URL}docs"
echo "OpenAPI Spec: ${API_URL}openapi.json"

# Test endpoints
echo ""
echo "=== Testing Updated Function ==="
echo "Root endpoint:"
curl -s $API_URL/ | python3 -m json.tool

echo -e "\nHealth check:"
curl -s $API_URL/health | python3 -m json.tool