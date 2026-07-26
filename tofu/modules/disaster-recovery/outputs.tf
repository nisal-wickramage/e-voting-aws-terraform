output "sns_topic_arn" {
  value       = aws_sns_topic.rds_backup_events.arn
  description = "SNS topic ARN for RDS backup events and notifications"
}

output "sns_topic_name" {
  value       = aws_sns_topic.rds_backup_events.name
  description = "SNS topic name for RDS backup events"
}

output "cloudwatch_log_group_name" {
  value       = aws_cloudwatch_log_group.rds_backups.name
  description = "CloudWatch log group name for RDS backup events"
}

output "backup_automation_role_arn" {
  value       = var.enable_manual_snapshots ? aws_iam_role.rds_backup_automation[0].arn : null
  description = "IAM role ARN for RDS backup automation (if enabled)"
}

output "backup_automation_role_name" {
  value       = var.enable_manual_snapshots ? aws_iam_role.rds_backup_automation[0].name : null
  description = "IAM role name for RDS backup automation (if enabled)"
}

output "daily_snapshot_rule_arn" {
  value       = var.enable_manual_snapshots ? aws_cloudwatch_event_rule.daily_rds_snapshot[0].arn : null
  description = "EventBridge rule ARN for daily RDS snapshots"
}

output "backup_alarm_failed_arn" {
  value       = var.enable_backup_monitoring ? aws_cloudwatch_metric_alarm.rds_backup_failed[0].arn : null
  description = "CloudWatch alarm ARN for backup failures"
}

output "backup_alarm_storage_arn" {
  value       = var.enable_backup_monitoring ? aws_cloudwatch_metric_alarm.rds_backup_storage[0].arn : null
  description = "CloudWatch alarm ARN for backup storage usage"
}

output "dashboard_name" {
  value       = var.enable_backup_monitoring ? aws_cloudwatch_dashboard.rds_backups[0].dashboard_name : null
  description = "CloudWatch dashboard name for RDS backup monitoring"
}

output "backup_retention_days" {
  value       = var.rds_backup_retention_days
  description = "Number of days RDS backups are retained"
}

output "backup_window" {
  value       = var.backup_window
  description = "RDS backup window (UTC)"
}

output "backup_encryption_enabled" {
  value       = var.enable_backup_encryption
  description = "Whether backup encryption is enabled"
}
