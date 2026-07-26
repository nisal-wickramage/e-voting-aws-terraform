# S3 Bucket for Frontend Assets (private, CloudFront-only access)
resource "aws_s3_bucket" "frontend" {
  bucket_prefix = "${var.project_name}-${var.environment}-frontend-"

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-frontend"
    Environment = var.environment
    Module      = "s3-frontend"
  })
}

# Block all public access (enforce CloudFront-only)
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for disaster recovery
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status     = var.enable_versioning ? "Enabled" : "Suspended"
    mfa_delete = var.environment == "prod" ? "Enabled" : "Disabled"
  }
}

# Server-side encryption with S3 managed keys
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enable access logging (optional)
resource "aws_s3_bucket_logging" "frontend" {
  count  = var.enable_logging ? 1 : 0
  bucket = aws_s3_bucket.frontend.id

  target_bucket = var.logging_bucket
  target_prefix = "${var.project_name}-${var.environment}-frontend/"
}

# Bucket policy: Allow CloudFront OAI to read objects only
resource "aws_cloudfront_origin_access_identity" "s3_oai" {
  comment = "OAI for ${var.project_name}-${var.environment}-frontend"
}

resource "aws_s3_bucket_policy" "frontend_cloudfront_only" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAIRead"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.s3_oai.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })
}

# CORS configuration (if frontend needs to make cross-origin requests)
resource "aws_s3_bucket_cors_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }
}
