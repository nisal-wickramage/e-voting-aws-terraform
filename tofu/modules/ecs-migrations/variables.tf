# ECS Migration Task Module Variables

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

variable "task_family_name" {
  description = "ECS task family name"
  type        = string
  default     = "evoting-migrations"
  validation {
    condition     = length(var.task_family_name) > 0 && length(var.task_family_name) <= 255
    error_message = "Task family name must be 1-255 characters."
  }
}

variable "container_image" {
  description = "Container image for migrations (must include migration tools like Alembic)"
  type        = string
  validation {
    condition     = length(var.container_image) > 0
    error_message = "Container image must not be empty."
  }
}

variable "container_memory" {
  description = "Memory for migration container in MB"
  type        = number
  default     = 512
  validation {
    condition     = var.container_memory >= 256 && var.container_memory <= 30720
    error_message = "Memory must be between 256 MB and 30 GB."
  }
}

variable "container_cpu" {
  description = "CPU units for migration container (256=0.25 vCPU)"
  type        = number
  default     = 256
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.container_cpu)
    error_message = "CPU must be 256, 512, 1024, 2048, or 4096."
  }
}

variable "db_host" {
  description = "Database host"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "ecs_task_execution_role_arn" {
  description = "IAM role ARN for ECS task execution"
  type        = string
  validation {
    condition     = can(regex("arn:aws:iam:", var.ecs_task_execution_role_arn))
    error_message = "Must be a valid IAM role ARN."
  }
}

variable "ecs_security_group_ids" {
  description = "Security group IDs for migration task"
  type        = list(string)
  validation {
    condition     = length(var.ecs_security_group_ids) > 0
    error_message = "Must provide at least one security group."
  }
}

variable "ecs_subnet_ids" {
  description = "Subnet IDs for migration task"
  type        = list(string)
  validation {
    condition     = length(var.ecs_subnet_ids) > 0
    error_message = "Must provide at least one subnet."
  }
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
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
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 32
    error_message = "Project name must be 1-32 characters."
  }
}

variable "secrets_arns" {
  description = "Map of secret names to their ARNs (e.g., {api_key = 'arn:aws:secretsmanager:...'})"
  type        = map(string)
  default     = {}
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    ManagedBy = "terragrunt"
  }
}
