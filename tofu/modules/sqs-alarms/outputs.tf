output "sqs_dlq_message_alarms" {
  value = {
    for dlq_name, alarm in aws_cloudwatch_metric_alarm.sqs_dlq_messages :
    dlq_name => alarm.arn
  }
  description = "Map of SQS DLQ name to alarm ARN"
}

output "sqs_old_message_alarms" {
  value = {
    for queue_name, alarm in aws_cloudwatch_metric_alarm.sqs_old_messages :
    queue_name => alarm.arn
  }
  description = "Map of SQS queue name to old message alarm ARN"
}

output "sqs_queue_depth_alarms" {
  value = {
    for queue_name, alarm in aws_cloudwatch_metric_alarm.sqs_queue_depth :
    queue_name => alarm.arn
  }
  description = "Map of SQS queue name to queue depth alarm ARN"
}
