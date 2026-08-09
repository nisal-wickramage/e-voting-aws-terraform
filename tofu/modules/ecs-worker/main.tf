# ECS Worker Service with Database Integration

# IAM role for worker task (task role - for accessing resources)
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

# IAM policy for task role (SQS, database secrets, logs)
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
        Resource = var.sqs_queue_arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = concat(
          [var.db_credentials_secret_arn],
          values(var.secrets_arns)
        )
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

# CloudWatch log group for worker service
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

# Build secrets array for task definition
locals {
  additional_secrets = [
    for secret_name, secret_arn in var.secrets_arns : {
      name      = upper(replace(secret_name, "-", "_"))
      valueFrom = secret_arn
    }
  ]
}

# ECS Task Definition for worker service
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
          value = var.sqs_queue_url
        },
        {
          name  = "DB_HOST"
          value = var.db_host
        },
        {
          name  = "DB_PORT"
          value = tostring(var.db_port)
        },
        {
          name  = "DB_NAME"
          value = var.db_name
        },
        {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      ]

      # Secrets from Secrets Manager
      secrets = concat(
        [
          {
            name      = "DB_PASSWORD"
            valueFrom = var.db_credentials_secret_arn
          }
        ],
        local.additional_secrets
      )

      # CloudWatch logging
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.service_logs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      # Health check for container
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
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

# Get current AWS region
data "aws_region" "current" {}

# ECS Service for worker
resource "aws_ecs_service" "service" {
  name            = "${var.project_name}-${var.service_name}"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = var.ecs_security_group_ids
    subnets          = var.ecs_subnet_ids
    assign_public_ip = false
  }

  depends_on = [aws_iam_role_policy.task_policy]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.service_name}-service"
    }
  )
}

# Auto-scaling target for worker service
resource "aws_appautoscaling_target" "service_target" {
  max_capacity       = var.environment == "prod" ? 10 : 4
  min_capacity       = var.desired_count
  resource_id        = "service/${split("/", var.cluster_arn)[1]}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# CPU utilization auto-scaling policy
resource "aws_appautoscaling_policy" "service_cpu" {
  name               = "${var.project_name}-${var.service_name}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service_target.resource_id
  scalable_dimension = aws_appautoscaling_target.service_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value      = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Memory utilization auto-scaling policy
resource "aws_appautoscaling_policy" "service_memory" {
  name               = "${var.project_name}-${var.service_name}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service_target.resource_id
  scalable_dimension = aws_appautoscaling_target.service_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value      = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# CloudWatch alarm for SQS queue depth
resource "aws_cloudwatch_metric_alarm" "sqs_queue_depth" {
  alarm_name          = "${var.project_name}-${var.service_name}-sqs-queue-depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = "100"
  alarm_description   = "Alert when SQS queue has > 100 messages"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = split("/", var.sqs_queue_url)[4]
  }

  tags = var.common_tags
}

# CloudWatch alarm for task count
resource "aws_cloudwatch_metric_alarm" "service_task_count" {
  alarm_name          = "${var.project_name}-${var.service_name}-task-count"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RunningCount"
  namespace           = "ECS/ContainerInsights"
  period              = "60"
  statistic           = "Average"
  threshold           = var.desired_count
  alarm_description   = "Alert when running tasks < desired count"
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = split("/", var.cluster_arn)[1]
    ServiceName = aws_ecs_service.service.name
  }

  tags = var.common_tags
}

# ECR Repository for service container images
resource "aws_ecr_repository" "service" {
  count = var.enable_ecr ? 1 : 0

  name                 = "${var.project_name}-${var.service_name}"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.image_scan_on_push
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.service_name}"
    }
  )
}

# ECR Lifecycle Policy (retention)
resource "aws_ecr_lifecycle_policy" "service" {
  count = var.enable_ecr ? 1 : 0

  repository = aws_ecr_repository.service[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.ecr_retention_days} days of images"
        selection = {
          tagStatus     = "any"
          countType     = "sinceImagePushed"
          countUnit     = "days"
          countNumber   = var.ecr_retention_days
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
