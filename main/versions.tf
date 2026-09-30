terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "kds-electronics-13062026-tfstate"
    key            = "main/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "kds-electronics-13062026-tflock"
    encrypt        = true
    profile        = "kds-client"
  }
}

provider "aws" {
  region  = "ap-south-1"
  profile = "kds-client"
}

# WAFv2 web ACLs scoped to CLOUDFRONT must be created in us-east-1
# regardless of where the distribution itself runs (ap-south-1 here) — see
# waf-backend.tf. No such alias existed before this; this is the first
# multi-region provider setup in the repo.
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = "kds-client"
}