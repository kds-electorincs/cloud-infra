# main/cloudfront-backend.tf

# --- CloudFront distribution: HTTPS front door for the backend API ---------
# Origin is the backend EC2's Elastic IP over plain HTTP (CloudFront <-> EC2
# traffic stays on AWS's backbone, not the public internet). CloudFront
# terminates TLS at the edge using its own default *.cloudfront.net cert —
# no custom domain needed for Phase 1.

resource "aws_cloudfront_distribution" "backend" {
  enabled = true
  comment = "${var.project} backend API"

  # See waf-backend.tf — CLOUDFRONT-scope Web ACLs are attached directly via
  # this attribute (aws_wafv2_web_acl_association only applies to regional
  # scope resources like ALB/API Gateway, not CloudFront).
  web_acl_id = aws_wafv2_web_acl.backend.arn

  origin {
    domain_name = aws_eip.backend.public_dns
    origin_id   = "backend-ec2"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "backend-ec2"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]

    # AWS managed: CachingDisabled — API responses are not cached
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    # AWS managed: AllViewer — forwards all headers, cookies, and query
    # strings to the origin (needed for Authorization header / JWT, CORS)
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
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
    Purpose = "backend-api-cdn"
  }
}

