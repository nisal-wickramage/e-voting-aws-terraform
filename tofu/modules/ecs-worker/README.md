# ECS Worker Service Module

## Purpose

Creates a production-ready ECS microservice for consuming and processing messages from an SQS queue, with database write capabilities. Worker services run privately without load balancer exposure and are ideal for background processing, event handling, and data persistence tasks.

## Overview

This module provisions:
- **ECS Task Definition**: Fargate task configured for SQS message consumption
- **ECS Service**: Manages running tasks with auto-scaling based on CPU/memory
- **IAM Roles**: Task permissions for SQS access, database secrets, and logging
- **CloudWatch Logs**: Dedicated log group for service output
- **Auto-scaling**: CPU (70%) and memory (80%) target tracking
- **Alarms**: Monitor SQS queue depth and task health

## Architecture

```
SQS Queue
    ↓
ECS Service (worker)
    ├─ Task 1 (container: worker)
    ├─ Task 2 (container: worker)
    └─ Task N (auto-scaled based on metrics)
         ↓
    RDS PostgreSQL
         ├─ Stores processed data
         ├─ Updates records
         └─ Persists results
```

## Inputs

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `cluster_name` | string | ✅ | ECS cluster name |
| `cluster_arn` | string | ✅ | ECS cluster ARN |
| `service_name` | string | | Service name (default: worker) |
| `container_image` | string | ✅ | Container image URI |
| `container_port` | number | | Service port (default: 8000) |
| `container_memory` | number | | Memory in MB (default: 512) |
| `container_cpu` | number | | CPU units (default: 256 = 0.25 vCPU) |
| `desired_count` | number | | Initial task count (default: 2) |
| `ecs_security_group_ids` | list(string) | ✅ | Security groups for tasks |
| `ecs_subnet_ids` | list(string) | ✅ | Subnets for tasks |
| `ecs_task_execution_role_arn` | string | ✅ | Task execution IAM role |
| `sqs_queue_url` | string | ✅ | SQS queue URL to consume |
| `sqs_queue_arn` | string | ✅ | SQS queue ARN |
| `db_host` | string | ✅ | Database host |
| `db_port` | number | | Database port (default: 5432) |
| `db_name` | string | ✅ | Database name |
| `db_credentials_secret_arn` | string | ✅ | Secrets Manager secret ARN |
| `environment` | string | ✅ | dev/staging/prod |
| `project_name` | string | ✅ | Project name |
| `common_tags` | map(string) | | Common tags |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `service_name` | string | ECS service name |
| `service_arn` | string | ECS service ARN |
| `task_definition_arn` | string | Task definition ARN |
| `task_role_arn` | string | Task IAM role ARN |
| `cloudwatch_log_group_name` | string | CloudWatch log group name |
| `autoscaling_target_id` | string | Auto-scaling target ID |
| `desired_count` | number | Desired number of tasks |
| `max_capacity` | number | Maximum tasks for auto-scaling |

## Usage

```hcl
module "event_processor_worker" {
  source = "./modules/ecs-worker"

  # ECS Cluster
  cluster_name = module.platform.ecs_cluster_name
  cluster_arn  = module.platform.ecs_cluster_arn

  # Service Configuration
  service_name = "event-processor"
  container_image = "${var.ecr_repo_url}/event-processor:latest"
  container_port  = 8000
  container_cpu   = 256
  container_memory = 512
  desired_count   = 2

  # Network
  ecs_security_group_ids      = [module.platform.ecs_security_group_id]
  ecs_subnet_ids              = module.network.private_subnet_ids_by_tier["app"]
  ecs_task_execution_role_arn = module.platform.ecs_task_execution_role_arn

  # SQS Queue
  sqs_queue_url = module.async_api.sqs_queue_url
  sqs_queue_arn = module.async_api.sqs_queue_arn

  # Database
  db_host                   = module.database.rds_address
  db_port                   = module.database.rds_port
  db_name                   = "evoting"
  db_credentials_secret_arn = module.ecs_migrations.db_credentials_secret_arn

  # Environment
  environment  = "dev"
  project_name = "e-voting"
}
```

## Service Implementation

Container must implement:
1. **Health Check Endpoint**: `GET /health` → 200 OK
2. **SQS Message Processing**: 
   - Read from `$SQS_QUEUE_URL` environment variable
   - Parse and process messages
   - Write results to database using `$DB_*` variables
   - Delete on success: `aws sqs delete-message`
   - Auto-retry on failure (message reprocessed after visibility timeout)
3. **Database Connection**:
   - Use `$DB_HOST`, `$DB_PORT`, `$DB_NAME`, `$DB_PASSWORD` (from Secrets Manager)
   - Connect and perform CRUD operations
   - Handle connection pooling for performance

### Example Python Implementation

```python
import boto3
import json
import os
import psycopg2
from psycopg2.pool import SimpleConnectionPool

sqs = boto3.client('sqs')
QUEUE_URL = os.getenv('SQS_QUEUE_URL')

# Database connection pool
conn_pool = SimpleConnectionPool(
    minconn=1,
    maxconn=5,
    host=os.getenv('DB_HOST'),
    database=os.getenv('DB_NAME'),
    user=os.getenv('DB_USERNAME'),
    password=os.getenv('DB_PASSWORD')
)

def process_message(message):
    """Process single SQS message and write to database"""
    try:
        body = json.loads(message['Body'])
        conn = conn_pool.getconn()
        cursor = conn.cursor()
        
        # Process request - example: voting submission
        request_id = body.get('request_id')
        vote_data = body.get('data')
        
        # Write to database
        cursor.execute(
            """
            INSERT INTO votes (request_id, data, status, created_at)
            VALUES (%s, %s, 'processed', NOW())
            ON CONFLICT (request_id) DO UPDATE SET status='processed'
            """,
            (request_id, json.dumps(vote_data))
        )
        conn.commit()
        
        # Delete from queue on success
        sqs.delete_message(
            QueueUrl=QUEUE_URL,
            ReceiptHandle=message['ReceiptHandle']
        )
        
        conn_pool.putconn(conn)
        print(f"Processed message: {request_id}")
        
    except Exception as e:
        print(f"Error processing message: {e}")
        # Message visibility will expire and be retried

def poll_queue():
    """Continuously poll SQS queue"""
    while True:
        response = sqs.receive_message(
            QueueUrl=QUEUE_URL,
            MaxNumberOfMessages=10,
            WaitTimeSeconds=20
        )
        
        for message in response.get('Messages', []):
            process_message(message)
```

## Auto-scaling Behavior

| Metric | Target | Min Tasks | Max Tasks |
|--------|--------|-----------|-----------|
| CPU Utilization | 70% | `desired_count` | 4 (dev), 10 (prod) |
| Memory Utilization | 80% | `desired_count` | 4 (dev), 10 (prod) |

**Example**: If desired_count=2:
- **Scale Up**: When avg CPU > 70% for 1 minute → Add tasks
- **Scale Down**: When avg CPU < 70% for 5 minutes → Remove tasks
- **Max**: Cannot exceed 4 (dev) or 10 (prod) tasks

## Monitoring & Alarms

### CloudWatch Metrics
- **ApproximateNumberOfMessagesVisible**: Messages waiting in queue
- **ECS RunningCount**: Number of running tasks
- **ECS CPUUtilization**: CPU usage percentage
- **ECS MemoryUtilization**: Memory usage percentage

### Alarms Created
1. **Queue Depth High**: > 100 messages waiting
2. **Task Count Low**: Running tasks < desired count

### View Logs
```bash
# Stream service logs
aws logs tail /ecs/e-voting-worker --follow

# Search for errors
aws logs filter-log-events \
  --log-group-name /ecs/e-voting-worker \
  --filter-pattern "ERROR"

# Tail last N lines
aws logs tail /ecs/e-voting-worker --follow --max-items 50
```

## Troubleshooting

**Tasks not starting**:
- Check security group allows RDS access (port 5432)
- Verify IAM task role has database secrets access
- Check container image available in ECR
- Review CloudWatch logs for startup errors

**High queue depth**:
- Increase `desired_count` to add more workers
- Check task logs for processing errors
- Verify database is accessible and not slow
- Monitor database connection pool exhaustion

**Database connection failures**:
- Ensure security groups allow task → RDS (5432)
- Verify Secrets Manager secret is accessible
- Check database credentials are correct
- Monitor RDS CPU/memory for capacity issues

**Health check failing**:
- Ensure `/health` endpoint returns 200 OK
- Check container port matches `container_port`
- Verify application is listening on correct port
- Review startup logs for initialization errors

**Message processing stuck**:
- Check visibility timeout (default: 300s)
- Review CloudWatch logs for exceptions
- Monitor database for locks/slow queries
- Verify container has database connection permissions

## Cost Optimization

- **Dev**: 2 × t3.small (256 CPU, 512 MB) = ~$14/month
- **Staging**: 4 × t3.small = ~$28/month
- **Prod**: 4-10 × t3.small = $28-70/month

**Tips**:
- Use `desired_count=1` for dev if cost is critical
- Right-size CPU/memory based on workload profiling
- Monitor auto-scaling to detect over-provisioning
- Use CloudWatch logs retention policies to reduce storage costs

## Differences from Async API Module

| Aspect | Async API | Worker |
|--------|-----------|--------|
| **Purpose** | Queue incoming requests | Process queued messages |
| **Load Balancer** | Yes (ALB target group) | No (private only) |
| **Database Access** | None | Full read/write |
| **SQS Role** | Producer | Consumer |
| **Visibility** | Public-facing | Backend processing |

## Future Enhancements

- [ ] Circuit breaker pattern for database failures
- [ ] Dead-letter queue processor for failed messages
- [ ] Custom CloudWatch metrics for business events
- [ ] Message encryption in transit
- [ ] Distributed tracing with X-Ray
- [ ] Graceful shutdown with message requeue
- [ ] Database transaction rollback on failure
