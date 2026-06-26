output "k3s_public_ip" {
  description = "The public entrypoint address for your application interface"
  value       = aws_instance.k3s_node.public_ip
}

output "secrets_manager_arn" {
  description = "The resource pathway identifiers for the app runtime components"
  value       = aws_secretsmanager_secret.backend_secrets.arn
}
output "k3s_secret_arn" {
  value = aws_secretsmanager_secret.k3s_kubeconfig.arn
}
