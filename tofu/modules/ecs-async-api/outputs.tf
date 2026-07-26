# ECS Async API Service Outputs

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

output "sqs_queue_url" {
  description = "SQS queue URL for async requests"
  value       = aws_sqs_queue.requests.url
}

output "sqs_queue_arn" {
  description = "SQS queue ARN"
  value       = aws_sqs_queue.requests.arn
}

output "sqs_queue_name" {
  description = "SQS queue name"
  value       = aws_sqs_queue.requests.name
}

output "sqs_dlq_url" {
  description = "SQS Dead Letter Queue URL"
  value       = aws_sqs_queue.dlq.url
}

output "sqs_dlq_arn" {
  description = "SQS Dead Letter Queue ARN"
  value       = aws_sqs_queue.dlq.arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for service"
  value       = aws_cloudwatch_log_group.service_logs.name
}

output "task_role_arn" {
  description = "IAM task role ARN"
  value       = aws_iam_role.task_role.arn
}

output "autoscaling_target_id" {
  description = "Auto-scaling target ID"
  value       = aws_appautoscaling_target.service_autoscaling.resource_id
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
