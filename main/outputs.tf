# main/outputs.tf

output "images_cdn_domain" {
  value       = aws_cloudfront_distribution.images.domain_name
  description = "CloudFront domain for catalog images — store object keys in DB, serve via this"
}

output "backend_public_ip" {
  value       = aws_eip.backend.public_ip
  description = "Elastic IP for the backend EC2 — SSH here, will later sit behind CloudFront"
}
output "db_endpoint" {
  value       = aws_db_instance.main.endpoint
  description = "RDS endpoint (host:port) — use in Spring Boot's JDBC connection string"
}

output "db_name" {
  value       = aws_db_instance.main.db_name
  description = "Initial database name on the RDS instance"
}
output "backend_api_domain" {
  value       = aws_cloudfront_distribution.backend.domain_name
  description = "CloudFront domain for the backend API — Vercel frontend calls this, e.g. https://<this>/api/..."
}
