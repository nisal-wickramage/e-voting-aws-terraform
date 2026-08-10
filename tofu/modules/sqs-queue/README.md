# SQS Queue Module

Standalone SQS queue module that creates main queue with optional dead-letter queue. This module enables composable queue architecture - create queues independently and pass details to services.

## Key Features

- **Main Queue & DLQ**: Creates both main and dead-letter queue
- **Configurable Timeouts**: Visibility timeout and message retention
- **Flexible DLQ**: Optional dead-letter queue with configurable receive count

## Usage Example

```hcl
module "async_queue" {
  source = "../sqs-queue"

  project_name              = "e-voting"
  environment               = "dev"
  queue_name                = "async-api-requests"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600  # 14 days
  enable_dlq                = true
  dlq_max_receive_count     = 3

  common_tags = {
    Environment = "dev"
    ManagedBy   = "terragrunt"
  }
}
```

## Outputs

- `queue_url` - Main queue URL
- `queue_arn` - Main queue ARN
- `dlq_url` - Dead-letter queue URL
- `dlq_arn` - Dead-letter queue ARN

## Integration with ECS Service

Pass queue details to `ecs-service` module:

```hcl
module "async_api" {
  source = "../ecs-service"
  
  # ... other config ...
  
  environment_variables = {
    SQS_QUEUE_URL = module.async_queue.queue_url
    SQS_QUEUE_ARN = module.async_queue.queue_arn
  }

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
}
```

## Inputs

### Required
- `project_name` - Project name
- `environment` - Environment (dev/staging/prod)
- `queue_name` - Queue name

### Optional
- `visibility_timeout_seconds` - Visibility timeout (default: 300)
- `message_retention_seconds` - Message retention (default: 1209600 = 14 days)
- `enable_dlq` - Create DLQ (default: true)
- `dlq_max_receive_count` - Max receives before DLQ (default: 3)
