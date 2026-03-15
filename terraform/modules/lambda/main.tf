# IAM Role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda functions
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy-${var.environment}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${var.video_bucket_arn}/*",
          "arn:aws:s3:::${var.heatmap_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = var.results_table_arn
      }
    ]
  })
}

# Lambda Layer for dependencies (OpenCV, numpy, etc.)
# NOTE: For demo purposes, layer is commented out as all dependencies
# are included in the deployment package. Uncomment for production use.
# resource "aws_lambda_layer_version" "cv_layer" {
#   filename            = "${path.module}/../../../lambda/layers/cv-layer.zip"
#   layer_name          = "${var.project_name}-cv-layer"
#   compatible_runtimes = ["python3.11"]
#
#   lifecycle {
#     create_before_destroy = true
#   }
# }

# Video Processor Lambda Function
resource "aws_lambda_function" "video_processor" {
  filename         = "${path.module}/../../../lambda/video-processor/deployment.zip"
  function_name    = "${var.project_name}-video-processor-${var.environment}"
  role            = aws_iam_role.lambda_role.arn
  handler         = "handler.lambda_handler"
  runtime         = "python3.11"
  timeout         = 900
  memory_size     = 3008

  # Layer commented out - dependencies included in deployment package
  # layers = [aws_lambda_layer_version.cv_layer.arn]

  environment {
    variables = {
      RESULTS_TABLE = var.results_table_name
      HEATMAP_BUCKET = var.heatmap_bucket_name
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# S3 Event trigger for video processor
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.video_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.video_bucket_arn
}

resource "aws_s3_bucket_notification" "video_upload" {
  bucket = var.video_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.video_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".mp4"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# API Handler Lambda Function
resource "aws_lambda_function" "api_handler" {
  filename         = "${path.module}/../../../lambda/api-handler/deployment.zip"
  function_name    = "${var.project_name}-api-handler-${var.environment}"
  role            = aws_iam_role.lambda_role.arn
  handler         = "handler.lambda_handler"
  runtime         = "python3.11"
  timeout         = 30
  memory_size     = 512

  environment {
    variables = {
      RESULTS_TABLE = var.results_table_name
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "video_processor" {
  name              = "/aws/lambda/${aws_lambda_function.video_processor.function_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "api_handler" {
  name              = "/aws/lambda/${aws_lambda_function.api_handler.function_name}"
  retention_in_days = 7
}
