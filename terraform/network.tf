
# Networking
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  aws_region           = var.aws_region
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  availability_zones = slice(
    data.aws_availability_zones.available.names,
    0,
    length(var.public_subnet_cidrs)
  )

}

import {
  to = aws_cloudwatch_log_group.vpc_flow_logs
  id = "/aws/vpc-flow-logs/${local.name_prefix}"
}
# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {

  name              = "/aws/vpc-flow-logs/${local.name_prefix}"
  retention_in_days = var.cloudwatch_log_retention_days
  kms_key_id        = aws_kms_key.infrastructure.arn
  tags              = local.common_tags
}


# IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_logs" {

  name = "${local.name_prefix}-flowlogs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}


# IAM Policy for Flow Logs
resource "aws_iam_role_policy" "flow_logs" {
  name = "${local.name_prefix}-flowlogs-policy"
  role = aws_iam_role.flow_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {

        Effect = "Allow"
        Action = [

          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"

        ]
        Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
      }
    ]
  })
}


# Enable VPC Flow Logs
resource "aws_flow_log" "vpc" {

  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn         = aws_iam_role.flow_logs.arn
  traffic_type         = "ALL"
  vpc_id               = module.vpc.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-flowlogs"
    }
  )
}


# Data Sources
data "aws_vpc" "selected" {
  id = module.vpc.vpc_id
}

data "aws_subnets" "public" {

  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]
  }

  tags = {
    Type = "Public"
  }
}

data "aws_subnets" "private" {

  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]
  }

  tags = {
    Type = "Private"
  }
}