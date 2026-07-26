# ECS API Service Module Variables

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
  description = "ECS service name (e.g., api, voting-api)"
  type        = string
  default     = "api"
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
  description = "Container image URI for API service"
  type        = string
  validation {
    condition     = length(var.container_image) > 0
    error_message = "Container image must not be empty."
  }
}

variable "container_port" {
  description = "Container port for service"
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

variable "alb_target_group_arn" {
  description = "ALB target group ARN for service registration"
  type        = string
  validation {
    condition     = can(regex("arn:aws:elasticloadbalancing:", var.alb_target_group_arn))
    error_message = "Must be a valid ALB target group ARN."
  }
}

variable "alb_listener_arn" {
  description = "ALB listener ARN for rule creation"
  type        = string
  validation {
    condition     = can(regex("arn:aws:elasticloadbalancing:", var.alb_listener_arn))
    error_message = "Must be a valid ALB listener ARN."
  }
}

variable "listener_rule_path_pattern" {
  description = "ALB listener rule path pattern (e.g., /api/*)"
  type        = list(string)
  default     = ["/api/*"]
  validation {
    condition     = length(var.listener_rule_path_pattern) > 0
    error_message = "At least one path pattern must be provided."
  }
}

variable "listener_rule_priority" {
  description = "Priority for ALB listener rule (1-50000)"
  type        = number
  default     = 100
  validation {
    condition     = var.listener_rule_priority >= 1 && var.listener_rule_priority <= 50000
    error_message = "Priority must be between 1 and 50000."
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

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "postgres"
  validation {
    condition     = length(var.db_username) > 0
    error_message = "Database username must not be empty."
  }
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.db_password) >= 8
    error_message = "Database password must be at least 8 characters."
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

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
