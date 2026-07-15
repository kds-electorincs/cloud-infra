# main/outputs.tf

output "images_cdn_domain" {
  value       = aws_cloudfront_distribution.images.domain_name
  description = "CloudFront domain for catalog images — store object keys in DB, serve via this"
}
