# ECS Worker Service - Development Environment Configuration

include "root" {
  path = "../../terragrunt.hcl"
}

terraform {
  source = "../../../tofu/modules/ecs-worker"
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
  }
}

dependency "database" {
  config_path = "../database"
  
  mock_outputs = {
    rds_address = "e-voting-db.cdmzaqlrjaqr.us-east-1.rds.amazonaws.com"
    rds_port    = 5432
  }
}

dependency "ecs_async_api" {
  config_path = "../ecs-async-api"
  
  mock_outputs = {
    sqs_queue_url = "https://sqs.us-east-1.amazonaws.com/123456789012/e-voting-async-api-requests"
    sqs_queue_arn = "arn:aws:sqs:us-east-1:123456789012:e-voting-async-api-requests"
  }
}

dependency "ecs_migrations" {
  config_path = "../ecs-migrations"
  
  mock_outputs = {
    db_credentials_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:e-voting-db-credentials-XXXXXX"
  }
}

inputs = {
  # ECS Cluster
  cluster_name = dependency.platform.outputs.ecs_cluster_name
  cluster_arn  = dependency.platform.outputs.ecs_cluster_arn

  # Service Configuration
  service_name = "worker"
  container_image = get_env("WORKER_IMAGE_URI", "123456789012.dkr.ecr.us-east-1.amazonaws.com/worker:latest")
  container_port   = 8000
  container_memory = 512
  container_cpu    = 256
  desired_count    = 2

  # Network Configuration
  ecs_security_group_ids      = [dependency.platform.outputs.ecs_security_group_id]
  ecs_subnet_ids              = dependency.network.outputs.private_subnet_ids_by_tier["app"]
  ecs_task_execution_role_arn = dependency.platform.outputs.ecs_task_execution_role_arn

  # SQS Queue from async-api
  sqs_queue_url = dependency.ecs_async_api.outputs.sqs_queue_url
  sqs_queue_arn = dependency.ecs_async_api.outputs.sqs_queue_arn

  # Database Configuration
  db_host                   = dependency.database.outputs.rds_address
  db_port                   = dependency.database.outputs.rds_port
  db_name                   = "evoting"
  db_credentials_secret_arn = dependency.ecs_migrations.outputs.db_credentials_secret_arn

  # Environment
  environment  = "dev"
  project_name = "e-voting"
}
