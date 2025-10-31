terraform {
  required_version = "1.13.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.18.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Create the bucket
resource "aws_s3_bucket" "state" {
  bucket = var.bucket_name
}
