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

variable "vpc_id" {
  type        = string
  description = "VPC ID for transit gateway attachment"

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "VPC ID must start with vpc-"
  }
}

variable "transit_gateway_id" {
  type        = string
  description = "Transit gateway ID to attach to"

  validation {
    condition     = can(regex("^tgw-", var.transit_gateway_id))
    error_message = "Transit gateway ID must start with tgw-"
  }
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for transit gateway attachment"

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet ID must be provided."
  }
}

variable "route_table_ids" {
  type        = list(string)
  description = "List of route table IDs to add transit gateway routes to"

  validation {
    condition     = length(var.route_table_ids) > 0
    error_message = "At least one route table ID must be provided."
  }
}

variable "security_group_id" {
  type        = string
  description = "Security group ID to allow HTTP traffic to transit gateway"

  validation {
    condition     = can(regex("^sg-", var.security_group_id))
    error_message = "Security group ID must start with sg-"
  }
}

variable "http_endpoint_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "CIDR block of the HTTP endpoint destination"
}

variable "nacl_ids_by_tier" {
  type        = map(list(string))
  default     = {}
  description = "Map of tier names to NACL IDs (e.g., {app = [nacl-123]})"
}

variable "enable_http_traffic" {
  type        = bool
  default     = true
  description = "Enable HTTP (80) traffic to transit gateway"
}

variable "enable_https_traffic" {
  type        = bool
  default     = true
  description = "Enable HTTPS (443) traffic to transit gateway"
}

variable "common_tags" {
  type        = map(string)
  default     = {}
  description = "Common tags to apply to all resources"
}
