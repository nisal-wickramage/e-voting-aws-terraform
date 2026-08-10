# ECS Service Module

Unified, composable ECS service module that combines functionality from `ecs-api` and `ecs-async-api`. This module handles:
- Container image management (ECR repository creation, optional)
- ECS task definition with flexible environment variables and secrets
- ECS service deployment
- ALB integration (optional)
- Custom IAM permissions
- Additional security groups attachment

## Key Features

- **Flexible Service Types**: Support both HTTP services (API) and queue-based services (async-api, worker) via configuration
- **Composable IAM Permissions**: Pass additional IAM policy statements for SQS, databases, or custom permissions
- **Optional ALB Integration**: Make load balancer configuration optional
- **Extra Security Groups**: Attach additional security groups beyond the base set
- **Flexible Environment Variables**: Pass arbitrary environment variables as a map
- **Secrets Management**: Inject secrets from AWS Secrets Manager as environment variables

## Usage Example: API Service

```hcl
module "ecs_api" {
  source = "../ecs-service"

  cluster_name                = dependency.cluster.outputs.ecs_cluster_name
  cluster_arn                 = dependency.cluster.outputs.ecs_cluster_arn
  service_name                = "api"
  container_image             = "account.dkr.ecr.region.amazonaws.com/project/api:latest"
  container_port              = 8000
  container_cpu               = 512
  container_memory            = 1024
  desired_count               = 2

  ecs_security_group_ids      = [dependency.cluster.outputs.ecs_security_group_id]
  ecs_subnet_ids              = dependency.network.outputs.private_subnet_ids_by_tier["app"]
  ecs_task_execution_role_arn = dependency.cluster.outputs.ecs_task_execution_role_arn

  # ALB Configuration
  alb_target_group_arn        = dependency.cluster.outputs.default_target_group_arn
  alb_listener_arn            = dependency.cdn_waf.outputs.alb_listener_arn
  listener_rule_path_pattern  = ["/api/*", "/voting/*"]
  listener_rule_priority      = 100

  # Environment variables
  environment_variables = {
    SERVICE_NAME = "api"
    LOG_LEVEL    = "info"
    DB_HOST      = dependency.database.outputs.rds_endpoint
    DB_PORT      = "5432"
    DB_NAME      = "e_voting"
  }

  # Secrets from Secrets Manager
  secrets_arns = {
    db_password = dependency.integration_secrets.outputs.secret_arn
  }

  project_name = "e-voting"
  environment  = "dev"

  tags = {
    Environment = "dev"
    ManagedBy   = "terragrunt"
  }
}
```

## Usage Example: Async API Service with SQS

```hcl
# Create SQS queue separately
module "async_queue" {
  source = "../sqs-queue"

  project_name = "e-voting"
  environment  = "dev"
  queue_name   = "async-api-requests"
}

# ECS Service with SQS permissions
module "ecs_async_api" {
  source = "../ecs-service"

  cluster_name                = dependency.cluster.outputs.ecs_cluster_name
  cluster_arn                 = dependency.cluster.outputs.ecs_cluster_arn
  service_name                = "async-api"
  container_image             = "account.dkr.ecr.region.amazonaws.com/project/async-api:latest"
  container_port              = 8001
  container_cpu               = 512
  container_memory            = 1024
  desired_count               = 2

  ecs_security_group_ids      = [dependency.cluster.outputs.ecs_security_group_id]
  extra_security_group_ids    = [aws_security_group.async_api.id]  # Custom SG for SQS access
  ecs_subnet_ids              = dependency.network.outputs.private_subnet_ids_by_tier["app"]
  ecs_task_execution_role_arn = dependency.cluster.outputs.ecs_task_execution_role_arn

  # ALB Configuration (optional)
  alb_target_group_arn        = dependency.cluster.outputs.default_target_group_arn
  listener_rule_path_pattern  = ["/async/*"]
  listener_rule_priority      = 101

  # Environment variables
  environment_variables = {
    SERVICE_NAME    = "async-api"
    SQS_QUEUE_URL   = module.async_queue.queue_url
    SQS_QUEUE_ARN   = module.async_queue.queue_arn
  }

  # Extra IAM permissions for SQS
  extra_iam_policy_statements = [
    {
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ChangeMessageVisibility"
      ]
      Resource = [
        module.async_queue.queue_arn,
        module.async_queue.dlq_arn
      ]
    }
  ]

  secrets_arns = {
    db_password = dependency.integration_secrets.outputs.secret_arn
  }

  project_name = "e-voting"
  environment  = "dev"
}
```

## Migration from Old Modules

### From `ecs-api`:
- No SQS queue to migrate
- Pass `environment_variables` instead of individual `db_*` variables
- ALB configuration remains similar

### From `ecs-async-api`:
- Create `sqs-queue` module separately
- Pass SQS ARN/URL via `environment_variables`
- Use `extra_iam_policy_statements` for SQS permissions
- Use `extra_security_group_ids` if custom security group needed for SQS

### From `ecs-worker`:
- Remove database credential handling from ECS module (handle in secrets module)
- Pass SQS queue details via `environment_variables`
- Use `extra_iam_policy_statements` for SQS + Database permissions

### From `ecs-migrations`:
- Keep task definition but can simplify
- Use `environment_variables` for configuration
- Use `secrets_arns` for database credentials

## Inputs

### Required
- `cluster_name` - ECS cluster name
- `cluster_arn` - ECS cluster ARN
- `service_name` - Service name (e.g., api, async-api)
- `container_image` - Container image URI
- `ecs_security_group_ids` - Base security groups
- `ecs_subnet_ids` - Subnets for task placement
- `ecs_task_execution_role_arn` - Task execution role
- `project_name` - Project name
- `environment` - Environment (dev/staging/prod)

### Optional
- `alb_target_group_arn` - ALB target group (for load balancer integration)
- `alb_listener_arn` - ALB listener (for load balancer integration)
- `listener_rule_path_pattern` - Path patterns for ALB rules
- `extra_security_group_ids` - Additional security groups
- `environment_variables` - Environment variables map
- `secrets_arns` - Secrets Manager ARNs map
- `extra_iam_policy_statements` - Custom IAM policy statements

## Outputs

- `service_arn` - ECS service ARN
- `service_name` - ECS service name
- `task_definition_arn` - Task definition ARN
- `task_role_arn` - Task IAM role ARN
- `log_group_name` - CloudWatch log group name
- `ecr_repository_url` - ECR repository URL (if created)
