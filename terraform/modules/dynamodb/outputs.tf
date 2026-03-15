output "results_table_name" {
  description = "Name of the results DynamoDB table"
  value       = aws_dynamodb_table.results.name
}

output "results_table_arn" {
  description = "ARN of the results DynamoDB table"
  value       = aws_dynamodb_table.results.arn
}

output "heatmaps_table_name" {
  description = "Name of the heatmaps DynamoDB table"
  value       = aws_dynamodb_table.heatmaps.name
}

output "heatmaps_table_arn" {
  description = "ARN of the heatmaps DynamoDB table"
  value       = aws_dynamodb_table.heatmaps.arn
}
