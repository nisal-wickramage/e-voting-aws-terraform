# RDS CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "rds_cpu_utilization" {
  alarm_name          = "${var.project_name}-rds-cpu-utilization-${var.environment}"
  alarm_description   = "Alert when RDS CPU utilization exceeds threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.rds_cpu_threshold
  alarm_actions       = [var.alarm_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_identifier
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-rds-cpu-utilization"
    }
  )
}

# RDS Memory Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "rds_memory_utilization" {
  alarm_name          = "${var.project_name}-rds-memory-utilization-${var.environment}"
  alarm_description   = "Alert when RDS freeable memory falls below threshold"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.rds_memory_threshold
  alarm_actions       = [var.alarm_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_identifier
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-rds-memory-utilization"
    }
  )
}

# RDS Database Connections Alarm (Outage Detection)
resource "aws_cloudwatch_metric_alarm" "rds_database_connections" {
  alarm_name          = "${var.project_name}-rds-database-connections-${var.environment}"
  alarm_description   = "Alert when RDS database connections drop (outage detection)"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_actions       = [var.alarm_sns_topic_arn]
  treat_missing_data  = "breaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_identifier
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-rds-database-connections"
    }
  )
}
