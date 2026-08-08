output "alb_unhealthy_targets_alarm_arn" {
  value       = aws_cloudwatch_metric_alarm.alb_unhealthy_targets.arn
  description = "ALB unhealthy targets alarm ARN"
}
