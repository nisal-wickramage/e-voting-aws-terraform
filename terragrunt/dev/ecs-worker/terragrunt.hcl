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

dependency "cluster" {
  config_path = "../cluster"
  
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

inputs = {
  # ECS Cluster
  cluster_name = dependency.cluster.outputs.ecs_cluster_name
  cluster_arn  = dependency.cluster.outputs.ecs_cluster_arn

  # Service Configuration
  service_name = "worker"
  container_image = get_env("WORKER_IMAGE_URI", "123456789012.dkr.ecr.us-east-1.amazonaws.com/worker:latest")
  container_port   = 8000
  container_memory = 512
  container_cpu    = 256
  desired_count    = 2
  # ECR Configuration
  enable_ecr            = true
  image_tag_mutability  = "MUTABLE"
  image_scan_on_push    = true
  ecr_retention_days    = 30
  # Network Configuration
  ecs_security_group_ids      = [dependency.cluster.outputs.ecs_security_group_id]
  ecs_subnet_ids              = dependency.network.outputs.private_subnet_ids_by_tier["app"]
  ecs_task_execution_role_arn = dependency.cluster.outputs.ecs_task_execution_role_arn

  # SQS Queue (provide via environment variable)
  sqs_queue_url = get_env("SQS_QUEUE_URL", "https://sqs.us-east-1.amazonaws.com/123456789012/e-voting-async-api-requests")
  sqs_queue_arn = get_env("SQS_QUEUE_ARN", "arn:aws:sqs:us-east-1:123456789012:e-voting-async-api-requests")

  # Database Configuration
  db_host                   = dependency.database.outputs.rds_address
  db_port                   = dependency.database.outputs.rds_port
  db_name                   = "evoting"
  db_credentials_secret_arn = get_env("DB_CREDENTIALS_SECRET_ARN", "arn:aws:secretsmanager:us-east-1:123456789012:secret:e-voting-db-credentials-XXXXXX")

  # Environment
  environment  = "dev"
  project_name = "e-voting"
}
