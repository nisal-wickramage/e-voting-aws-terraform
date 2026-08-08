# ECS Migration Task - Development Environment Configuration

include "root" {
  path = "../../terragrunt.hcl"
}

terraform {
  source = "../../../tofu/modules/ecs-migrations"
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

  # Task Configuration
  task_family_name = "evoting-migrations"
  
  # Container Image
  # Update this to your ECR repository URL with Alembic/migration tools
  # Example: 123456789012.dkr.ecr.us-east-1.amazonaws.com/evoting-migrations:latest
  container_image     = get_env("MIGRATION_IMAGE_URI", "123456789012.dkr.ecr.us-east-1.amazonaws.com/evoting-migrations:latest")
  container_memory    = 512
  container_cpu       = 256

  # Database Configuration
  db_host     = dependency.database.outputs.rds_address
  db_port     = dependency.database.outputs.rds_port
  db_name     = "evoting"
  db_username = "postgres"
  db_password = get_env("DB_PASSWORD", "ChangeMe123!")  # Set via env var

  # Network Configuration
  ecs_task_execution_role_arn = dependency.cluster.outputs.ecs_task_execution_role_arn
  ecs_security_group_ids      = [dependency.cluster.outputs.ecs_security_group_id]
  ecs_subnet_ids              = dependency.network.outputs.private_subnet_ids_by_tier["app"]

  # Environment
  environment  = "dev"
  project_name = "e-voting"
}
