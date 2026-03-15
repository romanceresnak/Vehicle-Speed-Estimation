output "video_bucket_name" {
  description = "Name of the videos S3 bucket"
  value       = aws_s3_bucket.videos.bucket
}

output "video_bucket_arn" {
  description = "ARN of the videos S3 bucket"
  value       = aws_s3_bucket.videos.arn
}

output "heatmap_bucket_name" {
  description = "Name of the heatmaps S3 bucket"
  value       = aws_s3_bucket.heatmaps.bucket
}

output "heatmap_bucket_arn" {
  description = "ARN of the heatmaps S3 bucket"
  value       = aws_s3_bucket.heatmaps.arn
}

output "dashboard_bucket_name" {
  description = "Name of the dashboard S3 bucket"
  value       = aws_s3_bucket.dashboard.bucket
}

output "dashboard_bucket_domain_name" {
  description = "Domain name of the dashboard S3 bucket"
  value       = aws_s3_bucket.dashboard.bucket_regional_domain_name
}

output "dashboard_website_endpoint" {
  description = "Website endpoint of the dashboard S3 bucket"
  value       = aws_s3_bucket_website_configuration.dashboard.website_endpoint
}
