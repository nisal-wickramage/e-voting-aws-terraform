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

variable "queue_name" {
  type        = string
  description = "Name of the SQS queue (e.g., 'async-api-requests')"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.queue_name))
    error_message = "Queue name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "visibility_timeout_seconds" {
  type        = number
  default     = 300
  description = "Visibility timeout for queue messages in seconds"

  validation {
    condition     = var.visibility_timeout_seconds >= 0 && var.visibility_timeout_seconds <= 43200
    error_message = "Visibility timeout must be between 0 and 43200 seconds."
  }
}

variable "message_retention_seconds" {
  type        = number
  default     = 1209600  # 14 days
  description = "Message retention period in seconds"

  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600
    error_message = "Message retention must be between 60 and 1209600 seconds."
  }
}

variable "enable_dlq" {
  type        = bool
  default     = true
  description = "Create a dead-letter queue"
}

variable "dlq_max_receive_count" {
  type        = number
  default     = 3
  description = "Number of times a message can be received before going to DLQ"

  validation {
    condition     = var.dlq_max_receive_count > 0
    error_message = "Max receive count must be greater than 0."
  }
}

variable "common_tags" {
  type        = map(string)
  default     = {}
  description = "Common tags to apply to all resources"
}
