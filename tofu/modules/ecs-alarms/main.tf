# ALB Unhealthy Targets Alarm
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  alarm_name          = "${var.project_name}-alb-unhealthy-targets-${var.environment}"
  alarm_description   = "Alert when ALB has unhealthy targets"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.unhealthy_target_threshold
  alarm_actions       = [var.alarm_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_name
    TargetGroup  = var.alb_target_group_name
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-alb-unhealthy-targets"
    }
  )
}
