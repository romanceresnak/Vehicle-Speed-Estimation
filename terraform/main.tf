terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = var.tags
  }
}

# S3 Buckets
module "s3" {
  source = "./modules/s3"
  
  project_name = var.project_name
  environment  = var.environment
}

# DynamoDB Tables
module "dynamodb" {
  source = "./modules/dynamodb"
  
  project_name = var.project_name
  environment  = var.environment
}

# Lambda Functions
module "lambda" {
  source = "./modules/lambda"
  
  project_name              = var.project_name
  environment               = var.environment
  video_bucket_name         = module.s3.video_bucket_name
  video_bucket_arn          = module.s3.video_bucket_arn
  results_table_name        = module.dynamodb.results_table_name
  results_table_arn         = module.dynamodb.results_table_arn
  heatmap_bucket_name       = module.s3.heatmap_bucket_name
}

# API Gateway
module "api_gateway" {
  source = "./modules/api-gateway"
  
  project_name       = var.project_name
  environment        = var.environment
  lambda_invoke_arn  = module.lambda.api_handler_invoke_arn
  lambda_function_name = module.lambda.api_handler_function_name
}

# CloudFront for Dashboard
module "cloudfront" {
  source = "./modules/cloudfront"
  
  project_name         = var.project_name
  environment          = var.environment
  dashboard_bucket_name = module.s3.dashboard_bucket_name
  dashboard_bucket_domain_name = module.s3.dashboard_bucket_domain_name
}
