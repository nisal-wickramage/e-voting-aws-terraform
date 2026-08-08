variable "project_name" {
  type        = string
  description = "Project name for resource naming"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "alb_name" {
  type        = string
  description = "Name of the Application Load Balancer"
}

variable "alb_target_group_name" {
  type        = string
  description = "Name of the ALB target group"
}

variable "unhealthy_target_threshold" {
  type        = number
  default     = 1
  description = "Number of unhealthy targets to trigger alarm"

  validation {
    condition     = var.unhealthy_target_threshold > 0
    error_message = "Unhealthy target threshold must be greater than 0."
  }
}

variable "ecs_cluster_name" {
  type        = string
  description = "Name of the ECS cluster"
}

variable "alarm_sns_topic_arn" {
  type        = string
  description = "SNS topic ARN for alarm notifications"
}

variable "alarm_evaluation_periods" {
  type        = number
  default     = 2
  description = "Number of periods to evaluate alarm"
}

variable "alarm_period_seconds" {
  type        = number
  default     = 300
  description = "Alarm evaluation period in seconds"
}

variable "common_tags" {
  type        = map(string)
  default     = {}
  description = "Common tags to apply to all resources"
}
