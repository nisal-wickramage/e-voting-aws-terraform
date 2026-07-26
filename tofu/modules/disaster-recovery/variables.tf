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

# RDS Configuration
variable "rds_cluster_id" {
  type        = string
  description = "RDS cluster identifier"
}

variable "rds_backup_retention_days" {
  type        = number
  description = "Number of days to retain RDS backups"
  validation {
    condition     = var.rds_backup_retention_days >= 1 && var.rds_backup_retention_days <= 35
    error_message = "Backup retention must be between 1 and 35 days."
  }
}

variable "backup_window" {
  type        = string
  description = "Preferred backup window in UTC (e.g., 03:00-04:00)"
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  type        = string
  description = "Preferred maintenance window in UTC (e.g., sun:04:00-sun:05:00)"
  default     = "sun:04:00-sun:05:00"
}

# Backup encryption
variable "enable_backup_encryption" {
  type        = bool
  description = "Enable encryption for RDS backups"
  default     = true
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ID for backup encryption (if enable_backup_encryption=true)"
  default     = null
}

# Manual snapshot configuration
variable "enable_manual_snapshots" {
  type        = bool
  description = "Enable manual snapshot infrastructure"
  default     = true
}

variable "snapshot_retention_days" {
  type        = number
  description = "Number of days to retain manual snapshots before deletion"
  default     = 30
}

# Monitoring
variable "enable_backup_monitoring" {
  type        = bool
  description = "Enable CloudWatch alarms for backup health"
  default     = true
}

variable "backup_failure_threshold_count" {
  type        = number
  description = "Number of failed backup attempts before alarm triggers"
  default     = 1
}

variable "tags" {
  type        = map(string)
  description = "Common tags for all resources"
  default     = {}
}
