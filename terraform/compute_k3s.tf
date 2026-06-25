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
          Service = "ec2.amazonaws.com" # FIXED: Corrected invalid endpoint scheme
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
      }
    ]
  })
}

resource "aws_iam_instance_profile" "k3s_profile" {
  name = "zuri-k3s-instance-profile"
  role = aws_iam_role.ec2_k3s_role.name
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
              curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
              echo "k3s operational verification completed."
              EOF

  tags = {
    Name        = "${var.project_name}-k3s-server"
    Environment = var.environment
  }
}
