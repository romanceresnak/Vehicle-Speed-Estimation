# S3 bucket for raw videos
resource "aws_s3_bucket" "videos" {
  bucket = "${var.project_name}-videos-${var.environment}"
}

resource "aws_s3_bucket_versioning" "videos" {
  bucket = aws_s3_bucket.videos.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "videos" {
  bucket = aws_s3_bucket.videos.id

  rule {
    id     = "delete-old-videos"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

# S3 bucket for processed results (heatmaps, thumbnails)
resource "aws_s3_bucket" "heatmaps" {
  bucket = "${var.project_name}-heatmaps-${var.environment}"
}

resource "aws_s3_bucket_public_access_block" "heatmaps" {
  bucket = aws_s3_bucket.heatmaps.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "heatmaps" {
  bucket = aws_s3_bucket.heatmaps.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.heatmaps.arn}/*"
      }
    ]
  })
}

# S3 bucket for dashboard (React app)
resource "aws_s3_bucket" "dashboard" {
  bucket = "${var.project_name}-dashboard-${var.environment}"
}

resource "aws_s3_bucket_website_configuration" "dashboard" {
  bucket = aws_s3_bucket.dashboard.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "dashboard" {
  bucket = aws_s3_bucket.dashboard.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "dashboard" {
  bucket = aws_s3_bucket.dashboard.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.dashboard.arn}/*"
      }
    ]
  })
}
