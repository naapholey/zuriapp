
# Project Configuration
variable "project_name" {
  description = "Project name used for naming AWS resources."
  type        = string
  default     = "zuriapp"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"

  validation {
    condition = contains(
      ["dev", "test", "staging", "prod"],
      var.environment
    )

    error_message = "Environment must be one of: dev, test, staging or prod."
  }
}


# AWS Configuration
variable "aws_region" {
  description = "AWS deployment region."
  type        = string
  default     = "us-east-1"
}


# Networking
variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}


variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs."

  type = list(string)

  default = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs."

  type = list(string)

  default = [
    "10.0.11.0/24",
    "10.0.12.0/24"
  ]
}


# EC2 Configuration
variable "instance_type" {
  description = "EC2 instance type."

  type    = string
  default = "t3.medium"

  validation {

    condition = contains([
      "t3.small",
      "t3.medium",
      "t3.large",
      "t3.xlarge"
    ], var.instance_type)

    error_message = "Unsupported EC2 instance type."
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size (GB)."

  type    = number
  default = 30

  validation {
    condition     = var.root_volume_size >= 20
    error_message = "Root volume must be at least 20 GB."
  }
}

variable "ssh_key_name" {
  description = "Existing EC2 Key Pair."
  type        = string
}


# K3s Configuration


variable "k3s_version" {
  description = "Version of K3s to install."

  type    = string
  default = "stable"
}


# GitHub OIDC


variable "github_repository" {
  description = "GitHub repository allowed to assume the OIDC role."
  type        = string
}

variable "github_branch" {
  description = "GitHub branch allowed to deploy."
  type        = string
  default     = "main"
}


# Docker Images
variable "dockerhub_username" {
  description = "DockerHub username."
  type        = string
  default     = "naapholey"
}


# CloudWatch
variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention."

  type    = number
  default = 30
}


# Secrets Manager
variable "kubeconfig_secret_name" {

  description = "Secrets Manager secret storing the K3s kubeconfig."
  type        = string
  default     = "zuri-k3s-kubeconfig"
}


# Allowed SSH CIDR
variable "allowed_ssh_cidr" {

  description = "CIDR allowed to SSH into EC2."
  type        = string
  default     = "0.0.0.0/0"

  validation {

    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "Invalid CIDR block."
  }
}


# Tags
variable "additional_tags" {

  description = "Additional resource tags."
  type        = map(string)
  default     = {}
}