variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "video_bucket_name" {
  description = "Name of the S3 bucket for videos"
  type        = string
}

variable "video_bucket_arn" {
  description = "ARN of the S3 bucket for videos"
  type        = string
}

variable "heatmap_bucket_name" {
  description = "Name of the S3 bucket for heatmaps"
  type        = string
}

variable "results_table_name" {
  description = "Name of the DynamoDB results table"
  type        = string
}

variable "results_table_arn" {
  description = "ARN of the DynamoDB results table"
  type        = string
}
