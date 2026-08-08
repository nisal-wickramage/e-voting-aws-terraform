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

variable "sqs_queue_names" {
  type        = list(string)
  default     = []
  description = "List of SQS queue names to monitor"
}

variable "sqs_dlq_names" {
  type        = list(string)
  default     = []
  description = "List of SQS dead-letter queue names to monitor"
}

variable "sqs_dlq_threshold" {
  type        = number
  default     = 5
  description = "Number of messages in DLQ to trigger alarm"

  validation {
    condition     = var.sqs_dlq_threshold > 0
    error_message = "DLQ threshold must be greater than 0."
  }
}

variable "sqs_old_message_threshold_minutes" {
  type        = number
  default     = 60
  description = "Minutes to consider a message old"

  validation {
    condition     = var.sqs_old_message_threshold_minutes > 0
    error_message = "Old message threshold must be greater than 0."
  }
}

variable "sqs_queue_depth_threshold" {
  type        = number
  default     = 1000
  description = "Number of messages in queue to trigger alarm"

  validation {
    condition     = var.sqs_queue_depth_threshold > 0
    error_message = "Queue depth threshold must be greater than 0."
  }
}

variable "alarm_sns_topic_arn" {
  type        = string
  description = "SNS topic ARN for alarm notifications"
}

variable "alarm_evaluation_periods" {
  type        = number
  default     = 1
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
