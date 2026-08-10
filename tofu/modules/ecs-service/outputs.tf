# ============================================================
# ECR Outputs
# ============================================================

output "ecr_repository_url" {
  value       = try(aws_ecr_repository.service[0].repository_url, "")
  description = "ECR repository URL (if created)"
}

output "ecr_repository_arn" {
  value       = try(aws_ecr_repository.service[0].arn, "")
  description = "ECR repository ARN (if created)"
}

# ============================================================
# ECS Task Definition Outputs
# ============================================================

output "task_definition_arn" {
  value       = aws_ecs_task_definition.service.arn
  description = "ECS task definition ARN"
}

output "task_definition_family" {
  value       = aws_ecs_task_definition.service.family
  description = "ECS task definition family name"
}

output "task_definition_revision" {
  value       = aws_ecs_task_definition.service.revision
  description = "ECS task definition revision"
}

# ============================================================
# ECS Service Outputs
# ============================================================

output "service_id" {
  value       = aws_ecs_service.service.id
  description = "ECS service ID"
}

output "service_arn" {
  value       = "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:service/${var.cluster_name}/${aws_ecs_service.service.name}"
  description = "ECS service ARN"
}

output "service_name" {
  value       = aws_ecs_service.service.name
  description = "ECS service name"
}

# ============================================================
# IAM Role Outputs
# ============================================================

output "task_role_arn" {
  value       = aws_iam_role.task_role.arn
  description = "Task role ARN"
}

output "task_role_name" {
  value       = aws_iam_role.task_role.name
  description = "Task role name"
}

# ============================================================
# CloudWatch Logs Outputs
# ============================================================

output "log_group_name" {
  value       = aws_cloudwatch_log_group.service_logs.name
  description = "CloudWatch log group name"
}

output "log_group_arn" {
  value       = aws_cloudwatch_log_group.service_logs.arn
  description = "CloudWatch log group ARN"
}
