# ECS Async API Service Module

## Purpose

Creates a production-ready ECS microservice for async request processing with SQS queue integration, auto-scaling, and built-in dead-letter queue handling for failed messages.

## Overview

This module provisions:
- **SQS Queue**: For incoming async requests with DLQ for failed messages
- **ECS Task Definition**: Fargate task configured for SQS message processing
- **ECS Service**: Manages running tasks with auto-scaling based on CPU/memory
- **IAM Roles**: Task permissions for SQS access and logging
- **CloudWatch Logs**: Dedicated log group for service output
- **Auto-scaling**: CPU (70%) and memory (80%) target tracking
- **Alarms**: Monitor SQS queue depth and DLQ for issues

## Architecture

```
API Gateway / ALB
    ↓
ECS Service (async-api)
    ├─ Task 1 (container: async-api)
    ├─ Task 2 (container: async-api)
    └─ Task N (auto-scaled based on metrics)
         ↓
    SQS Queue (async-api-requests)
         ├─ Processes messages
         ├─ Max retry: 3
         └─ Failed → DLQ (async-api-requests-dlq)
```

## Inputs

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `cluster_name` | string | ✅ | ECS cluster name |
| `cluster_arn` | string | ✅ | ECS cluster ARN |
| `service_name` | string | | Service name (default: async-api) |
| `container_image` | string | ✅ | Container image URI |
| `container_port` | number | | Service port (default: 8000) |
| `container_memory` | number | | Memory in MB (default: 512) |
| `container_cpu` | number | | CPU units (default: 256 = 0.25 vCPU) |
| `desired_count` | number | | Initial task count (default: 2) |
| `ecs_security_group_ids` | list(string) | ✅ | Security groups for tasks |
| `ecs_subnet_ids` | list(string) | ✅ | Subnets for tasks |
| `ecs_task_execution_role_arn` | string | ✅ | Task execution IAM role |
| `alb_target_group_arn` | string | ✅ | ALB target group for service |
| `sqs_queue_name` | string | | Queue name (default: async-api-requests) |
| `sqs_visibility_timeout` | number | | Visibility timeout in seconds (default: 300) |
| `sqs_message_retention` | number | | Message retention in seconds (default: 345600 = 4 days) |
| `environment` | string | ✅ | dev/staging/prod |
| `project_name` | string | ✅ | Project name |
| `common_tags` | map(string) | | Common tags |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `service_name` | string | ECS service name |
| `service_arn` | string | ECS service ARN |
| `task_definition_arn` | string | Task definition ARN |
| `sqs_queue_url` | string | SQS queue URL |
| `sqs_queue_arn` | string | SQS queue ARN |
| `sqs_queue_name` | string | SQS queue name |
| `sqs_dlq_url` | string | Dead-letter queue URL |
| `cloudwatch_log_group_name` | string | CloudWatch log group name |
| `task_role_arn` | string | Task IAM role ARN |
| `autoscaling_target_id` | string | Auto-scaling target ID |

## Usage

```hcl
module "ecs_async_api" {
  source = "./modules/ecs-async-api"

  # ECS Cluster
  cluster_name = module.platform.ecs_cluster_name
  cluster_arn  = module.platform.ecs_cluster_arn

  # Service Configuration
  service_name = "async-api"
  container_image = "${var.ecr_repo_url}:latest"
  container_port  = 8000
  container_cpu   = 256
  container_memory = 512
  desired_count   = 2

  # Network
  ecs_security_group_ids      = [module.platform.ecs_security_group_id]
  ecs_subnet_ids              = module.network.private_subnet_ids_by_tier["app"]
  ecs_task_execution_role_arn = module.platform.ecs_task_execution_role_arn
  alb_target_group_arn        = module.platform.default_target_group_arn

  # SQS
  sqs_queue_name           = "async-api-requests"
  sqs_visibility_timeout   = 300
  sqs_message_retention    = 345600

  # Environment
  environment  = "dev"
  project_name = "e-voting"
}
```

## SQS Queue Management

### Send Request
```bash
# Send message to queue
aws sqs send-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789/e-voting-async-api-requests \
  --message-body '{"request_id": "123", "data": {...}}'
```

### Monitor Queue
```bash
# Get queue attributes
aws sqs get-queue-attributes \
  --queue-url <QUEUE_URL> \
  --attribute-names All

# Receive messages (long polling)
aws sqs receive-message \
  --queue-url <QUEUE_URL> \
  --max-number-of-messages 10 \
  --wait-time-seconds 20
```

### Check Dead-Letter Queue
```bash
# List DLQ messages
aws sqs receive-message \
  --queue-url <DLQ_URL> \
  --max-number-of-messages 10
```

## Service Implementation

Container must implement:
1. **Health Check Endpoint**: `GET /health` → 200 OK
2. **SQS Message Processing**: 
   - Read from `$SQS_QUEUE_URL` environment variable
   - Process messages
   - Delete on success: `aws sqs delete-message`
   - Auto-retry on failure (3 times before DLQ)

### Example Python Implementation

```python
import boto3
import json
import os

sqs = boto3.client('sqs')
QUEUE_URL = os.getenv('SQS_QUEUE_URL')

def process_message(message):
    """Process single SQS message"""
    body = json.loads(message['Body'])
    
    # Process the request (e.g., call another service, compute something)
    request_id = body.get('request_id')
    result = process_request(body)
    
    # Store result or call downstream service
    # Example: call API to store result
    # result_api.store_result(request_id, result)
    
    # Delete from queue on success
    sqs.delete_message(
        QueueUrl=QUEUE_URL,
        ReceiptHandle=message['ReceiptHandle']
    )

def poll_queue():
    """Continuously poll SQS queue"""
    while True:
        response = sqs.receive_message(
            QueueUrl=QUEUE_URL,
            MaxNumberOfMessages=10,
            WaitTimeSeconds=20
        )
        
        for message in response.get('Messages', []):
            try:
                process_message(message)
            except Exception as e:
                # Message will be retried (Redrive policy: max 3 times)
                print(f"Error processing: {e}")
```

## Auto-scaling Behavior

| Metric | Target | Min Tasks | Max Tasks |
|--------|--------|-----------|-----------|
| CPU Utilization | 70% | `desired_count` | 4 (dev), 10 (prod) |
| Memory Utilization | 80% | `desired_count` | 4 (dev), 10 (prod) |

Example: If desired_count=2:
- **Scale Up**: When avg CPU > 70% → Add tasks
- **Scale Down**: When avg CPU < 70% for 5 minutes → Remove tasks
- **Max**: Cannot exceed 4 (dev) or 10 (prod) tasks

## Monitoring & Alarms

### CloudWatch Metrics
- **ApproximateNumberOfMessagesVisible**: Messages in queue
- **ApproximateAgeOfOldestMessage**: Age of oldest unprocessed message
- **NumberOfMessagesSent**: Total messages sent
- **NumberOfMessagesReceived**: Total messages processed
- **NumberOfMessagesDeleted**: Successfully processed

### Alarms Created
1. **Queue Depth High**: > 100 messages waiting
2. **DLQ Has Messages**: > 5 failed messages

### View Logs
```bash
# Stream service logs
aws logs tail /ecs/e-voting-async-api --follow

# Search for errors
aws logs filter-log-events \
  --log-group-name /ecs/e-voting-async-api \
  --filter-pattern "ERROR"
```

## Troubleshooting

**Tasks not starting**:
- Check security group allows SQS access
- Verify IAM task role has SQS permissions
- Check container image available in ECR

**High queue depth**:
- Increase desired_count
- Check task logs for processing errors
- Verify database is accessible

**Messages in DLQ**:
- Check CloudWatch logs for error details
- Fix bug and redeploy
- Manually reprocess DLQ messages if needed

**Health check failing**:
- Ensure `/health` endpoint returns 200 OK
- Check container port matches `container_port`
- Verify application is listening on correct port

## Cost Optimization

- **Dev**: 2 × t3.small (256 CPU, 512 MB) = ~$14/month + SQS (~$0.40/month)
- **Staging**: 4 × t3.small = ~$28/month + SQS
- **Prod**: 4-10 × t3.small = $28-70/month + SQS + DLQ monitoring

## Future Enhancements

- [ ] Lambda dead-letter queue processor
- [ ] Message encryption in transit
- [ ] Custom metrics for business events
- [ ] Integration with SNS for notifications
- [ ] Message replay from DLQ
- [ ] Circuit breaker for database failures
