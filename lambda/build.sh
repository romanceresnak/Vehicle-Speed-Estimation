#!/bin/bash

# Build script for Lambda functions

set -e

echo "Building Lambda functions..."

# Build video-processor
echo "Building video-processor..."
cd video-processor
pip install -r requirements.txt -t package/
cp handler.py package/
cd package
zip -r ../deployment.zip .
cd ..
rm -rf package
cd ..

# Build api-handler
echo "Building api-handler..."
cd api-handler
pip install -r requirements.txt -t package/
cp handler.py package/
cd package
zip -r ../deployment.zip .
cd ..
rm -rf package
cd ..

# Create dummy Lambda layer (for Terraform validation)
# Note: In production, you would build OpenCV layer separately
echo "Creating Lambda layer placeholder..."
mkdir -p layers/python
touch layers/python/placeholder.txt
cd layers
zip -r cv-layer.zip python/
cd ..

echo "Lambda functions built successfully!"
echo ""
echo "Files created:"
echo "  - video-processor/deployment.zip"
echo "  - api-handler/deployment.zip"
echo "  - layers/cv-layer.zip"
