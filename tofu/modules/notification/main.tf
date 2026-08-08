# Conditional SNS topic creation
resource "aws_sns_topic" "monitoring_alerts" {
  count = var.alarm_sns_topic_arn == "" ? 1 : 0
  name  = "${var.project_name}-monitoring-alerts-${var.environment}"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-monitoring-alerts"
    }
  )
}

# Select between created or provided SNS topic
locals {
  alarm_sns_topic_arn = var.alarm_sns_topic_arn != "" ? var.alarm_sns_topic_arn : aws_sns_topic.monitoring_alerts[0].arn
  alarm_sns_topic_name = var.alarm_sns_topic_arn != "" ? "" : aws_sns_topic.monitoring_alerts[0].name
}
