# ECS Async API Service Module Variables

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
  description = "ECS service name (e.g., async-api)"
  type        = string
  default     = "async-api"
  validation {
    condition     = length(var.service_name) > 0 && length(var.service_name) <= 255
    error_message = "Service name must be 1-255 characters."
  }
}

variable "container_image" {
  description = "Container image URI for async API service"
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
  description = "Security group IDs for service tasks"
  type        = list(string)
  validation {
    condition     = length(var.ecs_security_group_ids) > 0
    error_message = "Must provide at least one security group."
  }
}

variable "ecs_subnet_ids" {
  description = "Subnet IDs for service tasks"
  type        = list(string)
  validation {
    condition     = length(var.ecs_subnet_ids) > 0
    error_message = "Must provide at least one subnet."
  }
}

variable "ecs_task_execution_role_arn" {
  description = "IAM role ARN for ECS task execution"
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

variable "sqs_queue_name" {
  description = "SQS queue name for async requests"
  type        = string
  default     = "async-api-requests"
  validation {
    condition     = length(var.sqs_queue_name) > 0 && length(var.sqs_queue_name) <= 80
    error_message = "Queue name must be 1-80 characters."
  }
}

variable "sqs_visibility_timeout" {
  description = "SQS message visibility timeout in seconds"
  type        = number
  default     = 300
  validation {
    condition     = var.sqs_visibility_timeout >= 0 && var.sqs_visibility_timeout <= 43200
    error_message = "Visibility timeout must be 0-43200 seconds."
  }
}

variable "sqs_message_retention" {
  description = "SQS message retention period in seconds (default 4 days)"
  type        = number
  default     = 345600
  validation {
    condition     = var.sqs_message_retention >= 60 && var.sqs_message_retention <= 1209600
    error_message = "Message retention must be 60-1209600 seconds."
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

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    ManagedBy = "terragrunt"
  }
}
