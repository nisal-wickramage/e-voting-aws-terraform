# ============================================================
# Data Sources
# ============================================================

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ============================================================
# ECR Repository (Optional)
# ============================================================

resource "aws_ecr_repository" "service" {
  count = var.enable_ecr ? 1 : 0

  name = "${var.project_name}/${var.service_name}"
  image_tag_mutability       = var.image_tag_mutability
  image_scanning_configuration {
    scan_on_push = var.image_scan_on_push
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.service_name}-ecr"
    }
  )
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "service" {
  count = var.enable_ecr ? 1 : 0

  repository = aws_ecr_repository.service[0].name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images"
        selection = {
          tagStatus     = "untagged"
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

# ============================================================
# IAM Role for ECS Task
# ============================================================

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

# ============================================================
# IAM Policy for Task Role
# ============================================================

resource "aws_iam_role_policy" "task_policy" {
  name   = "${var.project_name}-${var.service_name}-task-policy"
  role   = aws_iam_role.task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect = "Allow"
          Action = [
            "secretsmanager:GetSecretValue"
          ]
          Resource = values(var.secrets_arns)
        },
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "arn:aws:logs:*:*:*"
        }
      ],
      var.extra_iam_policy_statements
    )
  })
}

# ============================================================
# CloudWatch Log Group
# ============================================================

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

# ============================================================
# Build Secrets Array for Task Definition
# ============================================================

locals {
  secrets_array = [
    for secret_name, secret_arn in var.secrets_arns : {
      name      = upper(replace(secret_name, "-", "_"))
      valueFrom = secret_arn
    }
  ]
}

# ============================================================
# ECS Task Definition
# ============================================================

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

      # Environment variables (merged with user-provided ones)
      environment = [
        for key, value in var.environment_variables : {
          name  = key
          value = value
        }
      ]

      # Secrets from Secrets Manager
      secrets = local.secrets_array

      # CloudWatch logging
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

# ============================================================
# ECS Service
# ============================================================

resource "aws_ecs_service" "service" {
  name            = "${var.project_name}-${var.service_name}"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = concat(var.ecs_security_group_ids, var.extra_security_group_ids)
    subnets          = var.ecs_subnet_ids
    assign_public_ip = false
  }

  # ALB configuration (optional)
  dynamic "load_balancer" {
    for_each = var.alb_target_group_arn != "" ? [1] : []
    content {
      target_group_arn = var.alb_target_group_arn
      container_name   = var.service_name
      container_port   = var.container_port
    }
  }

  depends_on = [aws_iam_role_policy.task_policy]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.service_name}"
    }
  )
}

# ============================================================
# ALB Listener Rule (Optional)
# ============================================================

resource "aws_lb_listener_rule" "service" {
  count = var.alb_listener_arn != "" && length(var.listener_rule_path_pattern) > 0 ? 1 : 0

  listener_arn       = var.alb_listener_arn
  priority           = var.listener_rule_priority
  action {
    type             = "forward"
    target_group_arn = var.alb_target_group_arn
  }

  condition {
    path_pattern {
      values = var.listener_rule_path_pattern
    }
  }
}
