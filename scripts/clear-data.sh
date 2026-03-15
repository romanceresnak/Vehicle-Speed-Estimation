#!/bin/bash

# Helper script to clear all data from DynamoDB table
# Useful for testing or starting fresh

set -e

echo "========================================="
echo "Clear DynamoDB Data"
echo "========================================="
echo ""

# Get table name from Terraform output
cd terraform

if [ ! -f "terraform.tfstate" ]; then
    echo "Error: No Terraform state found. Deploy infrastructure first."
    exit 1
fi

TABLE_NAME=$(terraform output -raw results_table_name 2>/dev/null)

if [ -z "$TABLE_NAME" ]; then
    echo "Error: Could not get table name from Terraform"
    exit 1
fi

cd ..

echo "Table: $TABLE_NAME"
echo ""
echo "WARNING: This will delete ALL data from the table!"
echo ""

read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo "Clearing data..."

# Scan and delete all items
aws dynamodb scan --table-name "$TABLE_NAME" --attributes-to-get "videoId" "timestamp" \
  --query "Items[*].[videoId.S,timestamp.N]" --output text | \
while read videoId timestamp; do
  if [ -n "$videoId" ] && [ -n "$timestamp" ]; then
    aws dynamodb delete-item --table-name "$TABLE_NAME" \
      --key "{\"videoId\": {\"S\": \"$videoId\"}, \"timestamp\": {\"N\": \"$timestamp\"}}" \
      > /dev/null 2>&1
    echo "  Deleted: $videoId / $timestamp"
  fi
done

echo ""
echo "✓ All data cleared from $TABLE_NAME"
