output "monitoring_alerts_sns_topic_arn" {
  value       = var.alarm_sns_topic_arn != "" ? var.alarm_sns_topic_arn : aws_sns_topic.monitoring_alerts[0].arn
  description = "SNS topic ARN for monitoring alerts"
}

output "monitoring_alerts_sns_topic_name" {
  value       = var.alarm_sns_topic_arn != "" ? null : aws_sns_topic.monitoring_alerts[0].name
  description = "SNS topic name for monitoring alerts (if created by module)"
}

output "alb_unhealthy_targets_alarm_arn" {
  value       = aws_cloudwatch_metric_alarm.alb_unhealthy_targets.arn
  description = "ALB unhealthy targets alarm ARN"
}

output "rds_cpu_utilization_alarm_arn" {
  value       = aws_cloudwatch_metric_alarm.rds_cpu_utilization.arn
  description = "RDS CPU utilization alarm ARN"
}

output "rds_memory_utilization_alarm_arn" {
  value       = aws_cloudwatch_metric_alarm.rds_memory_utilization.arn
  description = "RDS memory utilization alarm ARN"
}

output "rds_database_connections_alarm_arn" {
  value       = aws_cloudwatch_metric_alarm.rds_database_connections.arn
  description = "RDS database connections alarm ARN (outage detection)"
}

output "sqs_dlq_message_alarms" {
  value = {
    for dlq, alarm in aws_cloudwatch_metric_alarm.sqs_dlq_messages : dlq => alarm.arn
  }
  description = "Map of SQS DLQ name to alarm ARN"
}

output "sqs_old_message_alarms" {
  value = {
    for queue, alarm in aws_cloudwatch_metric_alarm.sqs_old_messages : queue => alarm.arn
  }
  description = "Map of SQS queue name to old message alarm ARN"
}

output "sqs_queue_depth_alarms" {
  value = {
    for queue, alarm in aws_cloudwatch_metric_alarm.sqs_queue_depth : queue => alarm.arn
  }
  description = "Map of SQS queue name to queue depth alarm ARN"
}

output "ecs_running_count_alarms" {
  value = {
    for service, alarm in aws_cloudwatch_metric_alarm.ecs_service_running_count : service => alarm.arn
  }
  description = "Map of ECS service name to running count alarm ARN"
}

output "dashboard_name" {
  value       = aws_cloudwatch_dashboard.monitoring.dashboard_name
  description = "CloudWatch dashboard name for monitoring"
}

output "all_alarm_arns" {
  value = concat(
    [
      aws_cloudwatch_metric_alarm.alb_unhealthy_targets.arn,
      aws_cloudwatch_metric_alarm.rds_cpu_utilization.arn,
      aws_cloudwatch_metric_alarm.rds_memory_utilization.arn,
      aws_cloudwatch_metric_alarm.rds_database_connections.arn
    ],
    [for alarm in aws_cloudwatch_metric_alarm.sqs_dlq_messages : alarm.arn],
    [for alarm in aws_cloudwatch_metric_alarm.sqs_old_messages : alarm.arn],
    [for alarm in aws_cloudwatch_metric_alarm.sqs_queue_depth : alarm.arn],
    [for alarm in aws_cloudwatch_metric_alarm.ecs_service_running_count : alarm.arn]
  )
  description = "List of all CloudWatch alarm ARNs"
}
