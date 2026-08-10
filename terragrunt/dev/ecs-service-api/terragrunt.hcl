include "root" {
  path = "../../terragrunt.hcl"
}

terraform {
  source = "../../../tofu/modules/ecs-service"
}

dependency "cluster" {
  config_path = "../cluster"
  mock_outputs = {
    ecs_cluster_arn            = "arn:aws:ecs:us-east-1:123456789012:cluster/mock"
    ecs_cluster_name           = "e-voting-cluster"
    ecs_security_group_id      = "sg-12345678"
    ecs_task_execution_role_arn = "arn:aws:iam::123456789012:role/ecs-task-execution-role"
    default_target_group_arn   = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/mock/1234567890123456"
    alb_listener_arn           = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/mock/1234567890123456/1234567890123456"
  }
}

dependency "network" {
  config_path = "../network"
  mock_outputs = {
    private_subnet_ids_by_tier = {
      app = ["subnet-12345678", "subnet-87654321"]
    }
  }
}

dependency "database" {
  config_path = "../database"
  mock_outputs = {
    rds_endpoint = "mock-db.example.com"
    rds_port     = 5432
  }
}

locals {
  env         = "dev"
  project_name = "e-voting"
}

inputs = {
  project_name = local.project_name
  environment  = local.env
  service_name = "api"

  cluster_name                = dependency.cluster.outputs.ecs_cluster_name
  cluster_arn                 = dependency.cluster.outputs.ecs_cluster_arn
  
  container_image             = "nginx:latest"  # Replace with actual ECR URI
  container_port              = 8080
  container_cpu               = 256
  container_memory            = 512
  desired_count               = 2

  ecs_security_group_ids      = [dependency.cluster.outputs.ecs_security_group_id]
  ecs_subnet_ids              = dependency.network.outputs.private_subnet_ids_by_tier["app"]
  ecs_task_execution_role_arn = dependency.cluster.outputs.ecs_task_execution_role_arn

  # ALB Configuration
  alb_target_group_arn       = dependency.cluster.outputs.default_target_group_arn
  alb_listener_arn           = dependency.cluster.outputs.alb_listener_arn
  listener_rule_path_pattern = ["/api/*"]
  listener_rule_priority     = 100

  environment_variables = {
    SERVICE_NAME = "api"
    LOG_LEVEL    = "info"
    DB_HOST      = dependency.database.outputs.rds_endpoint
    DB_PORT      = "5432"
    DB_NAME      = "e_voting"
  }

  secrets_arns = {}  # Add if using Secrets Manager

  extra_iam_policy_statements = []
  extra_security_group_ids    = []

  common_tags = {
    Environment = local.env
    Project     = local.project_name
    ManagedBy   = "terragrunt"
  }
}
