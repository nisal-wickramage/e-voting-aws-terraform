# Notification Module - Development Environment Configuration (AWS)
# Manages SNS topic for alarm notifications

include "root" {
  path = "../../terragrunt.hcl"
}

terraform {
  source = "../../../tofu/modules/notification"
}

inputs = {
  project_name         = "e-voting"
  environment          = "dev"
  alarm_sns_topic_arn  = ""  # Leave empty to create new topic

  common_tags = {
    Environment = "dev"
    Project     = "e-voting"
    ManagedBy   = "terragrunt"
    Module      = "notification"
  }
}
