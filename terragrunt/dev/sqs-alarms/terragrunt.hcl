# SQS Alarms Module - Development Environment Configuration (AWS)
# Manages SQS queue monitoring alarms

include "root" {
  path = "../../terragrunt.hcl"
}

terraform {
  source = "../../../tofu/modules/sqs-alarms"
}

dependency "notification" {
  config_path = "../notification"

  mock_outputs = {
    monitoring_alerts_sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:e-voting-monitoring-alerts-dev"
  }
}

inputs = {
  project_name                      = "e-voting"
  environment                       = "dev"
  sqs_queue_names                   = ["e-voting-async-api-requests"]
  sqs_dlq_names                     = ["e-voting-async-api-requests-dlq"]
  sqs_dlq_threshold                 = 5
  sqs_old_message_threshold_minutes = 60
  sqs_queue_depth_threshold         = 1000
  alarm_sns_topic_arn               = dependency.notification.outputs.monitoring_alerts_sns_topic_arn
  alarm_evaluation_periods          = 1
  alarm_period_seconds              = 300

  common_tags = {
    Environment = "dev"
    Project     = "e-voting"
    ManagedBy   = "terragrunt"
    Module      = "sqs-alarms"
  }
}
