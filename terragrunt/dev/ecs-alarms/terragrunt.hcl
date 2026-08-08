# ECS Alarms Module - Development Environment Configuration (AWS)
# Manages ALB and ECS health monitoring alarms

include "root" {
  path = "../../terragrunt.hcl"
}

terraform {
  source = "../../../tofu/modules/ecs-alarms"
}

dependency "notification" {
  config_path = "../notification"

  mock_outputs = {
    monitoring_alerts_sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:e-voting-monitoring-alerts-dev"
  }
}

dependency "cluster" {
  config_path = "../cluster"

  mock_outputs = {
    alb_name                      = "e-voting-alb"
    default_target_group_name     = "e-voting-default-tg"
    ecs_cluster_name              = "e-voting-cluster"
  }
}

inputs = {
  project_name                  = "e-voting"
  environment                   = "dev"
  alb_name                      = dependency.cluster.outputs.alb_name
  alb_target_group_name         = dependency.cluster.outputs.default_target_group_name
  ecs_cluster_name              = dependency.cluster.outputs.ecs_cluster_name
  unhealthy_target_threshold    = 1
  alarm_sns_topic_arn           = dependency.notification.outputs.monitoring_alerts_sns_topic_arn
  alarm_evaluation_periods      = 2
  alarm_period_seconds          = 300

  common_tags = {
    Environment = "dev"
    Project     = "e-voting"
    ManagedBy   = "terragrunt"
    Module      = "ecs-alarms"
  }
}
