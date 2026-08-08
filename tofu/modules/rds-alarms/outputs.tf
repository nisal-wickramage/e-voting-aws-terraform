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
