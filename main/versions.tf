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