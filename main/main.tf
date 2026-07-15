# --- Application image bucket -----------------------------------------------

resource "aws_s3_bucket" "images" {
  bucket = "${var.project}-images"

  tags = {
    Project = "kds-electronics"
    Purpose = "catalog-images"
  }
}

resource "aws_s3_bucket_versioning" "images" {
  bucket = aws_s3_bucket.images.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket = aws_s3_bucket.images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Image bucket CORS (browser direct-PUT via presigned URL) ---------------

resource "aws_s3_bucket_cors_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  cors_rule {
    allowed_methods = ["PUT"]
    allowed_origins = var.frontend_origins
    allowed_headers = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# --- IAM: backend access to the image bucket --------------------------------

# Policy document — least-privilege, scoped to JUST the image bucket
data "aws_iam_policy_document" "backend_s3" {
  statement {
    sid    = "ObjectLevel"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject"
    ]
    resources = [
      "${aws_s3_bucket.images.arn}/*",
    ]
  }

  statement {
    sid    = "BucketLevel"
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.images.arn,
    ]
  }
}

resource "aws_iam_policy" "backend_s3" {
  name        = "${var.project}-backend-s3"
  description = "Allows the KDS backend to sign presigned PUT/GET URLs for the image bucket"
  policy      = data.aws_iam_policy_document.backend_s3.json
}

# Role the EC2 backend will assume (instance profile attached at the EC2 stage)
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backend" {
  name               = "${var.project}-backend"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = {
    Project = "kds-electronics"
  }
}

resource "aws_iam_role_policy_attachment" "backend_s3" {
  role       = aws_iam_role.backend.name
  policy_arn = aws_iam_policy.backend_s3.arn
}

# --- CloudFront for public image reads (bucket stays private) ---------------

resource "aws_cloudfront_origin_access_control" "images" {
  name                              = "${var.project}-images-oac"
  description                       = "OAC for KDS catalog image bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "images" {
  enabled = true
  comment = "${var.project} catalog images"

  origin {
    domain_name              = aws_s3_bucket.images.bucket_regional_domain_name
    origin_id                = "images-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.images.id
  }

  default_cache_behavior {
    target_origin_id       = "images-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" # AWS managed: CachingOptimized
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  price_class = "PriceClass_200"

  tags = {
    Project = "kds-electronics"
    Purpose = "catalog-images-cdn"
  }
}

# Bucket policy: allow ONLY this CloudFront distribution to read objects
data "aws_iam_policy_document" "images_bucket" {
  statement {
    sid    = "AllowCloudFrontRead"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.images.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.images.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "images" {
  bucket = aws_s3_bucket.images.id
  policy = data.aws_iam_policy_document.images_bucket.json
}

output "images_cdn_domain" {
  value       = aws_cloudfront_distribution.images.domain_name
  description = "CloudFront domain for catalog images — store object keys in DB, serve via this"
}