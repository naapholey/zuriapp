output "k3s_public_ip" {
  value = aws_instance.k3s.public_ip
}

output "k3s_private_ip" {
  value = aws_instance.k3s.private_ip
}

output "instance_id" {
  value = aws_instance.k3s.id
}

output "github_actions_role_arn" {

  value = aws_iam_role.github_actions.arn

}

output "github_oidc_provider_arn" {

  value = aws_iam_openid_connect_provider.github.arn

}

