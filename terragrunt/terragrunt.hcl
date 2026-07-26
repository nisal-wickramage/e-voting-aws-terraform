# Root Terragrunt Configuration

locals {
  environment = get_env("ENVIRONMENT", "dev")
  region      = "us-east-1"
  project     = "e-voting"
  
  # LocalStack endpoint
  aws_endpoint_url = get_env("AWS_ENDPOINT_URL", "")

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

      %{if local.aws_endpoint_url != ""}
      # LocalStack endpoint configuration
      endpoints {
        ec2                    = "${local.aws_endpoint_url}"
        rds                    = "${local.aws_endpoint_url}"
        s3                     = "${local.aws_endpoint_url}"
        elasticloadbalancing   = "${local.aws_endpoint_url}"
        ecs                    = "${local.aws_endpoint_url}"
        cloudwatch             = "${local.aws_endpoint_url}"
        logs                   = "${local.aws_endpoint_url}"
        secretsmanager         = "${local.aws_endpoint_url}"
        iam                    = "${local.aws_endpoint_url}"
        ecr                    = "${local.aws_endpoint_url}"
        cloudformation         = "${local.aws_endpoint_url}"
      }
      %{endif}

      default_tags {
        tags = ${jsonencode(local.common_tags)}
      }
    }
  EOF
}
