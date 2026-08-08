# ECS Async API Service - Development Environment Configuration

include "root" {
  path = "../../terragrunt.hcl"
}

terraform {
  source = "../../../tofu/modules/ecs-async-api"
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
    default_target_group_arn    = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/e-voting-default/abc123"
  }
}

inputs = {
  # ECS Cluster
  cluster_name = dependency.cluster.outputs.ecs_cluster_name
  cluster_arn  = dependency.cluster.outputs.ecs_cluster_arn

  # Service Configuration
  service_name     = "async-api"
  container_image  = get_env("ASYNC_API_IMAGE_URI", "123456789012.dkr.ecr.us-east-1.amazonaws.com/async-api:latest")
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
  alb_target_group_arn        = dependency.cluster.outputs.default_target_group_arn

  # SQS Configuration
  sqs_queue_name        = "async-api-requests"
  sqs_visibility_timeout = 300
  sqs_message_retention = 345600  # 4 days

  # Environment
  environment  = "dev"
  project_name = "e-voting"
}
