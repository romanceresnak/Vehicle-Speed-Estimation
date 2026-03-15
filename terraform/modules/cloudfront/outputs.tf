output "dashboard_url" {
  description = "CloudFront distribution URL for the dashboard"
  value       = "https://${aws_cloudfront_distribution.dashboard.domain_name}"
}

output "distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.dashboard.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.dashboard.arn
}
