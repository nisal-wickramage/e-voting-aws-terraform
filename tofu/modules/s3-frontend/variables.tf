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

variable "enable_versioning" {
  type        = bool
  description = "Enable S3 versioning for disaster recovery"
  default     = true
}

variable "enable_logging" {
  type        = bool
  description = "Enable S3 access logging"
  default     = false
}

variable "logging_bucket" {
  type        = string
  description = "S3 bucket for storing access logs (if enable_logging=true)"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Common tags for all resources"
  default     = {}
}
