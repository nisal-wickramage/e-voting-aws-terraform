# ECS Migration Task Definition

# IAM role for migration task (task role - for accessing resources)
resource "aws_iam_role" "migration_task_role" {
  name = "${var.project_name}-migration-task-role"

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

# IAM policy for migration task (access to Secrets Manager, CloudWatch, RDS)
resource "aws_iam_role_policy" "migration_task_policy" {
  name   = "${var.project_name}-migration-task-policy"
  role   = aws_iam_role.migration_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch log group for migration task
resource "aws_cloudwatch_log_group" "migration_logs" {
  name              = "/ecs/${var.project_name}-migrations"
  retention_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-migration-logs"
    }
  )
}

# AWS Secrets Manager - Store RDS credentials for migration task
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}-db-credentials"
  description             = "Database credentials for ${var.project_name}"
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-db-credentials"
    }
  )
}

# Store the actual secret value
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username            = var.db_username
    password            = var.db_password
    engine              = "postgres"
    host                = var.db_host
    port                = var.db_port
    dbname              = var.db_name
  })
}


# ECS Task Definition for database migrations
resource "aws_ecs_task_definition" "migrations" {
  family                   = var.task_family_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = aws_iam_role.migration_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "migrations"
      image     = var.container_image
      essential = true

      # Database connection environment variables
      environment = [
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
          name  = "DB_USERNAME"
          value = var.db_username
        },
        {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      ]

      # Secrets (sensitive data)
      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = aws_secretsmanager_secret.db_credentials.arn
        }
      ]

      # Logging to CloudWatch
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.migration_logs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      # Standard working directory for migrations
      workingDirectory = "/app"

      # Default command (override with `aws ecs run-task --overrides`)
      command = ["python", "-m", "alembic", "upgrade", "head"]
    }
  ])

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-migration-task"
    }
  )
}

# Data sources for current AWS account/region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
