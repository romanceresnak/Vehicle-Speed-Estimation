output "video_bucket_name" {
  description = "Name of the S3 bucket for videos"
  value       = module.s3.video_bucket_name
}

output "dashboard_bucket_name" {
  description = "Name of the S3 bucket for dashboard"
  value       = module.s3.dashboard_bucket_name
}

output "heatmap_bucket_name" {
  description = "Name of the S3 bucket for heatmaps"
  value       = module.s3.heatmap_bucket_name
}

output "dashboard_url" {
  description = "CloudFront URL for the dashboard"
  value       = module.cloudfront.dashboard_url
}

output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = module.api_gateway.api_endpoint
}

output "video_processor_function_name" {
  description = "Name of the video processor Lambda function"
  value       = module.lambda.video_processor_function_name
}

output "results_table_name" {
  description = "Name of the DynamoDB results table"
  value       = module.dynamodb.results_table_name
}
