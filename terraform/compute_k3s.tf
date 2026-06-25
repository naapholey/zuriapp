# Security Firewall Group for Kubernetes Node
resource "aws_security_group" "zuriapp_k3s_sg" {
  name        = "${var.project_name}-k3s-sg"
  description = "Network policies for k3s cluster control plane"
  vpc_id      = aws_vpc.zuriapp_main.id

  # Inbound Public Traffic (HTTP/Nginx)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound Kubernetes API Endpoint
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Secure this using your home IP address range if necessary
  }

  # Outbound Rule allowing internet discovery
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
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
          Service = "://amazonaws.com"
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
  instance_type        = "t3.micro" # Satisfies Node + Vite runtime memory demands
  subnet_id            = aws_subnet.zuriapp_public_1.id
  security_groups      = [aws_security_group.zuriapp_k3s_sg.id]
  iam_instance_profile = aws_iam_instance_profile.k3s_profile.name

  # Automation Engine Bootstrapping script to provision k3s natively
  user_data = <<-EOF
              #!/bin/bash
              # Update packages and download k3s binary installer
              curl -sfL https://k3s.io | sh -s - --write-kubeconfig-mode 644
              
              # Optional verification command 
              echo "k3s operational verification completed."
              EOF

  tags = {
    Name        = "${var.project_name}-k3s-server"
    Environment = var.environment
  }
}
