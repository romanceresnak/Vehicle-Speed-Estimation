# Quick Start Guide

Get the Traffic Speed Analyzer running in 5 minutes!

## Prerequisites

- AWS Account with credentials configured
- Terraform >= 1.0
- AWS CLI
- Node.js >= 18
- Python 3.11+

## Step-by-Step

### 1. Configure AWS

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: eu-west-1 (or your preferred region)
```

### 2. Clone and Navigate

```bash
cd "/Users/romanceresnak/AWS Hero/02. Vehicle Speed Estimation"
```

### 3. Deploy Everything

```bash
bash scripts/deploy.sh
```

This single command will:
- Build Lambda functions with dependencies
- Deploy all AWS infrastructure (S3, Lambda, DynamoDB, API Gateway, CloudFront)
- **Automatically seed 200 demo records** into DynamoDB (realistic traffic data)
- Build and deploy the React dashboard
- Output all endpoints

Wait ~5-10 minutes for deployment to complete.

### 4. Access Your Dashboard

After deployment completes, you'll see:
```
Dashboard URL: https://d1234567890.cloudfront.net
API Endpoint: https://api-id.execute-api.eu-west-1.amazonaws.com/dev/results
Video Bucket: traffic-speed-analyzer-videos-dev
```

Open the Dashboard URL in your browser!

**Dashboard will already show demo data:**
- 200 traffic records
- Mix of cars, trucks, buses, motorcycles
- Realistic speed distribution (50-130 km/h)
- ~15% speeding violations
- Multiple locations and sessions

### 5. Upload a Test Video (Optional)

```bash
bash scripts/upload-video.sh your-video.mp4
```

The system will automatically:
- Process the video
- Detect vehicles
- Estimate speeds
- Update the dashboard

## What You Get

- **S3 Buckets**: For videos, processed results, and dashboard hosting
- **Lambda Functions**: Serverless video processing and API
- **DynamoDB Tables**: NoSQL database for results
- **API Gateway**: REST API for querying data
- **CloudFront**: CDN for global dashboard access
- **React Dashboard**: Analytics interface with charts and heatmaps

## Cleanup

When you're done:

```bash
bash scripts/destroy.sh
```

This removes all AWS resources and stops billing.

## Cost Estimate

For demo/testing (~10 videos):
- **Free tier**: Most services covered
- **Estimated cost**: $5-15/month
- **Tip**: Run destroy.sh when not in use to minimize costs

## Need Help?

Check the main [README.md](README.md) for:
- Detailed architecture
- Manual deployment steps
- Troubleshooting guide
- Development tips

## Next Steps

1. **Customize**: Edit `terraform/terraform.tfvars` for your settings
2. **Real YOLO**: Integrate actual YOLOv8 model (currently using mock)
3. **Add videos**: Use BrnoCompSpeed dataset for realistic testing
4. **Monitor**: Check CloudWatch logs for processing status

Enjoy building!
