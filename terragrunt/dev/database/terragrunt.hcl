# Database Module - Development Environment Configuration (AWS)

include "root" {
  path = "../../terragrunt.hcl"
}

terraform {
  source = "../../../tofu/modules/database"
}

dependency "network" {
  config_path = "../network"
  
  mock_outputs = {
    vpc_id       = "vpc-mock"
    private_subnet_ids_by_tier = {
      db = ["subnet-mock1", "subnet-mock2"]
    }
  }
}

inputs = {
  # Network configuration from network module
  vpc_id             = dependency.network.outputs.vpc_id
  private_subnet_ids = dependency.network.outputs.private_subnet_ids_by_tier["db"]
  
  # ECS configuration - pass security group ID as input (from platform module)
  # For standalone database deployment, use a placeholder; platform will provide the actual SG
  ecs_security_group_id = get_env("ECS_SECURITY_GROUP_ID", "sg-placeholder")

  # RDS Configuration (smallest instance for cost)
  db_instance_class       = "db.t3.micro"
  db_allocated_storage    = 20
  db_name                 = "evoting"
  db_username             = "postgres"
  db_password             = get_env("DB_PASSWORD", "ChangeMe123!")  # Set via env var
  db_backup_retention_days = 7
  db_multi_az             = true
  db_skip_final_snapshot  = true

  # Environment and project settings
  environment  = "dev"
  project_name = "e-voting"
}
