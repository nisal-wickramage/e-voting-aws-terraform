output "monitoring_alerts_sns_topic_arn" {
  value       = local.alarm_sns_topic_arn
  description = "SNS topic ARN for monitoring alerts"
}

output "monitoring_alerts_sns_topic_name" {
  value       = local.alarm_sns_topic_name
  description = "SNS topic name (empty if using provided ARN)"
}
