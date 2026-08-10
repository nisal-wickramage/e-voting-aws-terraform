# ============================================================
# Basic API Stack
# ============================================================
# Composition:
# - Network infrastructure (VPC, subnets, security groups)
# - ECS cluster with ALB
# - RDS PostgreSQL database
# - Single ECS API service
# - Database migrations task
# - CloudFront CDN with WAF
# - SNS notifications for alarms
# - CloudWatch alarms for ECS and RDS
#
# Use Case: Simple REST API with database and CDN
#
# Deploy with:
#   cd stacks/basic-api
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

unit "ecs_service_api" {
  source = "../../terragrunt/dev/ecs-service-api"
  description = "ECS API service with ALB"
  after = [unit.cluster, unit.database]
}

unit "ecs_migrations" {
  source = "../../terragrunt/dev/ecs-migrations"
  description = "Database migrations task (one-time)"
  after = [unit.cluster, unit.database]
}

unit "ecs_alarms" {
  source = "../../terragrunt/dev/ecs-alarms"
  description = "CloudWatch alarms for ECS and ALB"
  after = [unit.ecs_service_api, unit.notification]
}

unit "rds_alarms" {
  source = "../../terragrunt/dev/rds-alarms"
  description = "CloudWatch alarms for RDS"
  after = [unit.database, unit.notification]
}

unit "cdn_waf" {
  source = "../../terragrunt/dev/cdn-waf"
  description = "CloudFront CDN with WAF"
  after = [unit.cluster]
}
