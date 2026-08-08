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

variable "alarm_sns_topic_arn" {
  type        = string
  default     = ""
  description = "Existing SNS topic ARN for alarms. If empty, a new topic will be created."
}

variable "common_tags" {
  type        = map(string)
  default     = {}
  description = "Common tags to apply to all resources"
}
