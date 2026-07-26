variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones for subnet deployment"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Must specify exactly 2 availability zones."
  }
}

variable "private_subnet_cidrs" {
  description = "Map of tier names to lists of CIDR blocks (2 per tier for 2 AZs)"
  type        = map(list(string))
  validation {
    condition     = alltrue([for tier, cidrs in var.private_subnet_cidrs : length(cidrs) == 2])
    error_message = "Each tier must have exactly 2 CIDR blocks (one per AZ)."
  }
  validation {
    condition = (
      length(var.private_subnet_cidrs) == 3 &&
      contains(keys(var.private_subnet_cidrs), "web") &&
      contains(keys(var.private_subnet_cidrs), "app") &&
      contains(keys(var.private_subnet_cidrs), "db")
    )
    error_message = "Tier keys must be exactly: web, app, db"
  }
}

variable "vpc_endpoint_services" {
  description = "List of VPC endpoint services to create. Services: s3, dynamodb (gateway endpoints), ec2, elasticloadbalancing, cloudwatch, secretsmanager, ecr.api, ecr.dkr, logs (interface endpoints). Empty list creates no VPC endpoints."
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for svc in var.vpc_endpoint_services : contains([
        "s3", "dynamodb", "ec2", "elasticloadbalancing", "cloudwatch",
        "secretsmanager", "ecr.api", "ecr.dkr", "logs"
      ], svc)
    ])
    error_message = "Invalid VPC endpoint service. Allowed services: s3, dynamodb, ec2, elasticloadbalancing, cloudwatch, secretsmanager, ecr.api, ecr.dkr, logs"
  }
}

variable "s3_prefix_list_id" {
  description = "AWS S3 prefix list ID for the region (optional for S3 route)"
  type        = string
  default     = ""
}

variable "dynamodb_prefix_list_id" {
  description = "AWS DynamoDB prefix list ID for the region (optional for DynamoDB route)"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 20
    error_message = "Project name must be 1-20 characters."
  }
}

variable "aws_region" {
  description = "AWS region for VPC endpoint service names"
  type        = string
  default     = "us-east-1"
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d$", var.aws_region))
    error_message = "AWS region must be a valid region format (e.g., us-east-1)."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs for debugging"
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "VPC Flow Logs retention in days"
  type        = number
  default     = 7
  validation {
    condition     = var.flow_logs_retention_days > 0 && var.flow_logs_retention_days <= 3653
    error_message = "Flow logs retention must be between 1 and 3653 days."
  }
}
