#!/bin/bash

# Destroy script for Traffic Speed Analyzer
# This script removes all AWS resources

set -e

echo "========================================="
echo "Traffic Speed Analyzer - Destroy"
echo "========================================="
echo ""

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${RED}WARNING: This will delete all resources!${NC}"
echo ""
read -p "Are you sure you want to destroy all infrastructure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${YELLOW}Destroy cancelled${NC}"
    exit 0
fi

# Empty S3 buckets first (required before deletion)
echo ""
echo "Emptying S3 buckets..."

cd terraform

# Get bucket names from Terraform outputs
VIDEO_BUCKET=$(terraform output -raw video_bucket_name 2>/dev/null || echo "")
DASHBOARD_BUCKET=$(terraform output -raw dashboard_bucket_name 2>/dev/null || echo "")
HEATMAP_BUCKET=$(terraform output -raw heatmap_bucket_name 2>/dev/null || echo "")

if [ -n "$VIDEO_BUCKET" ]; then
    echo "Emptying video bucket: $VIDEO_BUCKET"
    aws s3 rm s3://$VIDEO_BUCKET/ --recursive 2>/dev/null || true
fi

if [ -n "$DASHBOARD_BUCKET" ]; then
    echo "Emptying dashboard bucket: $DASHBOARD_BUCKET"
    aws s3 rm s3://$DASHBOARD_BUCKET/ --recursive 2>/dev/null || true
fi

if [ -n "$HEATMAP_BUCKET" ]; then
    echo "Emptying heatmap bucket: $HEATMAP_BUCKET"
    aws s3 rm s3://$HEATMAP_BUCKET/ --recursive 2>/dev/null || true
fi

# Destroy infrastructure
echo ""
echo "Destroying infrastructure..."
terraform destroy -auto-approve

cd ..

echo ""
echo -e "${GREEN}All resources destroyed successfully!${NC}"
