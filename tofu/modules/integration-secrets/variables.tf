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

variable "secret_name" {
  type        = string
  description = "Name of the secret (e.g., 'http-endpoint-credentials')"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.secret_name))
    error_message = "Secret name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "secret_string" {
  type        = string
  sensitive   = true
  description = "JSON string containing the secret data (e.g., API key, username/password)"

  validation {
    condition     = length(var.secret_string) > 0
    error_message = "Secret string cannot be empty."
  }
}

variable "recovery_window_in_days" {
  type        = number
  default     = 7
  description = "Number of days before secret is permanently deleted after deletion request (7-30)"

  validation {
    condition     = var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30
    error_message = "Recovery window must be between 7 and 30 days."
  }
}

variable "enable_rotation" {
  type        = bool
  default     = false
  description = "Enable automatic secret rotation"
}

variable "rotation_days" {
  type        = number
  default     = 30
  description = "Number of days between rotations (only used if enable_rotation is true)"

  validation {
    condition     = var.rotation_days > 0
    error_message = "Rotation days must be greater than 0."
  }
}

variable "common_tags" {
  type        = map(string)
  default     = {}
  description = "Common tags to apply to all resources"
}
