#!/bin/bash

# Helper script to reseed demo data to DynamoDB
# Use this if you want to refresh the demo data without full redeployment

set -e

echo "========================================="
echo "Reseeding Demo Data"
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

# Ask for confirmation
read -p "This will add 200 new demo records. Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled"
    exit 0
fi

# Run seed script
python3 scripts/seed-data.py "$TABLE_NAME" 200

echo ""
echo "Demo data refreshed!"
echo "Refresh your dashboard to see the new data."
