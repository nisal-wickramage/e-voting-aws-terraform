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
variable "alb_domain_name" {
  type        = string
  description = "ALB domain name or DNS endpoint (used as CloudFront origin for API)"
}

variable "alb_origin_path" {
  type        = string
  description = "Origin path for ALB (e.g., /api)"
  default     = ""
}

# S3 Frontend Configuration
variable "s3_bucket_regional_domain_name" {
  type        = string
  description = "S3 bucket regional domain name (e.g., bucket.s3.us-east-1.amazonaws.com)"
}

variable "cloudfront_oai_iam_arn" {
  type        = string
  description = "CloudFront OAI IAM ARN for S3 bucket access"
}

# WAF Configuration
variable "enable_waf" {
  type        = bool
  description = "Enable AWS WAF for CloudFront distributions"
  default     = true
}

variable "waf_rate_limit" {
  type        = number
  description = "Rate limit threshold per IP (requests per 5 minutes)"
  default     = 2000
}

variable "waf_geo_blocking_enabled" {
  type        = bool
  description = "Enable geographic blocking"
  default     = false
}

variable "waf_geo_blocked_countries" {
  type        = list(string)
  description = "List of country codes to block (e.g., [\"CN\", \"RU\"])"
  default     = []
}

# CloudFront Configuration
variable "default_ttl" {
  type        = number
  description = "Default TTL in seconds for CloudFront cache"
  default     = 3600
}

variable "max_ttl" {
  type        = number
  description = "Maximum TTL in seconds for CloudFront cache"
  default     = 86400
}

variable "compress" {
  type        = bool
  description = "Enable gzip compression in CloudFront"
  default     = true
}

variable "viewer_protocol_policy" {
  type        = string
  description = "Viewer protocol policy (allow-all, https-only, redirect-to-https)"
  default     = "redirect-to-https"
  validation {
    condition     = contains(["allow-all", "https-only", "redirect-to-https"], var.viewer_protocol_policy)
    error_message = "Must be allow-all, https-only, or redirect-to-https."
  }
}

variable "tags" {
  type        = map(string)
  description = "Common tags for all resources"
  default     = {}
}
