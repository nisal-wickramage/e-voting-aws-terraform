# ECS Worker Service Outputs

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.service.name
}

output "service_arn" {
  description = "ECS service ARN"
  value       = "${replace(var.cluster_arn, ":cluster/", ":service/")}/${aws_ecs_service.service.name}"
}

output "task_definition_arn" {
  description = "ECS task definition ARN"
  value       = aws_ecs_task_definition.service.arn
}

output "task_definition_revision" {
  description = "ECS task definition revision"
  value       = aws_ecs_task_definition.service.revision
}

output "task_role_arn" {
  description = "IAM task role ARN"
  value       = aws_iam_role.task_role.arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for service"
  value       = aws_cloudwatch_log_group.service_logs.name
}

output "autoscaling_target_id" {
  description = "Auto-scaling target ID"
  value       = aws_appautoscaling_target.service_target.resource_id
}

output "desired_count" {
  description = "Desired number of running tasks"
  value       = var.desired_count
}

output "max_capacity" {
  description = "Maximum number of tasks for auto-scaling"
  value       = aws_appautoscaling_target.service_target.max_capacity
}

output "ecr_repository_url" {
  description = "ECR repository URL for pushing container images"
  value       = var.enable_ecr ? aws_ecr_repository.service[0].repository_url : null
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = var.enable_ecr ? aws_ecr_repository.service[0].name : null
}

output "ecr_repository_arn" {
  description = "ECR repository ARN"
  value       = var.enable_ecr ? aws_ecr_repository.service[0].arn : null
}
