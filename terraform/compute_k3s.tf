# Security Firewall Group for Kubernetes Node

resource "aws_security_group" "zuriapp_k3s_sg" {
  name        = "${var.project_name}-k3s-sg"
  description = "Network policies for k3s cluster control plane"
  vpc_id      = aws_vpc.zuriapp_main.id

  tags = {
    Name = "${var.project_name}-k3s-sg"
  }
}

# Inbound Rules: Restrict Node application runtimes to VPC internal space
resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.zuriapp_k3s_sg.id
  cidr_ipv4         = aws_vpc.zuriapp_main.cidr_block # Tighten if using a public Application Load Balancer
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.zuriapp_k3s_sg.id
  cidr_ipv4         = aws_vpc.zuriapp_main.cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

# Inbound Rule: Restrict API Server to internal VPC network spaces only
resource "aws_vpc_security_group_ingress_rule" "allow_kubernetes_api" {
  security_group_id = aws_security_group.zuriapp_k3s_sg.id
  cidr_ipv4         = aws_vpc.zuriapp_main.cidr_block # Replaces 0.0.0.0/0
  from_port         = 6443
  ip_protocol       = "tcp"
  to_port           = 6443
}

# Outbound Rule: Explicit IPv4 Egress required since K3s drops tracking without it
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.zuriapp_k3s_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.zuriapp_k3s_sg.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" 
}

# Fetch current AWS Account ID and Region dynamically for the Key Policy
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Dedicated CMK for CloudWatch Log Group Encryption
resource "aws_kms_key" "cloudwatch_logs_key" {
  description             = "KMS Key for CloudWatch VPC Flow Logs"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable Root Account Administration"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs Service Delivery"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-cloudwatch-key"
    Environment = var.environment
  }
}

/* import {
  to = aws_cloudwatch_log_group.vpc_flow_log_group
  id = "/aws/vpc-flow-logs/${var.project_name}-${var.environment}"
} */

# CloudWatch Log Group to store network traffic records
resource "aws_cloudwatch_log_group" "vpc_flow_log_group" {
  name              = "/aws/vpc-flow-logs/${var.project_name}-${var.environment}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.cloudwatch_logs_key.arn

 lifecycle {
    prevent_destroy = false
  }
  
  tags = {
    Environment = var.environment
  }
}

/* import {
  to = aws_iam_role.ec2_k3s_role
  id = "zuri-k3s-instance-role"
} */
# IAM instance profile configuration to let k3s read Secrets Manager directly
resource "aws_iam_role" "ec2_k3s_role" {
  name = "zuri-k3s-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com" 
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "secrets_policy" {
  name = "zuri-k3s-secrets-policy"
  role = aws_iam_role.ec2_k3s_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [aws_secretsmanager_secret.backend_secrets.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = [aws_kms_key.cloudwatch_logs_key.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy" "k3s_s3_upload_policy" {
  name = "${var.project_name}-s3-upload-policy"
  role = aws_iam_role.ec2_k3s_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:PutObjectAcl"]
        Resource = "${aws_s3_bucket.zuriapp_s3_bucket.arn}/*"
      }
    ]
  })
}


/* import {
  to = aws_iam_instance_profile.k3s_profile
  id = "zuri-k3s-instance-profile"
} */

resource "aws_iam_instance_profile" "k3s_profile" {
  name = "zuri-k3s-instance-profile"
  role = aws_iam_role.ec2_k3s_role.name
}


resource "aws_s3_bucket" "zuriapp_s3_bucket" {
  # S3 bucket names must be globally unique across all AWS accounts
  bucket_prefix = "${var.project_name}-${var.environment}-artifacts-"
  force_destroy = true # Allows easy cleanup during testing teardowns

  tags = {
    Name        = "${var.project_name}-artifacts-bucket"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "zuriapp_s3_bucket_security" {
  bucket                  = aws_s3_bucket.zuriapp_s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "zuriapp_s3_bucket_crypto" {
  bucket = aws_s3_bucket.zuriapp_s3_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.cloudwatch_logs_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's official AWS Account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Allocate a static Elastic IP for the NAT Gateway
resource "aws_eip" "k3s_nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.zuriapp_igw]

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

# Deploy the NAT Gateway into one of your Public Subnets
resource "aws_nat_gateway" "k3s_nat_gw" {
  allocation_id = aws_eip.k3s_nat_eip.id
  subnet_id     = aws_subnet.zuriapp_public_1.id # Must be placed in a public subnet

  tags = {
    Name = "${var.project_name}-nat-gw"
  }
}

# Create a Private Route Table routing all outbound traffic to the NAT Gateway
resource "aws_route_table" "k3s_private_rt" {
  vpc_id = aws_vpc.zuriapp_main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.k3s_nat_gw.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Associate your private subnet where the K3s node lives
resource "aws_route_table_association" "k3s_private_assoc" {
  subnet_id      = aws_subnet.zuriapp_private_1.id
  route_table_id = aws_route_table.k3s_private_rt.id
}




# Private Subnet 1 (For Application / Worker Nodes)
resource "aws_subnet" "zuriapp_private_1" {
  vpc_id            = aws_vpc.zuriapp_main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name        = "${var.project_name}-private-1"
    Environment = var.environment
  }
}

# Private Subnet 2 (For Application / Worker Nodes)
resource "aws_subnet" "zuriapp_private_2" {
  vpc_id            = aws_vpc.zuriapp_main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name        = "${var.project_name}-private-2"
    Environment = var.environment
  }
}

# Allocate Static IPs for outbound internet routing from Private Subnets
resource "aws_eip" "zuriapp_nat_1" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.zuriapp_igw]

  tags = {
    Name = "${var.project_name}-nat-eip-1"
  }
}

resource "aws_eip" "zuriapp_nat_2" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.zuriapp_igw]

  tags = {
    Name = "${var.project_name}-nat-eip-2"
  }
}

# Deploy NAT Gateways into Public Subnets for AZ Redundancy
resource "aws_nat_gateway" "zuriapp_nat_gw_1" {
  allocation_id = aws_eip.zuriapp_nat_1.id
  subnet_id     = aws_subnet.zuriapp_public_1.id

  tags = {
    Name = "${var.project_name}-nat-gw-1"
  }
}

resource "aws_nat_gateway" "zuriapp_nat_gw_2" {
  allocation_id = aws_eip.zuriapp_nat_2.id
  subnet_id     = aws_subnet.zuriapp_public_2.id

  tags = {
    Name = "${var.project_name}-nat-gw-2"
  }
}

# Private Route Tables mapping traffic to respective NAT Gateways
resource "aws_route_table" "zuriapp_private_rt_1" {
  vpc_id = aws_vpc.zuriapp_main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.zuriapp_nat_gw_1.id
  }

  tags = {
    Name = "${var.project_name}-private-rt-1"
  }
}

resource "aws_route_table" "zuriapp_private_rt_2" {
  vpc_id = aws_vpc.zuriapp_main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.zuriapp_nat_gw_2.id
  }

  tags = {
    Name = "${var.project_name}-private-rt-2"
  }
}


resource "aws_route_table_association" "zuriapp_priv_2" {
  subnet_id      = aws_subnet.zuriapp_private_2.id
  route_table_id = aws_route_table.zuriapp_private_rt_2.id
}

# Virtual Machine Instance Provisioner
resource "aws_instance" "k3s_node" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = "t3.micro"
  subnet_id            = aws_subnet.zuriapp_public_1.id
  vpc_security_group_ids = [aws_security_group.zuriapp_k3s_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.k3s_profile.name

  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    encrypted = true
  }

  # Automation Engine Bootstrapping script to provision k3s natively
  user_data = <<-EOF
              #!/bin/bash
              # Update packages and download k3s binary installer
              apt-get update -y
              apt-get install -y curl unzip
              curl "https://amazonaws.com" -o "awscliv2.zip"
              unzip awscliv2.zip && ./aws/install
              echo "Updating packages and downloading k3s binary installer..."
              curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
              
              # Wait briefly for the cluster configuration to populate completely
              sleep 15

              # Fetch the public or private IP of this node (depending on where your runner sits)
              TARGET_IP=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169)

              # Prepare the kubeconfig file by replacing localhost with the routeable node IP
              sed "s/127.0.0.1/$TARGET_IP/g" /etc/rancher/k3s/k3s.yaml > /tmp/k3s-config

              # Securely upload the cluster profile directly into your deployment bucket
              aws s3 cp /tmp/k3s-config s3://${aws_s3_bucket.zuriapp_s3_bucket.id}/k3s-config --region ${var.aws_region}
            
              echo "k3s operational bootstrapping completed and token exported successfully."
              EOF

  tags = {
    Name        = "${var.project_name}-k3s-server"
    Environment = var.environment
  }
}
/* 
import {
  to = aws_iam_role.vpc_flow_log_role
  id = "${var.project_name}-vpc-flow-log-role"
} */
resource "aws_iam_role" "vpc_flow_log_role" {
  name = "${var.project_name}-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
           Service = "ec2.amazonaws.com" 
        }
      }
    ]
  })
}

# IAM Policy allowing write actions into the CloudWatch log stream
#trivy:ignore:AVD-AWS-0057
resource "aws_iam_role_policy" "vpc_flow_log_policy" {
  name = "${var.project_name}-vpc-flow-log-policy"
  role = aws_iam_role.vpc_flow_log_role.id

  policy = jsonencode({
    Statement = [
      {
        Sid    = "VPCFlowLogsToCloudWatch"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
         Resource = [
          aws_cloudwatch_log_group.vpc_flow_log_group.arn,
          "${aws_cloudwatch_log_group.vpc_flow_log_group.arn}:*"
        ]
      }
    ]
  })
}


# The actual VPC Flow Log delivery tracker mapping to your VPC
resource "aws_flow_log" "zuriapp_flow_log" {
  iam_role_arn    = aws_iam_role.vpc_flow_log_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log_group.arn
  traffic_type    = "ALL" # Captures both ACCEPT and REJECT network traffic
  vpc_id          = aws_vpc.zuriapp_main.id

  tags = {
    Name        = "${var.project_name}-vpc-flow-logs"
    Environment = var.environment
  }
}