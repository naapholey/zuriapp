# Configure the AWS provider
provider "aws" {
  region = "us-east-1" # Change to your preferred AWS region
}

# Security Group to allow necessary ports
resource "aws_security_group" "ec2_security_group" {
  name        = "ec2_security_group"
  description = "Allow necessary ports for admin, controlplane, and workernode"



  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Define the EC2 instances
resource "aws_instance" "admin" {
  ami             = "ami-0bc7f2dbdcc6b5303" # Ubuntu Server 20.04 LTS for us-east-1; change if needed
  instance_type   = "t2.micro"
  key_name        = "lamp_key" # Your existing key pair name
  security_groups = [aws_security_group.ec2_security_group.name]

  tags = {
    Name = "admin"
  }
}

resource "aws_instance" "controlplane" {
  ami             = "ami-0bc7f2dbdcc6b5303" # Ubuntu Server 20.04 LTS for us-east-1; change if needed
  instance_type   = "t2.micro"
  key_name        = "lamp_key" # Your existing key pair name
  security_groups = [aws_security_group.ec2_security_group.name]

  tags = {
    Name = "controlplane"
  }
}

resource "aws_instance" "workernode" {
  ami             = "ami-0bc7f2dbdcc6b5303" # Ubuntu Server 20.04 LTS for us-east-1; change if needed
  instance_type   = "t2.micro"
  key_name        = "lamp_key" # Your existing key pair name
  security_groups = [aws_security_group.ec2_security_group.name]

  tags = {
    Name = "workernode"
  }
}

# Output SSH commands for each instance
output "ssh_instructions" {
  description = "SSH commands to connect to each instance"
  value = {
    admin        = "ssh -i lamp_key.pem ubuntu@${aws_instance.admin.public_ip}"
    controlplane = "ssh -i lamp_key.pem ubuntu@${aws_instance.controlplane.public_ip}"
    workernode   = "ssh -i lamp_key.pem ubuntu@${aws_instance.workernode.public_ip}"
  }
}