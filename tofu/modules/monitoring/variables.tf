variable "project_name" {
  type        = string
  description = "Project name (e.g., e-voting)"
  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 32
    error_message = "Project name must be between 1 and 32 characters."
  }
}

variable "environment" {
  type        = string
  description = "Environment (dev, staging, prod)"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# ALB Configuration
variable "alb_target_group_name" {
  type        = string
  description = "ALB target group name for health monitoring"
}

variable "alb_name" {
  type        = string
  description = "ALB name for monitoring"
}

variable "unhealthy_target_threshold" {
  type        = number
  description = "Number of unhealthy targets before alarm triggers"
  default     = 1
}

# RDS Configuration
variable "rds_identifier" {
  type        = string
  description = "RDS database identifier (instance ID or cluster ID)"
}

variable "rds_cpu_threshold" {
  type        = number
  description = "RDS CPU utilization threshold (%)"
  default     = 80
  validation {
    condition     = var.rds_cpu_threshold > 0 && var.rds_cpu_threshold <= 100
    error_message = "CPU threshold must be between 0 and 100."
  }
}

variable "rds_memory_threshold" {
  type        = number
  description = "RDS freeable memory threshold (bytes)"
  default     = 500000000  # 500 MB
}

# SQS Configuration
variable "sqs_queue_names" {
  type        = list(string)
  description = "List of SQS queue names to monitor"
  default     = []
}

variable "sqs_dlq_names" {
  type        = list(string)
  description = "List of SQS dead-letter queue names to monitor"
  default     = []
}

variable "sqs_dlq_threshold" {
  type        = number
  description = "SQS DLQ message count threshold before alarm"
  default     = 5
}

variable "sqs_old_message_threshold_minutes" {
  type        = number
  description = "Age threshold for old messages in SQS (minutes)"
  default     = 60
}

# ECS Configuration
variable "ecs_cluster_name" {
  type        = string
  description = "ECS cluster name"
}

variable "ecs_service_names" {
  type        = list(string)
  description = "List of ECS service names to monitor"
  default     = []
}

# SNS Configuration
variable "alarm_sns_topic_arn" {
  type        = string
  description = "SNS topic ARN for alarm notifications (if empty, module creates its own)"
  default     = ""
}

# Monitoring Configuration
variable "evaluation_periods" {
  type        = number
  description = "Number of periods to evaluate before triggering alarm"
  default     = 2
}

variable "datapoints_to_alarm" {
  type        = number
  description = "Number of datapoints that must breach to trigger alarm"
  default     = 2
}

variable "alarm_period_seconds" {
  type        = number
  description = "Period in seconds for metric evaluation"
  default     = 300
}

variable "treat_missing_data" {
  type        = string
  description = "How to treat missing data (missing, breaching, notBreaching, insufficient_data)"
  default     = "notBreaching"
}

variable "tags" {
  type        = map(string)
  description = "Common tags for all resources"
  default     = {}
}
