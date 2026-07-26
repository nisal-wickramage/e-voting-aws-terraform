# CloudWatch Log Group for RDS backup events
resource "aws_cloudwatch_log_group" "rds_backups" {
  name              = "/aws/rds/backups/${var.project_name}-${var.environment}"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-rds-backups"
    Environment = var.environment
    Module      = "disaster-recovery"
  })
}

# SNS Topic for backup notifications
resource "aws_sns_topic" "rds_backup_events" {
  name              = "${var.project_name}-${var.environment}-rds-backup-events"
  kms_master_key_id = var.enable_backup_encryption ? var.kms_key_id : null

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-rds-backup-events"
    Environment = var.environment
    Module      = "disaster-recovery"
  })
}

# CloudWatch Alarm: RDS Backup Failed
resource "aws_cloudwatch_metric_alarm" "rds_backup_failed" {
  count = var.enable_backup_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-rds-backup-failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "FailedSQLServerAgentJobsCount"
  namespace           = "AWS/RDS"
  period              = 3600
  statistic           = "Maximum"
  threshold           = var.backup_failure_threshold_count
  alarm_description   = "Alert when RDS backup fails"
  alarm_actions       = [aws_sns_topic.rds_backup_events.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = var.rds_cluster_id
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-rds-backup-failed"
    Environment = var.environment
  })
}

# CloudWatch Alarm: RDS Backup Storage
resource "aws_cloudwatch_metric_alarm" "rds_backup_storage" {
  count = var.enable_backup_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-rds-backup-storage-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "DBInstanceStorageUsed"
  namespace           = "AWS/RDS"
  period              = 3600
  statistic           = "Average"
  threshold           = 80000000000  # 80 GB in bytes
  alarm_description   = "Alert when RDS backup storage usage is high (>80GB)"
  alarm_actions       = [aws_sns_topic.rds_backup_events.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = var.rds_cluster_id
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-rds-backup-storage-high"
    Environment = var.environment
  })
}

# IAM Role for RDS backup automation (for future Lambda/automation)
resource "aws_iam_role" "rds_backup_automation" {
  count = var.enable_manual_snapshots ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-rds-backup-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-rds-backup-automation"
    Environment = var.environment
    Module      = "disaster-recovery"
  })
}

# IAM Policy for RDS backup operations
resource "aws_iam_role_policy" "rds_backup_automation_policy" {
  count = var.enable_manual_snapshots ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-rds-backup-"
  role        = aws_iam_role.rds_backup_automation[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:CreateDBClusterSnapshot",
          "rds:DescribeDBClusters",
          "rds:DescribeDBClusterSnapshots",
          "rds:DeleteDBClusterSnapshot"
        ]
        Resource = [
          "arn:aws:rds:*:*:cluster:${var.rds_cluster_id}",
          "arn:aws:rds:*:*:cluster-snapshot:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.rds_backup_events.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# EventBridge Rule for daily manual snapshots
resource "aws_cloudwatch_event_rule" "daily_rds_snapshot" {
  count = var.enable_manual_snapshots ? 1 : 0

  name                = "${var.project_name}-${var.environment}-daily-rds-snapshot"
  description         = "Trigger daily RDS cluster snapshot"
  schedule_expression = "cron(0 2 * * ? *)"  # Daily at 2 AM UTC

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-daily-rds-snapshot"
    Environment = var.environment
    Module      = "disaster-recovery"
  })
}

# EventBridge Target (Lambda would go here, but for now just publish to SNS)
resource "aws_cloudwatch_event_target" "daily_rds_snapshot_sns" {
  count = var.enable_manual_snapshots ? 1 : 0

  rule      = aws_cloudwatch_event_rule.daily_rds_snapshot[0].name
  target_id = "RDSSnapshotSNS"
  arn       = aws_sns_topic.rds_backup_events.arn

  input_transformer {
    input_paths = {
      time = "$.time"
    }
    input_template = jsonencode({
      Action      = "CreateDBClusterSnapshot"
      ClusterId   = var.rds_cluster_id
      SnapshotId  = "${var.project_name}-${var.environment}-snapshot-<time>"
      TriggeredAt = "<time>"
    })
  }
}

# SNS Topic Policy to allow EventBridge to publish
resource "aws_sns_topic_policy" "rds_backup_events_allow_eventbridge" {
  count = var.enable_manual_snapshots ? 1 : 0

  arn = aws_sns_topic.rds_backup_events.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = [
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.rds_backup_events.arn
      }
    ]
  })
}

# CloudWatch Dashboard for RDS Backup Monitoring
resource "aws_cloudwatch_dashboard" "rds_backups" {
  count = var.enable_backup_monitoring ? 1 : 0

  dashboard_name = "${var.project_name}-${var.environment}-rds-backups"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "DBInstanceStorageUsed", { stat = "Average", label = "Storage Used" }],
            [".", "DBInstanceFreeStorageSpace", { stat = "Average", label = "Free Storage" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "RDS Storage Usage"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", { stat = "Average" }],
            [".", "CPUUtilization", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "RDS Performance Metrics"
        }
      }
    ]
  })
}

# Data source for current AWS region
data "aws_region" "current" {}
