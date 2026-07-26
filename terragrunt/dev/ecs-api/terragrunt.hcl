# ECS API Service - Development Environment Configuration

include "root" {
  path = "../../terragrunt.hcl"
}

terraform {
  source = "../../../tofu/modules/ecs-api"
}

dependency "network" {
  config_path = "../network"
  
  mock_outputs = {
    private_subnet_ids_by_tier = {
      app = ["subnet-mock1", "subnet-mock2"]
    }
  }
}

dependency "platform" {
  config_path = "../platform"
  
  mock_outputs = {
    ecs_cluster_name            = "e-voting-cluster-mock"
    ecs_cluster_arn             = "arn:aws:ecs:us-east-1:123456789012:cluster/e-voting-cluster-mock"
    ecs_security_group_id       = "sg-mock"
    ecs_task_execution_role_arn = "arn:aws:iam::123456789012:role/ecs-task-execution-role"
    alb_listener_arn            = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/e-voting-alb/1234567890abcdef/abc123"
    default_target_group_arn    = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/e-voting-default/abc123"
  }
}

dependency "database" {
  config_path = "../database"
  
  mock_outputs = {
    rds_address = "e-voting-db.cdmzaqlrjaqr.us-east-1.rds.amazonaws.com"
    rds_port    = 5432
  }
}

inputs = {
  # ECS Cluster
  cluster_name = dependency.platform.outputs.ecs_cluster_name
  cluster_arn  = dependency.platform.outputs.ecs_cluster_arn

  # Service Configuration
  service_name = "api"
  container_image = get_env("API_IMAGE_URI", "123456789012.dkr.ecr.us-east-1.amazonaws.com/api:latest")
  container_port   = 8000
  container_memory = 512
  container_cpu    = 256
  desired_count    = 2

  # Network Configuration
  ecs_security_group_ids      = [dependency.platform.outputs.ecs_security_group_id]
  ecs_subnet_ids              = dependency.network.outputs.private_subnet_ids_by_tier["app"]
  ecs_task_execution_role_arn = dependency.platform.outputs.ecs_task_execution_role_arn

  # ALB Configuration
  alb_target_group_arn       = dependency.platform.outputs.default_target_group_arn
  alb_listener_arn           = dependency.platform.outputs.alb_listener_arn
  listener_rule_path_pattern = ["/api/*"]
  listener_rule_priority     = 100

  # Database Configuration
  db_host     = dependency.database.outputs.rds_address
  db_port     = dependency.database.outputs.rds_port
  db_name     = "evoting"
  db_username = "api_user"
  db_password = get_env("API_DB_PASSWORD", "changeme123")  # CHANGE in production!

  # Environment
  environment  = "dev"
  project_name = "e-voting"
}
