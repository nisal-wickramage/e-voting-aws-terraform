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

variable "rds_identifier" {
  type        = string
  description = "RDS instance or cluster identifier"
}

variable "rds_cpu_threshold" {
  type        = number
  default     = 80
  description = "CPU utilization threshold (0-100%)"

  validation {
    condition     = var.rds_cpu_threshold >= 0 && var.rds_cpu_threshold <= 100
    error_message = "CPU threshold must be between 0 and 100."
  }
}

variable "rds_memory_threshold" {
  type        = number
  default     = 500000000
  description = "Freeable memory threshold in bytes (default: 500MB)"

  validation {
    condition     = var.rds_memory_threshold > 0
    error_message = "Memory threshold must be greater than 0."
  }
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
