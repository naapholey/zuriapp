
# K3s Server Security Group
resource "aws_security_group" "k3s_server" {

  name        = "${local.name_prefix}-k3s-server"
  description = "Security group for K3s server"
  vpc_id      = module.vpc.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-k3s-server"
    }
  )
}


# SSH
resource "aws_vpc_security_group_ingress_rule" "ssh" {

  security_group_id = aws_security_group.k3s_server.id
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH"
}


# HTTP
resource "aws_vpc_security_group_ingress_rule" "http" {

  security_group_id = aws_security_group.k3s_server.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP"
}


# HTTPS
resource "aws_vpc_security_group_ingress_rule" "https" {

  security_group_id = aws_security_group.k3s_server.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS"
}


# Kubernetes API Server
resource "aws_vpc_security_group_ingress_rule" "kubernetes_api" {

  security_group_id = aws_security_group.k3s_server.id
  cidr_ipv4         = var.allowed_kubernetes_api_cidr
  from_port         = 6443
  to_port           = 6443
  ip_protocol       = "tcp"
  description       = "Kubernetes API"
}


# Flannel VXLAN
resource "aws_vpc_security_group_ingress_rule" "flannel" {

  security_group_id            = aws_security_group.k3s_server.id
  referenced_security_group_id = aws_security_group.k3s_server.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
  description                  = "Flannel VXLAN"
}


# Kubelet
resource "aws_vpc_security_group_ingress_rule" "kubelet" {

  security_group_id            = aws_security_group.k3s_server.id
  referenced_security_group_id = aws_security_group.k3s_server.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  description                  = "Kubelet"
}


# NodePort Services
resource "aws_vpc_security_group_ingress_rule" "nodeport" {

  count             = var.enable_nodeport ? 1 : 0
  security_group_id = aws_security_group.k3s_server.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 30000
  to_port           = 32767
  ip_protocol       = "tcp"
  description       = "NodePort Services"
}


# ICMP
resource "aws_vpc_security_group_ingress_rule" "icmp" {

  security_group_id = aws_security_group.k3s_server.id
  cidr_ipv4         = var.allowed_ssh_cidr
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
  description       = "Ping"
}


# Outbound
resource "aws_vpc_security_group_egress_rule" "all" {

  security_group_id = aws_security_group.k3s_server.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Outbound Internet"
}

variable "allowed_kubernetes_api_cidr" {

  description = "CIDR allowed to reach Kubernetes API"
  type        = string
  default     = "0.0.0.0/0"
}

variable "enable_nodeport" {

  description = "Enable NodePort Services"
  type        = bool
  default     = false
}