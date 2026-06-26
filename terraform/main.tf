# Create a Customer Managed Key (CMK) for cryptographic control
resource "aws_kms_key" "secrets_key" {
  description             = "Customer managed key for encrypting backend application secrets"
  deletion_window_in_days = 7
  enable_key_rotation     = true # Resolves another common high-severity security finding

  tags = {
    Name        = "${var.project_name}-secrets-key"
    Environment = var.environment
  }
}

# Add a convenient alias name for management visibility
resource "aws_kms_alias" "secrets_key_alias" {
  name          = "alias/${var.project_name}-backend-secrets"
  target_key_id = aws_kms_key.secrets_key.key_id
}

# # AWS Secrets Manager Container
resource "aws_secretsmanager_secret" "backend_secrets" {
  name                    = "${var.environment}/${var.project_name}/backend"
  recovery_window_in_days = 0 
  kms_key_id              = aws_kms_key.secrets_key.arn

  tags = {
    Environment = var.environment
  }
}

# Standard Structure Template for Node.js Application Config
resource "aws_secretsmanager_secret_version" "backend_defaults" {
  secret_id = aws_secretsmanager_secret.backend_secrets.id
  secret_string = jsonencode({
    NODE_ENV     = "production"
    PORT         = "5000"
    DATABASE_URL = "mongodb://placeholder_string"
    JWT_SECRET   = "713300e5c96007c662ea608ee767d3931dd692f1aa9b85bb7ffc56e208156492"
  })
}

# Create dedicated project VPC
resource "aws_vpc" "zuriapp_main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

# Internet Gateway for Edge Routing
resource "aws_internet_gateway" "zuriapp_igw" {
  vpc_id = aws_vpc.zuriapp_main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnet 1
resource "aws_subnet" "zuriapp_public_1" {
  vpc_id                  = aws_vpc.zuriapp_main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false # Security best practice: avoid auto-public IPs for production workloads

  tags = {
    Name = "${var.project_name}-public-1"
  }
}

# Public Subnet 2
resource "aws_subnet" "zuriapp_public_2" {
  vpc_id                  = aws_vpc.zuriapp_main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = false # Security best practice: avoid auto-public IPs for production workloads

  tags = {
    Name = "${var.project_name}-public-2"
  }
}

# Public Route Table
resource "aws_route_table" "zuriapp_public_rt" {
  vpc_id = aws_vpc.zuriapp_main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.zuriapp_igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "zuriapp_pub_1" {
  subnet_id      = aws_subnet.zuriapp_public_1.id
  route_table_id = aws_route_table.zuriapp_public_rt.id
}

resource "aws_route_table_association" "zuriapp_pub_2" {
  subnet_id      = aws_subnet.zuriapp_public_2.id
  route_table_id = aws_route_table.zuriapp_public_rt.id
}
