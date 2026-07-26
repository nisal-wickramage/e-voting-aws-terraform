# ECS Async API Service with SQS Queue

# SQS Queue for async requests
resource "aws_sqs_queue" "requests" {
  name                      = "${var.project_name}-${var.sqs_queue_name}"
  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds  = var.sqs_message_retention
  
  # Dead Letter Queue for failed messages
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-async-api-queue"
    }
  )
}

# Dead Letter Queue for failed async requests
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-${var.sqs_queue_name}-dlq"
  message_retention_seconds = var.sqs_message_retention

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-async-api-dlq"
    }
  )
}

# IAM role for async API task (task role - for accessing resources)
resource "aws_iam_role" "task_role" {
  name = "${var.project_name}-${var.service_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# IAM policy for task role (SQS and logs)
resource "aws_iam_role_policy" "task_policy" {
  name   = "${var.project_name}-${var.service_name}-task-policy"
  role   = aws_iam_role.task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = [
          aws_sqs_queue.requests.arn,
          aws_sqs_queue.dlq.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# CloudWatch log group for async API service
resource "aws_cloudwatch_log_group" "service_logs" {
  name              = "/ecs/${var.project_name}-${var.service_name}"
  retention_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.service_name}-logs"
    }
  )
}

# ECS Task Definition for async API service
resource "aws_ecs_task_definition" "service" {
  family                   = "${var.project_name}-${var.service_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = aws_iam_role.task_role.arn

  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      # Environment variables
      environment = [
        {
          name  = "SERVICE_NAME"
          value = var.service_name
        },
        {
          name  = "SQS_QUEUE_URL"
          value = aws_sqs_queue.requests.url
        },
        {
          name  = "SQS_QUEUE_ARN"
          value = aws_sqs_queue.requests.arn
        },
        {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      ]

      # Health check
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      # Logging to CloudWatch
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.service_logs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.service_name}-task"
    }
  )
}

# ECS Service
resource "aws_ecs_service" "service" {
  name            = "${var.project_name}-${var.service_name}"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.ecs_subnet_ids
    security_groups  = var.ecs_security_group_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  depends_on = [
    aws_ecs_task_definition.service
  ]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.service_name}"
    }
  )
}

# Auto-scaling target for the service
resource "aws_appautoscaling_target" "service_autoscaling" {
  max_capacity       = var.environment == "prod" ? 10 : 4
  min_capacity       = var.desired_count
  resource_id        = "service/${split("/", var.cluster_arn)[1]}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto-scaling policy - CPU
resource "aws_appautoscaling_policy" "service_cpu_autoscaling" {
  name               = "${var.project_name}-${var.service_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service_autoscaling.resource_id
  scalable_dimension = aws_appautoscaling_target.service_autoscaling.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_autoscaling.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Auto-scaling policy - Memory
resource "aws_appautoscaling_policy" "service_memory_autoscaling" {
  name               = "${var.project_name}-${var.service_name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service_autoscaling.resource_id
  scalable_dimension = aws_appautoscaling_target.service_autoscaling.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_autoscaling.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80.0
  }
}

# CloudWatch alarm for SQS queue depth (messages waiting)
resource "aws_cloudwatch_metric_alarm" "sqs_queue_depth" {
  alarm_name          = "${var.project_name}-${var.service_name}-queue-depth-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "Alert when SQS queue has >100 messages waiting"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.requests.name
  }
}

# CloudWatch alarm for DLQ depth (failed messages)
resource "aws_cloudwatch_metric_alarm" "dlq_depth" {
  alarm_name          = "${var.project_name}-${var.service_name}-dlq-depth-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "Alert when DLQ has >5 failed messages"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }
}

# Data sources for current AWS account/region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
