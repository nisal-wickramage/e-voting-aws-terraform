# Monitoring Module - Development Environment Configuration (AWS)

include "root" {
  path = "../../terragrunt.hcl"
}

terraform {
  source = "../../../tofu/modules/monitoring"
}

dependency "platform" {
  config_path = "../platform"

  mock_outputs = {
    alb_name                  = "e-voting-alb"
    default_target_group_name = "e-voting-default-tg"
    ecs_cluster_name          = "e-voting-cluster"
  }
}

dependency "database" {
  config_path = "../database"

  mock_outputs = {
    rds_identifier = "e-voting-dev-db"
  }
}

inputs = {
  project_name  = "e-voting"
  environment   = "dev"

  # ALB Configuration
  alb_name                    = dependency.platform.outputs.alb_name
  alb_target_group_name     = dependency.platform.outputs.default_target_group_name
  unhealthy_target_threshold  = 1

  # RDS Configuration
  rds_identifier       = dependency.database.outputs.rds_identifier
  rds_cpu_threshold    = 80
  rds_memory_threshold = 500000000  # 500 MB

  # SQS Configuration (update queue names based on your setup)
  sqs_queue_names                  = ["e-voting-async-api-requests"]
  sqs_dlq_names                    = ["e-voting-async-api-requests-dlq"]
  sqs_dlq_threshold                = 5
  sqs_old_message_threshold_minutes = 60

  # ECS Configuration
  ecs_cluster_name = dependency.platform.outputs.ecs_cluster_name
  ecs_service_names = [
    "e-voting-async-api",
    "e-voting-worker",
    "e-voting-api"
  ]

  # SNS Topic for alerts (module creates its own)
  alarm_sns_topic_arn = ""

  # Monitoring thresholds
  evaluation_periods      = 2
  datapoints_to_alarm     = 2
  alarm_period_seconds    = 300
  treat_missing_data      = "notBreaching"

  tags = {
    Environment = "dev"
    Project     = "e-voting"
    ManagedBy   = "terragrunt"
    Module      = "monitoring"
  }
}
