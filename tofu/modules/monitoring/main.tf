# SNS Topic for Monitoring Alerts (created if not provided)
resource "aws_sns_topic" "monitoring_alerts" {
  count = var.alarm_sns_topic_arn == "" ? 1 : 0

  name              = "${var.project_name}-${var.environment}-monitoring-alerts"
  display_name      = "E-Voting Monitoring Alerts"

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-monitoring-alerts"
    Environment = var.environment
    Module      = "monitoring"
  })
}

# Use provided SNS topic or the one created above
locals {
  alarm_sns_topic_arn = var.alarm_sns_topic_arn != "" ? var.alarm_sns_topic_arn : aws_sns_topic.monitoring_alerts[0].arn
}

# ============================================================
# ALB Alarms
# ============================================================

# Alarm: Unhealthy Targets
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.unhealthy_target_threshold
  alarm_description   = "Alert when ALB has ${var.unhealthy_target_threshold} or more unhealthy targets"
  alarm_actions       = [local.alarm_sns_topic_arn]
  treat_missing_data  = var.treat_missing_data

  dimensions = {
    LoadBalancer = var.alb_name
    TargetGroup  = var.alb_target_group_name
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-alb-unhealthy-targets"
    Environment = var.environment
  })
}

# ============================================================
# RDS Alarms
# ============================================================

# Alarm: RDS CPU Utilization High
resource "aws_cloudwatch_metric_alarm" "rds_cpu_utilization" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.rds_cpu_threshold
  alarm_description   = "Alert when RDS CPU utilization exceeds ${var.rds_cpu_threshold}%"
  alarm_actions       = [local.alarm_sns_topic_arn]
  treat_missing_data  = var.treat_missing_data

  dimensions = {
    DBInstanceIdentifier = var.rds_identifier
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-rds-cpu-high"
    Environment = var.environment
  })
}

# Alarm: RDS Freeable Memory Low
resource "aws_cloudwatch_metric_alarm" "rds_memory_utilization" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-memory-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.rds_memory_threshold
  alarm_description   = "Alert when RDS freeable memory drops below ${var.rds_memory_threshold / 1000000} MB"
  alarm_actions       = [local.alarm_sns_topic_arn]
  treat_missing_data  = var.treat_missing_data

  dimensions = {
    DBInstanceIdentifier = var.rds_identifier
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-rds-memory-low"
    Environment = var.environment
  })
}

# Alarm: RDS Outage (No Connections)
resource "aws_cloudwatch_metric_alarm" "rds_database_connections" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-no-connections"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Alert when RDS has 0 active connections (possible outage)"
  alarm_actions       = [local.alarm_sns_topic_arn]
  treat_missing_data  = "breaching"  # Treat missing as breach (indicates outage)

  dimensions = {
    DBInstanceIdentifier = var.rds_identifier
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-rds-no-connections"
    Environment = var.environment
  })
}

# ============================================================
# SQS Alarms
# ============================================================

# Alarm: SQS Dead Letter Queue Messages
resource "aws_cloudwatch_metric_alarm" "sqs_dlq_messages" {
  for_each = toset(var.sqs_dlq_names)

  alarm_name          = "${var.project_name}-${var.environment}-sqs-dlq-${each.value}-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.sqs_dlq_threshold
  alarm_description   = "Alert when SQS DLQ '${each.value}' has >= ${var.sqs_dlq_threshold} messages"
  alarm_actions       = [local.alarm_sns_topic_arn]
  treat_missing_data  = var.treat_missing_data

  dimensions = {
    QueueName = each.value
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-sqs-dlq-${each.value}"
    Environment = var.environment
  })
}

# Alarm: SQS Queue Old Messages
resource "aws_cloudwatch_metric_alarm" "sqs_old_messages" {
  for_each = toset(var.sqs_queue_names)

  alarm_name          = "${var.project_name}-${var.environment}-sqs-${each.value}-old-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = var.alarm_period_seconds
  statistic           = "Maximum"
  threshold           = var.sqs_old_message_threshold_minutes * 60  # Convert to seconds
  alarm_description   = "Alert when messages in '${each.value}' are older than ${var.sqs_old_message_threshold_minutes} minutes"
  alarm_actions       = [local.alarm_sns_topic_arn]
  treat_missing_data  = var.treat_missing_data

  dimensions = {
    QueueName = each.value
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-sqs-${each.value}-old-messages"
    Environment = var.environment
  })
}

# Alarm: SQS Approximate Number of Messages (Queue Depth)
resource "aws_cloudwatch_metric_alarm" "sqs_queue_depth" {
  for_each = toset(var.sqs_queue_names)

  alarm_name          = "${var.project_name}-${var.environment}-sqs-${each.value}-queue-depth-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = 1000
  alarm_description   = "Alert when SQS queue '${each.value}' depth exceeds 1000 messages"
  alarm_actions       = [local.alarm_sns_topic_arn]
  treat_missing_data  = var.treat_missing_data

  dimensions = {
    QueueName = each.value
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-sqs-${each.value}-queue-depth"
    Environment = var.environment
  })
}

# ============================================================
# ECS Alarms
# ============================================================

# Alarm: ECS Service Task Count Below Desired
resource "aws_cloudwatch_metric_alarm" "ecs_service_running_count" {
  for_each = toset(var.ecs_service_names)

  alarm_name          = "${var.project_name}-${var.environment}-ecs-${each.value}-running-count-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningCount"
  namespace           = "ECS/ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Alert when ECS service '${each.value}' has fewer running tasks than desired"
  alarm_actions       = [local.alarm_sns_topic_arn]
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = each.value
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-ecs-${each.value}-running-count"
    Environment = var.environment
  })
}

# ============================================================
# CloudWatch Dashboard
# ============================================================

resource "aws_cloudwatch_dashboard" "monitoring" {
  dashboard_name = "${var.project_name}-${var.environment}-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      # ALB Widget
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", { stat = "Average", label = "Healthy Targets", dimensions = { LoadBalancer = var.alb_name } }],
            [".", "UnHealthyHostCount", { stat = "Average", label = "Unhealthy Targets", dimensions = { LoadBalancer = var.alb_name } }],
            [".", "TargetResponseTime", { stat = "Average", label = "Response Time", dimensions = { LoadBalancer = var.alb_name } }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Load Balancer Health"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },

      # RDS Widget
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", { stat = "Average", label = "CPU %", dimensions = { DBInstanceIdentifier = var.rds_identifier } }],
            [".", "FreeableMemory", { stat = "Average", label = "Free Memory (bytes)", dimensions = { DBInstanceIdentifier = var.rds_identifier } }],
            [".", "DatabaseConnections", { stat = "Average", label = "Connections", dimensions = { DBInstanceIdentifier = var.rds_identifier } }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "RDS Database Metrics"
        }
      },

      # SQS Widget
      {
        type = "metric"
        properties = {
          metrics = [
            for queue in var.sqs_queue_names : ["AWS/SQS", "ApproximateNumberOfMessagesVisible", { stat = "Average", label = "Queue Depth: ${queue}", dimensions = { QueueName = queue } }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "SQS Queue Depth"
        }
      },

      # SQS DLQ Widget
      {
        type = "metric"
        properties = {
          metrics = [
            for dlq in var.sqs_dlq_names : ["AWS/SQS", "ApproximateNumberOfMessagesVisible", { stat = "Average", label = "DLQ: ${dlq}", dimensions = { QueueName = dlq } }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "SQS Dead Letter Queues"
        }
      },

      # ECS Widget
      {
        type = "metric"
        properties = {
          metrics = [
            for service in var.ecs_service_names : ["ECS/ContainerInsights", "RunningCount", { stat = "Average", label = "Running: ${service}", dimensions = { ClusterName = var.ecs_cluster_name, ServiceName = service } }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "ECS Running Tasks"
        }
      }
    ]
  })
}

# Data source for current AWS region
data "aws_region" "current" {}
