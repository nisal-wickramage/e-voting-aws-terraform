# Platform Module - Development Environment Configuration (AWS)

include "root" {
  path = "../../terragrunt.hcl"
}

terraform {
  source = "../../../tofu/modules/platform"
}

dependency "network" {
  config_path = "../network"
  
  mock_outputs = {
    vpc_id                     = "vpc-mock"
    vpc_cidr                   = "10.0.0.0/16"
    private_subnet_ids_by_tier = {
      app = ["subnet-mock1", "subnet-mock2"]
    }
  }
}

inputs = {
  # Network configuration from network module
  vpc_id             = dependency.network.outputs.vpc_id
  vpc_cidr           = dependency.network.outputs.vpc_cidr
  private_subnet_ids = dependency.network.outputs.private_subnet_ids_by_tier["app"]

  # ECS Cluster configuration
  cluster_name = "e-voting-cluster"
  alb_name     = "e-voting-alb"

  # ECS features
  enable_container_insights = true
  enable_execute_command    = false

  # ALB configuration
  alb_internal                     = true
  alb_enable_deletion_protection   = false
  enable_cross_zone_load_balancing = true
  deregistration_delay             = 30

  # Logging
  enable_alb_access_logs = false

  # Environment and project settings
  environment  = "dev"
  project_name = "e-voting"
}
