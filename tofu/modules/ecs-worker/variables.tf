# ECS Worker Service Module Variables

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
  validation {
    condition     = length(var.cluster_name) > 0
    error_message = "Cluster name must not be empty."
  }
}

variable "cluster_arn" {
  description = "ECS cluster ARN"
  type        = string
  validation {
    condition     = can(regex("arn:aws:ecs:", var.cluster_arn))
    error_message = "Must be a valid ECS cluster ARN."
  }
}

variable "service_name" {
  description = "ECS service name (e.g., worker, event-processor)"
  type        = string
  default     = "worker"
  validation {
    condition     = length(var.service_name) > 0 && length(var.service_name) <= 255
    error_message = "Service name must be 1-255 characters."
  }
}
# ECR Configuration
variable "enable_ecr" {
  description = "Create ECR repository for this service"
  type        = bool
  default     = true
}

variable "image_tag_mutability" {
  description = "Enable image tag mutability (allow overwrite)"
  type        = string
  default     = "MUTABLE"
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "Must be MUTABLE or IMMUTABLE."
  }
}

variable "image_scan_on_push" {
  description = "Enable ECR image scanning on push"
  type        = bool
  default     = true
}

variable "ecr_retention_days" {
  description = "Days to keep old ECR images before deletion"
  type        = number
  default     = 30
  validation {
    condition     = var.ecr_retention_days > 0 && var.ecr_retention_days <= 1000
    error_message = "Retention must be between 1 and 1000 days."
  }
}
variable "container_image" {
  description = "Container image URI for worker service"
  type        = string
  validation {
    condition     = length(var.container_image) > 0
    error_message = "Container image must not be empty."
  }
}

variable "container_port" {
  description = "Container port for health checks"
  type        = number
  default     = 8000
  validation {
    condition     = var.container_port >= 1024 && var.container_port <= 65535
    error_message = "Container port must be between 1024 and 65535."
  }
}

variable "container_memory" {
  description = "Memory for service container in MB"
  type        = number
  default     = 512
  validation {
    condition     = var.container_memory >= 256 && var.container_memory <= 30720
    error_message = "Memory must be between 256 MB and 30 GB."
  }
}

variable "container_cpu" {
  description = "CPU units for service container (256=0.25 vCPU)"
  type        = number
  default     = 256
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.container_cpu)
    error_message = "CPU must be 256, 512, 1024, 2048, or 4096."
  }
}

variable "desired_count" {
  description = "Desired number of running tasks"
  type        = number
  default     = 2
  validation {
    condition     = var.desired_count >= 1 && var.desired_count <= 10
    error_message = "Desired count must be 1-10 tasks."
  }
}

variable "ecs_security_group_ids" {
  description = "Security groups for ECS tasks"
  type        = list(string)
  validation {
    condition     = length(var.ecs_security_group_ids) > 0
    error_message = "At least one security group must be provided."
  }
}

variable "ecs_subnet_ids" {
  description = "Subnets for ECS tasks"
  type        = list(string)
  validation {
    condition     = length(var.ecs_subnet_ids) > 0
    error_message = "At least one subnet must be provided."
  }
}

variable "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN"
  type        = string
  validation {
    condition     = can(regex("arn:aws:iam:", var.ecs_task_execution_role_arn))
    error_message = "Must be a valid IAM role ARN."
  }
}

variable "sqs_queue_url" {
  description = "SQS queue URL to consume messages from"
  type        = string
  validation {
    condition     = can(regex("https://sqs\\..*\\.amazonaws\\.com/", var.sqs_queue_url))
    error_message = "Must be a valid SQS queue URL."
  }
}

variable "sqs_queue_arn" {
  description = "SQS queue ARN"
  type        = string
  validation {
    condition     = can(regex("arn:aws:sqs:", var.sqs_queue_arn))
    error_message = "Must be a valid SQS queue ARN."
  }
}

variable "db_host" {
  description = "Database host"
  type        = string
  validation {
    condition     = length(var.db_host) > 0
    error_message = "Database host must not be empty."
  }
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
  validation {
    condition     = var.db_port >= 1024 && var.db_port <= 65535
    error_message = "Database port must be between 1024 and 65535."
  }
}

variable "db_name" {
  description = "Database name"
  type        = string
  validation {
    condition     = length(var.db_name) > 0
    error_message = "Database name must not be empty."
  }
}

variable "db_credentials_secret_arn" {
  description = "Secrets Manager ARN for database credentials"
  type        = string
  validation {
    condition     = can(regex("arn:aws:secretsmanager:", var.db_credentials_secret_arn))
    error_message = "Must be a valid Secrets Manager secret ARN."
  }
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
  description = "Project name for resource naming"
  type        = string
  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 20
    error_message = "Project name must be 1-20 characters."
  }
}

variable "secrets_arns" {
  description = "Map of secret names to their ARNs (e.g., {api_key = 'arn:aws:secretsmanager:...'})"
  type        = map(string)
  default     = {}
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
