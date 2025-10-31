terraform {
  required_version = "1.13.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.18.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
  }

  backend "s3" {
    bucket = "eks-demo-alistechlab"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}
