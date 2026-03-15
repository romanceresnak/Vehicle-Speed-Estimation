variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "dashboard_bucket_name" {
  description = "Name of the dashboard S3 bucket"
  type        = string
}

variable "dashboard_bucket_domain_name" {
  description = "Regional domain name of the dashboard S3 bucket"
  type        = string
}
