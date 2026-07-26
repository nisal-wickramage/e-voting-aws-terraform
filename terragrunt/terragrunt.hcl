# Root Terragrunt Configuration

locals {
  environment = get_env("ENVIRONMENT", "dev")
  region      = "us-east-1"
  project     = "e-voting"

  common_tags = {
    Environment = local.environment
    Project     = local.project
    ManagedBy   = "terragrunt"
  }
}

# Generate provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.0"
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.0"
        }
      }
    }

    provider "aws" {
      region = "${local.region}"

      default_tags {
        tags = ${jsonencode(local.common_tags)}
      }
    }
  EOF
}
