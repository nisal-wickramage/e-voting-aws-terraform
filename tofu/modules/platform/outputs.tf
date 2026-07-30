output "ecs_cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

# Step 2: Capacity Providers (populated in step 2)
output "ecs_capacity_providers" {
  description = "ECS capacity providers (FARGATE, FARGATE_SPOT)"
  value       = try([for cp in aws_ecs_cluster_capacity_providers.main[0].capacity_providers : cp], [])
}

# Step 3: CloudWatch Log Group (populated in step 3)
output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for ECS Container Insights"
  value       = try(aws_cloudwatch_log_group.ecs[0].name, "")
}

# Step 4: ALB Security Group
output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

# Step 5: ECS Security Group
output "ecs_security_group_id" {
  description = "ECS tasks security group ID"
  value       = aws_security_group.ecs.id
}

# Step 6: Application Load Balancer
output "alb_id" {
  description = "Application Load Balancer ID"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "Application Load Balancer ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "ALB DNS name (for internal reference)"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID (for Route53)"
  value       = aws_lb.main.zone_id
}

output "default_target_group_arn" {
  description = "Default target group ARN"
  value       = aws_lb_target_group.default.arn
}

output "default_target_group_name" {
  description = "Default target group name"
  value       = aws_lb_target_group.default.name
}

output "alb_listener_arn" {
  description = "Default ALB listener ARN"
  value       = aws_lb_listener.default.arn
}

output "alb_name" {
  description = "ALB name (for monitoring and identification)"
  value       = aws_lb.main.name
}

output "subnets_used" {
  description = "Private subnets used by ALB"
  value       = var.private_subnet_ids
}

# IAM Roles
output "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN (for pulling images and logs)"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "ECS task role ARN (for task-level permissions)"
  value       = aws_iam_role.ecs_task_role.arn
}
