# DynamoDB table for speed estimation results
resource "aws_dynamodb_table" "results" {
  name         = "${var.project_name}-results-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "videoId"
  range_key    = "timestamp"

  attribute {
    name = "videoId"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "location"
    type = "S"
  }

  global_secondary_index {
    name            = "LocationIndex"
    hash_key        = "location"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-results"
  }
}

# DynamoDB table for heatmap metadata
resource "aws_dynamodb_table" "heatmaps" {
  name         = "${var.project_name}-heatmaps-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "location"
  range_key    = "date"

  attribute {
    name = "location"
    type = "S"
  }

  attribute {
    name = "date"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name = "${var.project_name}-heatmaps"
  }
}
