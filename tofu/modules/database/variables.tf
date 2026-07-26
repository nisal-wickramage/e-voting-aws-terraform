# Database Module Variables

variable "vpc_id" {
  description = "VPC ID from network module"
  type        = string
  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "VPC ID must be a valid VPC identifier (vpc-*)."
  }
}

variable "private_subnet_ids" {
  description = "Private database subnet IDs from network module (must be ≥2 for multi-AZ)"
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "Must provide at least 2 private subnets for RDS multi-AZ."
  }
  validation {
    condition     = alltrue([for subnet in var.private_subnet_ids : can(regex("^subnet-", subnet))])
    error_message = "All subnet IDs must be valid subnet identifiers (subnet-*)."
  }
}

variable "ecs_security_group_id" {
  description = "ECS security group ID for database access"
  type        = string
  validation {
    condition     = can(regex("^sg-", var.ecs_security_group_id))
    error_message = "Security group ID must be valid (sg-*)."
  }
}

variable "db_instance_class" {
  description = "RDS instance class (smallest recommended: db.t3.micro)"
  type        = string
  default     = "db.t3.micro"
  validation {
    condition     = can(regex("^db\\.", var.db_instance_class))
    error_message = "Instance class must be valid RDS class (e.g., db.t3.micro)."
  }
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB (minimum 20)"
  type        = number
  default     = 20
  validation {
    condition     = var.db_allocated_storage >= 20
    error_message = "Allocated storage must be at least 20 GB."
  }
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "evoting"
  validation {
    condition     = can(regex("^[a-z][a-z0-9]*$", var.db_name))
    error_message = "Database name must start with letter and contain only lowercase alphanumeric."
  }
}

variable "db_username" {
  description = "Master database username"
  type        = string
  default     = "postgres"
  sensitive   = true
  validation {
    condition     = length(var.db_username) >= 1 && length(var.db_username) <= 63
    error_message = "Username must be 1-63 characters."
  }
}

variable "db_password" {
  description = "Master database password (min 8 chars, alphanumeric + special)"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.db_password) >= 8
    error_message = "Password must be at least 8 characters."
  }
}

variable "db_backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
  validation {
    condition     = var.db_backup_retention_days >= 1 && var.db_backup_retention_days <= 35
    error_message = "Backup retention must be 1-35 days."
  }
}

variable "db_multi_az" {
  description = "Enable multi-AZ deployment"
  type        = bool
  default     = true
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot on deletion (NOT recommended for prod)"
  type        = bool
  default     = true
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
