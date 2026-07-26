# ECS Migration Task Definition Outputs

output "task_definition_arn" {
  description = "ECS task definition ARN"
  value       = aws_ecs_task_definition.migrations.arn
}

output "task_definition_revision" {
  description = "ECS task definition revision"
  value       = aws_ecs_task_definition.migrations.revision
}

output "task_family_name" {
  description = "ECS task family name"
  value       = aws_ecs_task_definition.migrations.family
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group for migration logs"
  value       = aws_cloudwatch_log_group.migration_logs.name
}

output "task_role_arn" {
  description = "IAM role ARN for migration task"
  value       = aws_iam_role.migration_task_role.arn
}

output "run_migration_command" {
  description = "AWS CLI command to run migrations (update with cluster and subnets)"
  value       = <<-EOT
    aws ecs run-task \
      --cluster ${var.cluster_name} \
      --task-definition ${aws_ecs_task_definition.migrations.family} \
      --launch-type FARGATE \
      --network-configuration "awsvpcConfiguration={subnets=[${join(",", var.ecs_subnet_ids)}],securityGroups=[${join(",", var.ecs_security_group_ids)}],assignPublicIp=DISABLED}" \
      --region us-east-1
  EOT
}

output "db_credentials_secret_arn" {
  description = "Secrets Manager secret ARN for database credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_credentials_secret_name" {
  description = "Secrets Manager secret name for database credentials"
  value       = aws_secretsmanager_secret.db_credentials.name
}
