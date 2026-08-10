output "queue_id" {
  value       = aws_sqs_queue.main.id
  description = "Queue ID"
}

output "queue_arn" {
  value       = aws_sqs_queue.main.arn
  description = "Queue ARN"
}

output "queue_url" {
  value       = aws_sqs_queue.main.url
  description = "Queue URL"
}

output "queue_name" {
  value       = aws_sqs_queue.main.name
  description = "Queue name"
}

output "dlq_id" {
  value       = try(aws_sqs_queue.dlq[0].id, "")
  description = "Dead-letter queue ID (if enabled)"
}

output "dlq_arn" {
  value       = try(aws_sqs_queue.dlq[0].arn, "")
  description = "Dead-letter queue ARN (if enabled)"
}

output "dlq_url" {
  value       = try(aws_sqs_queue.dlq[0].url, "")
  description = "Dead-letter queue URL (if enabled)"
}

output "dlq_name" {
  value       = try(aws_sqs_queue.dlq[0].name, "")
  description = "Dead-letter queue name (if enabled)"
}
