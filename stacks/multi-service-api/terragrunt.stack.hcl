# ============================================================
# Multi-Service API Stack
# ============================================================
# Composition:
# - Network infrastructure (VPC, subnets, security groups)
# - ECS cluster with ALB
# - RDS PostgreSQL database
# - Multiple ECS services communicating via SQS:
#   * Synchronous API service (REST endpoints)
#   * Asynchronous worker service (processes SQS messages)
# - SQS queue for async job processing
# - Database migrations task
# - CloudFront CDN with WAF
# - SNS notifications for alarms
# - CloudWatch alarms for ECS, RDS, and SQS
#
# Use Case: Microservices architecture with sync API and async workers
#
# Deploy with:
#   cd stacks/multi-service-api
#   terragrunt stack generate
#   terragrunt stack run -- init
#   terragrunt stack run -- plan
#   terragrunt stack run -- apply

locals {
  environment = "dev"
  project_name = "e-voting"
  region = "us-east-1"
}

unit "network" {
  source = "../../terragrunt/dev/network"
  description = "VPC, subnets, security groups"
}

unit "cluster" {
  source = "../../terragrunt/dev/cluster"
  description = "ECS cluster with ALB"
  after = [unit.network]
}

unit "database" {
  source = "../../terragrunt/dev/database"
  description = "RDS PostgreSQL Multi-AZ"
  after = [unit.network]
}

unit "notification" {
  source = "../../terragrunt/dev/notification"
  description = "SNS topic for alarms"
}

# SQS Queue for async job processing
unit "sqs_queue" {
  source = "../../terragrunt/dev/sqs-queue-async-api"
  description = "SQS queue for async jobs"
}

# Synchronous API service (handles REST requests)
unit "ecs_service_api" {
  source = "../../terragrunt/dev/ecs-service-api"
  description = "Synchronous REST API service"
  after = [unit.cluster, unit.database]
}

# Asynchronous worker service (processes queued jobs)
unit "ecs_service_async" {
  source = "../../terragrunt/dev/ecs-service-async-api"
  description = "Asynchronous worker service (processes SQS messages)"
  after = [unit.cluster, unit.database, unit.sqs_queue]
}

# Database migrations (runs once to initialize schema)
unit "ecs_migrations" {
  source = "../../terragrunt/dev/ecs-migrations"
  description = "Database migrations task (one-time setup)"
  after = [unit.cluster, unit.database]
}

# Monitoring and alarms
unit "ecs_alarms" {
  path = "../../terragrunt/dev/ecs-alarms"
  description = "CloudWatch alarms for ECS and ALB"
  after = [unit.ecs_service_api, unit.ecs_service_async, unit.notification]
}

unit "rds_alarms" {
  source = "../../terragrunt/dev/rds-alarms"
  description = "CloudWatch alarms for RDS"
  after = [unit.database, unit.notification]
}

unit "sqs_alarms" {
  source = "../../terragrunt/dev/sqs-alarms"
  description = "CloudWatch alarms for SQS queue"
  after = [unit.sqs_queue, unit.notification]
}

# CDN and WAF
unit "cdn_waf" {
  source = "../../terragrunt/dev/cdn-waf"
  description = "CloudFront CDN with WAF protecting API"
  after = [unit.cluster]
}
