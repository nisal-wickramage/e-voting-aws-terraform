# ============================================================
# Dead-Letter Queue (Optional)
# ============================================================

resource "aws_sqs_queue" "dlq" {
  count = var.enable_dlq ? 1 : 0

  name                      = "${var.project_name}-${var.queue_name}-dlq"
  message_retention_seconds = var.message_retention_seconds

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.queue_name}-dlq"
    }
  )
}

# ============================================================
# Main Queue with DLQ Redrive Policy
# ============================================================

resource "aws_sqs_queue" "main" {
  name                       = "${var.project_name}-${var.queue_name}"
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds

  redrive_policy = var.enable_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = var.dlq_max_receive_count
  }) : null

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.queue_name}"
    }
  )
}
