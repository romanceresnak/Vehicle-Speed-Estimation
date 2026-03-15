# Deployment Scripts

This directory contains helper scripts for deploying and managing the Traffic Speed Analyzer.

## Scripts

### `deploy.sh`
**Interactive** deployment script that:
- Builds Lambda functions
- Deploys infrastructure with Terraform (asks for confirmation)
- Builds and deploys the React dashboard
- Outputs all important endpoints

Usage:
```bash
bash scripts/deploy.sh
```

### `deploy-auto.sh`
**Fully automated** deployment script (no confirmation prompts):
- Same as deploy.sh but uses `terraform apply -auto-approve`
- Use with caution - deploys without asking for confirmation
- Good for CI/CD pipelines or when you trust the changes

Usage:
```bash
bash scripts/deploy-auto.sh
```

### `destroy.sh`
Cleanup script that:
- Empties all S3 buckets
- Destroys all infrastructure with Terraform

Usage:
```bash
bash scripts/destroy.sh
```

### `upload-video.sh`
Helper script to upload videos for processing.

Usage:
```bash
bash scripts/upload-video.sh path/to/video.mp4
```

### `seed-data.py`
Python script to seed demo data into DynamoDB.

**Automatically called by deploy scripts** - you don't need to run this manually.

Manual usage:
```bash
python3 scripts/seed-data.py <table-name> [num-records]
python3 scripts/seed-data.py traffic-speed-analyzer-results-dev 200
```

Generates realistic demo data:
- Vehicle types (65% cars, 20% trucks, 10% buses, 5% motorcycles)
- Speed distribution (70% normal, 15% slow, 15% violations)
- Multiple locations and video sessions
- Random but realistic bounding boxes and confidence scores

### `reseed-demo-data.sh`
Refresh demo data without redeploying infrastructure.

Usage:
```bash
bash scripts/reseed-demo-data.sh
```

Adds 200 new demo records to existing data.

### `clear-data.sh`
Clear all data from DynamoDB table.

Usage:
```bash
bash scripts/clear-data.sh
```

**WARNING:** Deletes ALL records from the results table!

## Prerequisites

All scripts require:
- AWS CLI configured with valid credentials
- Terraform installed
- Node.js and npm installed (for deploy.sh)
- Python 3.11+ (for Lambda builds)

## Notes

- All scripts use `set -e` to exit on errors
- Deploy script prompts for confirmation before applying Terraform changes
- Destroy script requires explicit "yes" confirmation
- Upload script automatically detects bucket name from Terraform state
