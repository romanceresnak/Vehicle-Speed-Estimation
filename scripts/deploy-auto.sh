#!/bin/bash

# Automated Deployment script for Traffic Speed Analyzer
# This script deploys WITHOUT confirmation prompts (use with caution!)

set -e

echo "========================================="
echo "Traffic Speed Analyzer - Auto Deployment"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo -e "${RED}Error: npm is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"
echo ""

# Build Lambda functions
echo "========================================="
echo "Step 1: Building Lambda functions"
echo "========================================="
cd lambda
bash build.sh
cd ..
echo -e "${GREEN}✓ Lambda functions built${NC}"
echo ""

# Deploy infrastructure with Terraform
echo "========================================="
echo "Step 2: Deploying infrastructure"
echo "========================================="
cd terraform

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Apply with auto-approve
echo ""
echo -e "${YELLOW}Applying changes automatically (no confirmation)...${NC}"
terraform apply -auto-approve

# Get outputs
echo ""
echo "Getting infrastructure outputs..."
API_ENDPOINT=$(terraform output -raw api_endpoint)
DASHBOARD_URL=$(terraform output -raw dashboard_url)
VIDEO_BUCKET=$(terraform output -raw video_bucket_name)
DASHBOARD_BUCKET_NAME=$(terraform output -raw dashboard_bucket_name)
RESULTS_TABLE=$(terraform output -raw results_table_name)

cd ..
echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo ""

# Seed demo data
echo "========================================="
echo "Step 3: Seeding demo data to DynamoDB"
echo "========================================="
python3 scripts/seed-data.py "$RESULTS_TABLE" 200
echo -e "${GREEN}✓ Demo data seeded${NC}"
echo ""

# Build and deploy dashboard
echo "========================================="
echo "Step 4: Building and deploying dashboard"
echo "========================================="
cd dashboard

# Install dependencies
echo "Installing dashboard dependencies..."
npm install

# Create .env file with API endpoint
echo "VITE_API_ENDPOINT=$API_ENDPOINT" > .env

# Build
echo "Building dashboard..."
npm run build

# Deploy to S3
echo "Deploying dashboard to S3..."
echo "Uploading to bucket: $DASHBOARD_BUCKET_NAME"
aws s3 sync build/ s3://$DASHBOARD_BUCKET_NAME/ --delete

cd ..
echo -e "${GREEN}✓ Dashboard deployed${NC}"
echo ""

# Summary
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo -e "${GREEN}API Endpoint:${NC} $API_ENDPOINT"
echo -e "${GREEN}Dashboard URL:${NC} $DASHBOARD_URL"
echo -e "${GREEN}Video Bucket:${NC} $VIDEO_BUCKET"
echo ""
echo "To upload a test video:"
echo "  bash scripts/upload-video.sh your-video.mp4"
echo ""
echo -e "${GREEN}Deployment successful!${NC}"
