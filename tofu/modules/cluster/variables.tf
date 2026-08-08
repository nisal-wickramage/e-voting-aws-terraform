variable "vpc_id" {
  description = "VPC ID from network module"
  type        = string
  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "VPC ID must be a valid VPC identifier (vpc-*)."
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR block from network module (for security group rules)"
  type        = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

variable "private_subnet_ids" {
  description = "Private subnet IDs from network module (for ALB placement)"
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "Must provide at least 2 private subnets for high availability."
  }
  validation {
    condition     = alltrue([for subnet in var.private_subnet_ids : can(regex("^subnet-", subnet))])
    error_message = "All subnet IDs must be valid subnet identifiers (subnet-*)."
  }
}

variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  validation {
    condition     = length(var.cluster_name) > 0 && length(var.cluster_name) <= 255
    error_message = "Cluster name must be 1-255 characters."
  }
}

variable "alb_name" {
  description = "Name of the Application Load Balancer"
  type        = string
  validation {
    condition     = length(var.alb_name) > 0 && length(var.alb_name) <= 32
    error_message = "ALB name must be 1-32 characters."
  }
}

variable "enable_container_insights" {
  description = "Enable ECS Container Insights for monitoring"
  type        = bool
  default     = true
}

variable "enable_execute_command" {
  description = "Enable ECS Exec for interactive container access (security implications)"
  type        = bool
  default     = false
}

variable "alb_internal" {
  description = "Whether ALB is internal (private) or internet-facing"
  type        = bool
  default     = true
  validation {
    condition     = var.alb_internal == true
    error_message = "ALB must be internal (private subnets only). Internet exposure via CloudFront only."
  }
}

variable "alb_enable_deletion_protection" {
  description = "Prevent accidental ALB deletion"
  type        = bool
  default     = false
}

variable "deregistration_delay" {
  description = "Time in seconds to wait for connection draining"
  type        = number
  default     = 30
  validation {
    condition     = var.deregistration_delay >= 0 && var.deregistration_delay <= 3600
    error_message = "Deregistration delay must be between 0 and 3600 seconds."
  }
}

variable "enable_cross_zone_load_balancing" {
  description = "Distribute traffic across availability zones"
  type        = bool
  default     = true
}

variable "enable_alb_access_logs" {
  description = "Enable ALB access logging to S3"
  type        = bool
  default     = false
}

variable "alb_access_logs_s3_bucket" {
  description = "S3 bucket name for ALB access logs (required if enable_alb_access_logs is true)"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 20
    error_message = "Project name must be 1-20 characters."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
