variable "project" {
  description = "Project name prefix for resource naming and tags"
  type        = string
  default     = "kds-electronics-13062026"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "frontend_origins" {
  description = "Allowed browser origins for direct-to-S3 uploads (CORS)"
  type        = list(string)
  default     = ["http://localhost:5173"]
}