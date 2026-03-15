#!/bin/bash

# Helper script to upload video to S3 for processing

set -e

if [ -z "$1" ]; then
    echo "Usage: ./upload-video.sh <video-file>"
    echo "Example: ./upload-video.sh test-video.mp4"
    exit 1
fi

VIDEO_FILE=$1

if [ ! -f "$VIDEO_FILE" ]; then
    echo "Error: File not found: $VIDEO_FILE"
    exit 1
fi

# Get bucket name from Terraform output
cd terraform
BUCKET_NAME=$(terraform output -raw video_bucket_name 2>/dev/null)

if [ -z "$BUCKET_NAME" ]; then
    echo "Error: Could not get bucket name from Terraform"
    echo "Make sure you have deployed the infrastructure first"
    exit 1
fi

cd ..

echo "Uploading $VIDEO_FILE to s3://$BUCKET_NAME/"
aws s3 cp "$VIDEO_FILE" "s3://$BUCKET_NAME/"

echo ""
echo "Video uploaded successfully!"
echo "Processing will start automatically."
echo ""
echo "To monitor processing:"
echo "  aws logs tail /aws/lambda/traffic-speed-analyzer-video-processor-dev --follow"
