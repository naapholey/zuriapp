
# AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "zuriapp"
      Owner       = "DevOps"
    }
  }
}


# Current AWS Account
#data "aws_caller_identity" "current" {}


# Current AWS Region
data "aws_region" "current" {}


# Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}