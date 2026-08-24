# main/s3-staging.tf

# --- Deploy staging bucket ---------------------------------------------------
# GitHub Actions uploads the built backend jar here; the backend EC2 (or an
# SSM RunCommand script) pulls it from here during deploy. Kept separate from
# both the images bucket (public-read via CloudFront) and the tfstate bucket
# (Terraform-internal) so their access policies never have to overlap.

resource "aws_s3_bucket" "staging" {
  bucket = "${var.project}-staging"

  tags = {
    Project = "kds-electronics"
    Purpose = "deploy-staging"
  }
}

resource "aws_s3_bucket_versioning" "staging" {
  bucket = aws_s3_bucket.staging.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "staging" {
  bucket = aws_s3_bucket.staging.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "staging" {
  bucket = aws_s3_bucket.staging.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Lifecycle: trim old jar versions ---------------------------------------
# LIMITATION: S3 lifecycle has no native "keep N most recent" rule, only
# age-based expiration. 30 days approximates "keep last 5" assuming
# roughly weekly-or-more-often deploys. Swap to
# noncurrent_version_expiration.newer_noncurrent_versions (provider >= 5.36)
# for true count-based retention if precision matters.
resource "aws_s3_bucket_lifecycle_configuration" "staging" {
  bucket = aws_s3_bucket.staging.id

  rule {
    id     = "expire-old-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
