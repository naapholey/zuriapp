##############################################################
# Ubuntu 24.04 LTS
##############################################################

data "aws_ami" "ubuntu" {

  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

##############################################################
# Cloud-init User Data
##############################################################

data "cloudinit_config" "k3s" {

  gzip          = true
  base64_encode = true

  part {

    filename     = "bootstrap.sh"
    content_type = "text/x-shellscript"

    content = templatefile(
      "${path.module}/templates/k3s-bootstrap.sh.tpl",
      {
        region      = var.aws_region
        secret_name = aws_secretsmanager_secret.k3s_kubeconfig.name
        k3s_version = var.k3s_version
      }
    )
  }
}

##############################################################
# EC2 Instance
##############################################################

resource "aws_instance" "k3s" {

  ami = data.aws_ami.ubuntu.id

  instance_type = var.instance_type

  subnet_id = module.vpc.public_subnet_ids[0]

  vpc_security_group_ids = [
    aws_security_group.k3s_server.id
  ]

  iam_instance_profile = aws_iam_instance_profile.k3s.name

  key_name = var.ssh_key_name

  associate_public_ip_address = true

  user_data_base64 = data.cloudinit_config.k3s.rendered

  ############################################################
  # IMDSv2
  ############################################################

  metadata_options {

    http_endpoint = "enabled"

    http_tokens = "required"

    http_put_response_hop_limit = 2

    instance_metadata_tags = "enabled"
  }

  ############################################################
  # Root Volume
  ############################################################

  root_block_device {

    volume_size = var.root_volume_size

    volume_type = "gp3"

    encrypted = true

    kms_key_id = aws_kms_key.infrastructure.arn

    delete_on_termination = true

    tags = merge(
      local.common_tags,
      {
        Name = "${local.name_prefix}-root-volume"
      }
    )
  }

  ############################################################
  # Monitoring
  ############################################################

  monitoring = true

  ebs_optimized = true

  ############################################################
  # Replace when user_data changes
  ############################################################

  user_data_replace_on_change = true

  ############################################################
  # Tags
  ############################################################

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-k3s-server"
    }
  )

  depends_on = [
    aws_secretsmanager_secret.k3s_kubeconfig,
    aws_iam_instance_profile.k3s
  ]
}