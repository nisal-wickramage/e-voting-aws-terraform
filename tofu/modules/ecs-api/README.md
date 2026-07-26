# ECS API Service Module

## Purpose

Creates a production-ready ECS microservice for API endpoints with ALB integration and direct database access. API services run in private subnets but are exposed through a load balancer listener, making them ideal for synchronous HTTP endpoints, REST APIs, and request-response workflows.

## Overview

This module provisions:
- **Secrets Manager**: Stores database credentials with rotation support
- **ECS Task Definition**: Fargate task with database credentials injection
- **ECS Service**: Manages running API tasks with ALB integration
- **ALB Listener Rule**: Routes HTTP traffic to the service
- **IAM Roles**: Task permissions for secrets and logging
- **CloudWatch Logs**: Dedicated log group for service output
- **Auto-scaling**: CPU (70%) and memory (80%) target tracking
- **Alarms**: Monitor task health and ALB target status

## Architecture

```
Public ALB (HTTPS 443 / HTTP 80)
    ↓
ALB Listener Rule (/api/*)
    ↓
ECS Service (api)
    ├─ Task 1 (container: api)
    ├─ Task 2 (container: api)
    └─ Task N (auto-scaled based on metrics)
         ↓
    RDS PostgreSQL
         ├─ Reads data
         ├─ Writes results
         └─ Query database
```

## Inputs

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `cluster_name` | string | ✅ | ECS cluster name |
| `cluster_arn` | string | ✅ | ECS cluster ARN |
| `service_name` | string | | Service name (default: api) |
| `container_image` | string | ✅ | Container image URI |
| `container_port` | number | | Service port (default: 8000) |
| `container_memory` | number | | Memory in MB (default: 512) |
| `container_cpu` | number | | CPU units (default: 256 = 0.25 vCPU) |
| `desired_count` | number | | Initial task count (default: 2) |
| `ecs_security_group_ids` | list(string) | ✅ | Security groups for tasks |
| `ecs_subnet_ids` | list(string) | ✅ | Subnets for tasks |
| `ecs_task_execution_role_arn` | string | ✅ | Task execution IAM role |
| `alb_target_group_arn` | string | ✅ | ALB target group for service |
| `alb_listener_arn` | string | ✅ | ALB listener for rule creation |
| `listener_rule_path_pattern` | list(string) | | Path pattern (default: ["/api/*"]) |
| `listener_rule_priority` | number | | Rule priority (default: 100) |
| `db_host` | string | ✅ | Database host |
| `db_port` | number | | Database port (default: 5432) |
| `db_name` | string | ✅ | Database name |
| `db_username` | string | | Database username (default: postgres) |
| `db_password` | string | ✅ | Database password (sensitive) |
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
| `db_credentials_secret_arn` | string | Secrets Manager secret ARN |
| `db_credentials_secret_name` | string | Secrets Manager secret name |
| `autoscaling_target_id` | string | Auto-scaling target ID |
| `listener_rule_arn` | string | ALB listener rule ARN |
| `desired_count` | number | Desired number of tasks |
| `max_capacity` | number | Maximum tasks for auto-scaling |

## Usage

```hcl
module "voting_api" {
  source = "./modules/ecs-api"

  # ECS Cluster
  cluster_name = module.platform.ecs_cluster_name
  cluster_arn  = module.platform.ecs_cluster_arn

  # Service Configuration
  service_name = "voting-api"
  container_image = "${var.ecr_repo_url}/voting-api:latest"
  container_port  = 8000
  container_cpu   = 256
  container_memory = 512
  desired_count   = 2

  # Network
  ecs_security_group_ids      = [module.platform.ecs_security_group_id]
  ecs_subnet_ids              = module.network.private_subnet_ids_by_tier["app"]
  ecs_task_execution_role_arn = module.platform.ecs_task_execution_role_arn

  # ALB
  alb_target_group_arn = module.platform.api_target_group_arn
  alb_listener_arn     = module.platform.alb_listener_arn
  listener_rule_path_pattern = ["/api/vote/*", "/api/results/*"]
  listener_rule_priority = 100

  # Database
  db_host     = module.database.rds_address
  db_port     = module.database.rds_port
  db_name     = "evoting"
  db_username = "api_user"
  db_password = random_password.api_db_password.result

  # Environment
  environment  = "dev"
  project_name = "e-voting"
}
```

## Service Implementation

Container must implement:
1. **Health Check Endpoint**: `GET /health` → 200 OK
2. **API Endpoints**: REST endpoints (GET, POST, PUT, DELETE)
3. **Database Connection**:
   - Use `$DB_HOST`, `$DB_PORT`, `$DB_NAME`, `$DB_USERNAME`, `$DB_PASSWORD` (from Secrets Manager)
   - Connect and perform CRUD operations
   - Handle connection pooling for performance
   - Implement transaction support for data consistency

### Example Python Implementation

```python
from flask import Flask, jsonify, request
import psycopg2
from psycopg2.pool import SimpleConnectionPool
import os
import json

app = Flask(__name__)

# Database connection pool
conn_pool = SimpleConnectionPool(
    minconn=2,
    maxconn=10,
    host=os.getenv('DB_HOST'),
    database=os.getenv('DB_NAME'),
    user=os.getenv('DB_USERNAME'),
    password=os.getenv('DB_PASSWORD')
)

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    try:
        conn = conn_pool.getconn()
        cursor = conn.cursor()
        cursor.execute('SELECT 1')
        conn_pool.putconn(conn)
        return jsonify({"status": "healthy"}), 200
    except Exception as e:
        return jsonify({"status": "unhealthy", "error": str(e)}), 500

@app.route('/api/votes', methods=['POST'])
def submit_vote():
    """Submit a vote"""
    try:
        data = request.json
        conn = conn_pool.getconn()
        cursor = conn.cursor()
        
        cursor.execute(
            """
            INSERT INTO votes (user_id, option, created_at)
            VALUES (%s, %s, NOW())
            RETURNING id
            """,
            (data['user_id'], data['option'])
        )
        vote_id = cursor.fetchone()[0]
        conn.commit()
        
        conn_pool.putconn(conn)
        return jsonify({"vote_id": vote_id}), 201
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/results', methods=['GET'])
def get_results():
    """Get voting results"""
    try:
        conn = conn_pool.getconn()
        cursor = conn.cursor()
        
        cursor.execute(
            """
            SELECT option, COUNT(*) as count
            FROM votes
            GROUP BY option
            """
        )
        results = {row[0]: row[1] for row in cursor.fetchall()}
        
        conn_pool.putconn(conn)
        return jsonify(results), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=False)
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
- **ECS RunningCount**: Number of running tasks
- **ECS CPUUtilization**: CPU usage percentage
- **ECS MemoryUtilization**: Memory usage percentage
- **ALB UnHealthyHostCount**: Unhealthy targets
- **ALB TargetResponseTime**: API latency

### Alarms Created
1. **Task Count Low**: Running tasks < desired count
2. **Unhealthy Targets**: > 0 unhealthy targets in ALB

### View Logs
```bash
# Stream service logs
aws logs tail /ecs/e-voting-api --follow

# Search for errors
aws logs filter-log-events \
  --log-group-name /ecs/e-voting-api \
  --filter-pattern "ERROR"

# View specific request
aws logs filter-log-events \
  --log-group-name /ecs/e-voting-api \
  --filter-pattern "POST /api/votes"
```

## Database Secrets

Credentials are automatically created in Secrets Manager with the following structure:

```json
{
  "username": "postgres",
  "password": "random-generated-password",
  "engine": "postgres",
  "host": "e-voting-db.us-east-1.rds.amazonaws.com",
  "port": 5432,
  "dbname": "evoting"
}
```

Secrets are injected as environment variables:
- `DB_USERNAME` ← from secret
- `DB_PASSWORD` ← from secret
- `DB_HOST`, `DB_PORT`, `DB_NAME` ← from module variables

## Troubleshooting

**Tasks not starting**:
- Check security group allows RDS access (port 5432)
- Verify IAM task role has secrets access
- Check container image available in ECR
- Review CloudWatch logs for startup errors

**Health check failing**:
- Ensure `/health` endpoint returns 200 OK
- Check database connectivity in health check
- Verify container port matches `container_port`
- Review startup logs for initialization errors

**API latency**:
- Check database connection pool sizing (min/max connections)
- Monitor RDS CPU/memory for capacity issues
- Review slow query logs in RDS
- Check ALB target latency metrics

**High error rate**:
- Review CloudWatch logs for exceptions
- Check database for locked tables or deadlocks
- Verify application error handling
- Monitor database connection pool exhaustion

**Secrets not accessible**:
- Ensure IAM task role has `secretsmanager:GetSecretValue` permission
- Verify secret ARN is correct
- Check secret exists and is not deleted
- Ensure secret is in the same AWS account/region

## Cost Optimization

- **Dev**: 2 × t3.small (256 CPU, 512 MB) = ~$14/month
- **Staging**: 4 × t3.small = ~$28/month
- **Prod**: 4-10 × t3.small = $28-70/month

**Tips**:
- Use `desired_count=1` for dev if cost is critical
- Right-size CPU/memory based on load testing
- Monitor auto-scaling to detect over-provisioning
- Use CloudWatch logs retention policies to reduce storage costs

## Differences from Worker Module

| Aspect | API | Worker |
|--------|-----|--------|
| **Purpose** | HTTP endpoints | Background processing |
| **Load Balancer** | Yes (ALB listener) | No (private only) |
| **Database Access** | Full read/write | Full read/write |
| **SQS Role** | None | Consumer |
| **Visibility** | Public-facing via ALB | Backend processing |
| **Request/Response** | Synchronous | Asynchronous |

## Future Enhancements

- [ ] API Gateway for additional routing
- [ ] Request/response caching with CloudFront
- [ ] Rate limiting at ALB level
- [ ] API versioning support
- [ ] JWT/OAuth2 authentication
- [ ] Distributed tracing with X-Ray
- [ ] API metrics and analytics
- [ ] Canary deployments with CodeDeploy
