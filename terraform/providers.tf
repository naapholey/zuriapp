terraform {
  required_version = "~> 1.6.0" 

  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 6.51.0" # Prevents unexpected breaking changes from v7.0
    }
  }
}

provider "aws" {
  region = "us-east-1"
  skip_credentials_validation = true
  skip_region_validation      = true
}