output "video_processor_function_name" {
  description = "Name of the video processor Lambda function"
  value       = aws_lambda_function.video_processor.function_name
}

output "video_processor_arn" {
  description = "ARN of the video processor Lambda function"
  value       = aws_lambda_function.video_processor.arn
}

output "api_handler_function_name" {
  description = "Name of the API handler Lambda function"
  value       = aws_lambda_function.api_handler.function_name
}

output "api_handler_arn" {
  description = "ARN of the API handler Lambda function"
  value       = aws_lambda_function.api_handler.arn
}

output "api_handler_invoke_arn" {
  description = "Invoke ARN of the API handler Lambda function"
  value       = aws_lambda_function.api_handler.invoke_arn
}
