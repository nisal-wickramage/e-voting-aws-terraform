# S3 Frontend Module - Development Environment Configuration (AWS)

include "root" {
  path = "../../terragrunt.hcl"
}

terraform {
  source = "../../../tofu/modules/s3-frontend"
}

inputs = {
  project_name      = "e-voting"
  environment       = "dev"
  enable_versioning = true
  enable_logging    = false

  tags = {
    Environment = "dev"
    Project     = "e-voting"
    ManagedBy   = "terragrunt"
    Module      = "s3-frontend"
  }
}
