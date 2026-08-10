# ECS Module Consolidation & Composability Guide

## Overview

We've refactored ECS modules to be more composable and flexible:

### **New Modules**
1. **ecs-service** - Unified ECS service module (replaces ecs-api, ecs-async-api)
2. **sqs-queue** - Standalone SQS queue module (extracted from ecs-async-api)

### **Key Improvements**
- ✅ Single flexible ECS service module for all service types
- ✅ Optional ALB integration (not forced)
- ✅ Support for custom IAM permissions (SQS, databases, etc.)
- ✅ Support for additional security groups
- ✅ Flexible environment variables and secrets
- ✅ SQS queues managed independently

---

## Migration Examples

### Example 1: Simple API Service

**Old (ecs-api):**
```hcl
module "api" {
  source = "../ecs-api"
  
  cluster_name = "e-voting-cluster"
  container_image = "nginx:latest"
  db_host = "rds.example.com"
  db_port = 5432
  db_name = "voting"
  db_username = "postgres"
  db_password = "secret"
  
  alb_target_group_arn = "arn:aws:elasticloadbalancing:..."
}
```

**New (ecs-service):**
```hcl
module "api" {
  source = "../ecs-service"
  
  cluster_name = "e-voting-cluster"
  cluster_arn = "arn:aws:ecs:..."
  service_name = "api"
  container_image = "nginx:latest"
  
  ecs_security_group_ids = [aws_security_group.ecs.id]
  ecs_subnet_ids = ["subnet-123", "subnet-456"]
  ecs_task_execution_role_arn = "arn:aws:iam:..."
  
  # Pass environment as map
  environment_variables = {
    DB_HOST = "rds.example.com"
    DB_PORT = "5432"
    DB_NAME = "voting"
  }
  
  # Pass secrets as map of ARNs
  secrets_arns = {
    db_password = "arn:aws:secretsmanager:..."
  }
  
  alb_target_group_arn = "arn:aws:elasticloadbalancing:..."
  alb_listener_arn = "arn:aws:elasticloadbalancing:..."
  listener_rule_path_pattern = ["/api/*"]
}
```

---

### Example 2: Async API with SQS

**Old (ecs-async-api):**
```hcl
module "async_api" {
  source = "../ecs-async-api"
  
  cluster_name = "e-voting-cluster"
  container_image = "worker:latest"
  sqs_queue_name = "async-requests"
  sqs_visibility_timeout = 300
  
  # SQS created inside module, hard to reuse
}
```

**New (ecs-service + sqs-queue):**
```hcl
# Create queue separately for reusability
module "async_queue" {
  source = "../sqs-queue"
  
  project_name = "e-voting"
  environment = "dev"
  queue_name = "async-requests"
  visibility_timeout_seconds = 300
}

# Use ecs-service with extra IAM permissions
module "async_api" {
  source = "../ecs-service"
  
  cluster_name = "e-voting-cluster"
  service_name = "async-api"
  container_image = "worker:latest"
  
  ecs_security_group_ids = [aws_security_group.ecs.id]
  ecs_subnet_ids = ["subnet-123", "subnet-456"]
  ecs_task_execution_role_arn = "arn:aws:iam:..."
  
  # Pass queue details via environment
  environment_variables = {
    SQS_QUEUE_URL = module.async_queue.queue_url
    SQS_QUEUE_ARN = module.async_queue.queue_arn
  }
  
  # Grant SQS permissions
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
  
  alb_target_group_arn = "arn:aws:elasticloadbalancing:..."
}
```

---

### Example 3: Service with Custom Security & Permissions

**Scenario**: Database + API Gateway + Custom VPC

```hcl
module "custom_service" {
  source = "../ecs-service"
  
  cluster_name = "e-voting-cluster"
  service_name = "custom-api"
  container_image = "custom-api:latest"
  
  ecs_security_group_ids = [aws_security_group.ecs.id]
  
  # Attach additional security groups for database access
  extra_security_group_ids = [aws_security_group.database_access.id]
  
  ecs_subnet_ids = ["subnet-123", "subnet-456"]
  ecs_task_execution_role_arn = "arn:aws:iam:..."
  
  environment_variables = {
    DB_HOST = "rds.example.com"
    EXTERNAL_API = "https://external-api.com"
  }
  
  secrets_arns = {
    db_password = "arn:aws:secretsmanager:..."
    api_key = "arn:aws:secretsmanager:..."
  }
  
  # Grant database + custom API permissions
  extra_iam_policy_statements = [
    {
      Effect = "Allow"
      Action = [
        "rds:DescribeDBInstances",
        "rds-db:connect"
      ]
      Resource = ["arn:aws:rds:..."]
    },
    {
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      Resource = ["arn:aws:s3:::my-bucket/*"]
    }
  ]
}
```

---

## Terragrunt Structure

Create separate Terragrunt configs for each component:

```
terragrunt/dev/
├── sqs-queue-async-api/
│   └── terragrunt.hcl      # SQS queue creation
├── ecs-service-api/
│   └── terragrunt.hcl      # API service
├── ecs-service-async-api/
│   └── terragrunt.hcl      # Async API service (depends on sqs-queue-async-api)
├── ecs-service-worker/
│   └── terragrunt.hcl      # Worker service
└── ecs-service-migrations/
    └── terragrunt.hcl      # Migrations (run-task only)
```

### Example Terragrunt Config for SQS

```hcl
# terragrunt/dev/sqs-queue-async-api/terragrunt.hcl

include "root" {
  path = "../../terragrunt.hcl"
}

terraform {
  source = "../../../tofu/modules/sqs-queue"
}

inputs = {
  project_name              = "e-voting"
  environment               = "dev"
  queue_name                = "async-api-requests"
  visibility_timeout_seconds = 300
  enable_dlq                = true
  dlq_max_receive_count     = 3

  common_tags = {
    Environment = "dev"
    Project     = "e-voting"
    ManagedBy   = "terragrunt"
  }
}
```

### Example Terragrunt Config for Async API Service

```hcl
# terragrunt/dev/ecs-service-async-api/terragrunt.hcl

include "root" {
  path = "../../terragrunt.hcl"
}

terraform {
  source = "../../../tofu/modules/ecs-service"
}

dependency "cluster" {
  config_path = "../cluster"
  mock_outputs = {
    ecs_cluster_arn = "arn:aws:ecs:..."
  }
}

dependency "network" {
  config_path = "../network"
  mock_outputs = {
    private_subnet_ids_by_tier = {
      app = ["subnet-123", "subnet-456"]
    }
  }
}

dependency "sqs" {
  config_path = "../sqs-queue-async-api"
  mock_outputs = {
    queue_url = "https://queue.amazonaws.com/..."
    queue_arn = "arn:aws:sqs:..."
    dlq_arn   = "arn:aws:sqs:..."
  }
}

locals {
  env = "dev"
  project_name = "e-voting"
}

inputs = {
  project_name = local.project_name
  environment  = local.env
  service_name = "async-api"
  
  cluster_name                = dependency.cluster.outputs.ecs_cluster_name
  cluster_arn                 = dependency.cluster.outputs.ecs_cluster_arn
  
  container_image             = "account.dkr.ecr.region.amazonaws.com/e-voting/async-api:latest"
  container_port              = 8001
  container_cpu               = 512
  container_memory            = 1024
  desired_count               = 2
  
  ecs_security_group_ids      = [dependency.cluster.outputs.ecs_security_group_id]
  ecs_subnet_ids              = dependency.network.outputs.private_subnet_ids_by_tier["app"]
  ecs_task_execution_role_arn = dependency.cluster.outputs.ecs_task_execution_role_arn
  
  alb_target_group_arn        = dependency.cluster.outputs.default_target_group_arn
  
  # Pass queue details to service
  environment_variables = {
    SERVICE_NAME    = "async-api"
    SQS_QUEUE_URL   = dependency.sqs.outputs.queue_url
    SQS_QUEUE_ARN   = dependency.sqs.outputs.queue_arn
    LOG_LEVEL       = "info"
  }
  
  # Grant SQS permissions
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
        dependency.sqs.outputs.queue_arn,
        dependency.sqs.outputs.dlq_arn
      ]
    }
  ]
  
  common_tags = {
    Environment = local.env
    Project     = local.project_name
    ManagedBy   = "terragrunt"
  }
}
```

---

## Next Steps

1. **Create Terragrunt configs** for new modules in `terragrunt/dev/`
2. **Test new modules** with `terragrunt plan/apply`
3. **Migrate existing services** one by one to new modules
4. **Deprecate old modules** after migration complete (ecs-api, ecs-async-api, ecs-worker, ecs-migrations)

---

## Benefits

✅ Single source of truth for ECS service configuration  
✅ Reusable SQS queues (not tied to ECS module)  
✅ Flexible IAM permissions (not hardcoded)  
✅ Support for any service type without module duplication  
✅ Easier to test and maintain  
✅ Clear composition pattern for complex services  
