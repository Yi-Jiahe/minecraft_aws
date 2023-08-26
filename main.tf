terraform {
  cloud {
    organization = "yi-jiahe"
    workspaces {
      name = "aws_minecraft_server"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.12.0"
    }
  }

  required_version = ">= 1.5.0"
}

# Required for Cloudwatch logging
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

provider "aws" {
  region = var.region
}