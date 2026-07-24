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
  default     = ["http://localhost:5173", "http://localhost:4173", "https://ekds-frontend.vercel.app"]
}

variable "db_name" {
  description = "Initial database name created on the RDS instance"
  type        = string
  default     = "kdselectronics"
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "kds_admin"
}

variable "db_password" {
  description = "Master password for the RDS instance. Must be supplied via terraform.tfvars (gitignored) — no default, intentionally, so it can't be committed by accident."
  type        = string
  sensitive   = true
}
