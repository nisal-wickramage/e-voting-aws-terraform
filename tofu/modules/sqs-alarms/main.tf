# SQS Dead-Letter Queue Messages Alarm
resource "aws_cloudwatch_metric_alarm" "sqs_dlq_messages" {
  for_each = toset(var.sqs_dlq_names)

  alarm_name          = "${var.project_name}-sqs-dlq-${each.value}-${var.environment}"
  alarm_description   = "Alert when messages appear in DLQ ${each.value}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.sqs_dlq_threshold
  alarm_actions       = [var.alarm_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = each.value
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-sqs-dlq-${each.value}"
    }
  )
}

# SQS Old Messages Alarm
resource "aws_cloudwatch_metric_alarm" "sqs_old_messages" {
  for_each = toset(var.sqs_queue_names)

  alarm_name          = "${var.project_name}-sqs-old-messages-${each.value}-${var.environment}"
  alarm_description   = "Alert when old messages are in queue ${each.value}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = var.alarm_period_seconds
  statistic           = "Maximum"
  threshold           = var.sqs_old_message_threshold_minutes * 60
  alarm_actions       = [var.alarm_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = each.value
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-sqs-old-messages-${each.value}"
    }
  )
}

# SQS Queue Depth Alarm
resource "aws_cloudwatch_metric_alarm" "sqs_queue_depth" {
  for_each = toset(var.sqs_queue_names)

  alarm_name          = "${var.project_name}-sqs-queue-depth-${each.value}-${var.environment}"
  alarm_description   = "Alert when queue depth exceeds threshold for ${each.value}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.sqs_queue_depth_threshold
  alarm_actions       = [var.alarm_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = each.value
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-sqs-queue-depth-${each.value}"
    }
  )
}
