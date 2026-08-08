# RDS Alarms Module - Development Environment Configuration (AWS)
# Manages RDS database monitoring alarms

include "root" {
  path = "../../terragrunt.hcl"
}

terraform {
  source = "../../../tofu/modules/rds-alarms"
}

dependency "notification" {
  config_path = "../notification"

  mock_outputs = {
    monitoring_alerts_sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:e-voting-monitoring-alerts-dev"
  }
}

dependency "database" {
  config_path = "../database"

  mock_outputs = {
    rds_identifier = "e-voting-dev-db"
  }
}

inputs = {
  project_name            = "e-voting"
  environment             = "dev"
  rds_identifier          = dependency.database.outputs.rds_identifier
  rds_cpu_threshold       = 80
  rds_memory_threshold    = 500000000  # 500 MB
  alarm_sns_topic_arn     = dependency.notification.outputs.monitoring_alerts_sns_topic_arn
  alarm_evaluation_periods = 2
  alarm_period_seconds    = 300

  common_tags = {
    Environment = "dev"
    Project     = "e-voting"
    ManagedBy   = "terragrunt"
    Module      = "rds-alarms"
  }
}
