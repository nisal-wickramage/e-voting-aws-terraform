# Network Module - Development Environment Configuration (AWS)

include "root" {
  path = "../../terragrunt.hcl"
}

terraform {
  source = "../../../tofu/modules/network"
}

inputs = {
  # VPC Configuration
  vpc_cidr = "10.0.0.0/16"

  # Tier-based subnets (2 per tier, 1 per AZ)
  private_subnet_cidrs = {
    web = ["10.0.1.0/24", "10.0.2.0/24"]       # CloudFront ALB ingress
    app = ["10.0.11.0/24", "10.0.12.0/24"]     # ECS Fargate tasks
    db  = ["10.0.21.0/24", "10.0.22.0/24"]     # RDS PostgreSQL
  }

  # VPC Endpoint services to create
  # Gateway endpoints: s3, dynamodb
  # Interface endpoints: ec2, elasticloadbalancing, cloudwatch, secretsmanager, ecr.api, ecr.dkr, logs
  vpc_endpoint_services = ["s3", "ecr.api", "ecr.dkr", "logs", "secretsmanager"]

  # Prefix lists for S3/DynamoDB routing (optional - can be obtained from AWS)
  s3_prefix_list_id       = ""
  dynamodb_prefix_list_id = ""

  # Environment and project settings
  environment  = "dev"
  project_name = "e-voting"
  aws_region   = "us-east-1"

  # Enable VPC Flow Logs for debugging
  enable_flow_logs         = false
  flow_logs_retention_days = 7
}
