# ── Generated images bucket ─────────────────────────────────────────────────

resource "aws_s3_bucket" "images" {
  bucket = "ai-myoa-images-${var.environment}"
}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket = aws_s3_bucket.images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    # Tightened to CloudFront origin once CDN is added
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}

# ── Lambda deployment artifacts bucket ──────────────────────────────────────

resource "aws_s3_bucket" "lambda_deployments" {
  bucket = "ai-myoa-lambda-deployments-${var.environment}"
}

resource "aws_s3_bucket_public_access_block" "lambda_deployments" {
  bucket = aws_s3_bucket.lambda_deployments.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_deployments" {
  bucket = aws_s3_bucket.lambda_deployments.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ── Frontend static site bucket ─────────────────────────────────────────────

resource "aws_s3_bucket" "website" {
  bucket = "ai-myoa-website-${var.environment}"
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.website]
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# ── DynamoDB sessions table ──────────────────────────────────────────────────
# Commented out — deploy once Lambda session logic is ready

# resource "aws_dynamodb_table" "sessions" {
#   name         = "ai-myoa-sessions-${var.environment}"
#   billing_mode = "PAY_PER_REQUEST"
#   hash_key     = "session_id"
#
#   attribute {
#     name = "session_id"
#     type = "S"
#   }
#
#   ttl {
#     attribute_name = "expires_at"
#     enabled        = true
#   }
#
#   tags = {
#     Name = "ai-myoa-sessions"
#   }
# }
