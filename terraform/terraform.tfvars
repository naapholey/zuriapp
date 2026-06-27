project_name       = "zuriapp"
environment        = "dev"
aws_region         = "us-east-1"
instance_type      = "t3.medium"
ssh_key_name       = "lamp-key"
github_repository  = "naapholey/zuriapp"
dockerhub_username = "naapholey"
allowed_ssh_cidr   = "154.161.23.114/32"
additional_tags = {
  CostCenter = "Engineering"
  Owner      = "DevOps"
}