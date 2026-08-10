# Root-level outputs aggregating all module outputs

# ===== Network Outputs =====
output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs by tier"
  value       = module.network.private_subnet_ids_by_tier
}

# ===== Database Outputs =====
output "rds_endpoint" {
  description = "RDS cluster endpoint"
  value       = module.database.rds_endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS cluster port"
  value       = module.database.rds_port
}

# ===== Cluster Outputs =====
output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.cluster.ecs_cluster_name
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.cluster.alb_dns_name
}

output "alb_arn" {
  description = "Application Load Balancer ARN"
  value       = module.cluster.alb_arn
}

# ===== ECS API Service Outputs =====
output "ecs_api_service_name" {
  description = "ECS API service name"
  value       = module.ecs_api.service_name
}

output "ecs_api_task_definition_arn" {
  description = "ECS API task definition ARN"
  value       = module.ecs_api.task_definition_arn
}

# ===== S3 Frontend Outputs =====
output "s3_bucket_id" {
  description = "S3 frontend bucket ID"
  value       = module.s3_frontend.bucket_name
}

output "s3_bucket_arn" {
  description = "S3 frontend bucket ARN"
  value       = module.s3_frontend.bucket_arn
}

# ===== CloudFront Outputs =====
output "api_cloudfront_domain_name" {
  description = "CloudFront domain name for API (ALB origin)"
  value       = module.cdn_waf.api_cloudfront_domain_name
}

output "api_cloudfront_distribution_id" {
  description = "CloudFront distribution ID for API"
  value       = module.cdn_waf.api_cloudfront_distribution_id
}

output "frontend_cloudfront_domain_name" {
  description = "CloudFront domain name for frontend (S3 origin)"
  value       = module.cdn_waf.frontend_cloudfront_domain_name
}

output "frontend_cloudfront_distribution_id" {
  description = "CloudFront distribution ID for frontend"
  value       = module.cdn_waf.frontend_cloudfront_distribution_id
}

# ===== Disaster Recovery Outputs =====
output "rds_backup_retention_days" {
  description = "RDS automated backup retention period"
  value       = module.disaster_recovery.backup_retention_days
}

output "backup_sns_topic_arn" {
  description = "SNS topic for backup notifications"
  value       = module.disaster_recovery.sns_topic_arn
}

# ===== Infrastructure Summary =====
output "infrastructure_summary" {
  description = "Summary of deployed infrastructure"
  value = {
    project_name    = var.project_name
    environment     = var.environment
    aws_region      = var.aws_region
    vpc_cidr        = var.vpc_cidr
    ecs_cluster     = module.cluster.ecs_cluster_name
    database_host   = module.database.rds_endpoint
    api_endpoint    = "https://${module.cdn_waf.api_cloudfront_domain_name}/api"
    frontend_url    = "https://${module.cdn_waf.frontend_cloudfront_domain_name}"
  }
}
