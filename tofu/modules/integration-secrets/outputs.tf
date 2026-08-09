output "secret_id" {
  value       = aws_secretsmanager_secret.integration.id
  description = "Secret ID (can be used to reference the secret)"
}

output "secret_arn" {
  value       = aws_secretsmanager_secret.integration.arn
  description = "Secret ARN (use this for IAM policies and task definitions)"
}

output "secret_name" {
  value       = aws_secretsmanager_secret.integration.name
  description = "Full secret name"
}

output "secret_version_id" {
  value       = aws_secretsmanager_secret_version.integration.version_id
  description = "Secret version ID"
}
