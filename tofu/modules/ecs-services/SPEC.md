# ECS Services Module Specification

## Purpose
Deploy microservices as ECS Fargate tasks with ECR repositories, task definitions, and ALB routing rules, enabling independent service deployment and scaling.

## Inputs

| Variable | Type | Description | Required | Example |
|----------|------|-------------|----------|---------|
| `vpc_id` | string | VPC ID from network module | Yes | (from dependency) |
| `ecs_cluster_arn` | string | ECS cluster ARN from platform | Yes | (from dependency) |
| `ecs_cluster_name` | string | ECS cluster name from platform | Yes | (from dependency) |
| `alb_arn` | string | ALB ARN from platform | Yes | (from dependency) |
| `alb_target_group_arn` | string | Default target group ARN from platform | Yes | (from dependency) |
| `ecs_security_group_id` | string | ECS security group ID from platform | Yes | (from dependency) |
| `db_instance_endpoint` | string | RDS endpoint from database | Yes | (from dependency) |
| `private_subnet_ids` | list(string) | Private subnet IDs from network | Yes | (from dependency) |
| `vpc_endpoint_ids` | map(string) | VPC endpoint IDs from network | Yes | (from dependency) |
| `services` | map(object) | Service definitions | Yes | See structure below |
| `container_insights_enabled` | bool | Enable Container Insights | No | `true` |
| `task_cpu` | number | CPU units per task | No | `256` |
| `task_memory` | number | Memory per task (MB) | No | `512` |
| `container_port` | number | Container port | Yes | `8080` |
| `health_check_path` | string | ALB health check path | Yes | `"/health"` |
| `desired_count` | number | Desired number of tasks | No | `2` |
| `max_capacity` | number | Maximum tasks (autoscaling) | No | `10` |
| `min_capacity` | number | Minimum tasks (autoscaling) | No | `2` |
| `environment` | string | Environment name (dev/staging/prod) | Yes | `"dev"` |
| `project_name` | string | Project name for resource tagging | Yes | `"e-voting"` |
| `docker_image_tag` | string | Docker image tag or digest | Yes | `"latest"` |

### Services Map Structure
```hcl
services = {
  "voting-service" = {
    port           = 8080
    cpu            = 256
    memory         = 512
    desired_count  = 2
    image_uri      = "MY_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/voting-service:latest"
    container_name = "voting-app"
    env_vars = {
      DB_HOST = "rds-endpoint"
      LOG_LEVEL = "INFO"
    }
    secrets = {
      DB_PASSWORD = "arn:aws:secretsmanager:..."
    }
  }
  # Add more services as needed
}
```

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `ecr_repository_urls` | map(string) | ECR repository URLs per service |
| `ecs_service_arns` | map(string) | ECS service ARNs per service |
| `ecs_task_definition_arns` | map(string) | Task definition ARNs per service |
| `cloudwatch_log_group_names` | map(string) | CloudWatch log group names per service |
| `target_group_arns` | map(string) | ALB target group ARNs per service |
| `ecr_repository_names` | map(string) | ECR repository names per service |
| `service_endpoints` | map(string) | Service endpoints (via ALB DNS) |

## Resources

- **aws_ecr_repository** (per service): Private Docker image repository
- **aws_ecs_task_definition** (per service): Task definition with container config
- **aws_ecs_service** (per service): ECS service managing tasks
- **aws_lb_target_group** (per service): ALB target group for service
- **aws_lb_listener_rule** (per service): ALB routing rule (path-based or hostname)
- **aws_cloudwatch_log_group** (per service): Container logs
- **aws_iam_role** (per service): Task execution role (ECR pull, Secrets Manager)
- **aws_iam_role** (per service): Task role (application permissions)
- **aws_appautoscaling_target**: Auto-scaling target for tasks
- **aws_appautoscaling_policy**: CPU/memory-based scaling policies

## Security

### IAM Roles
- **Task Execution Role**: Allow ECR pull, Secrets Manager read, CloudWatch logs
- **Task Role**: Application-specific permissions (e.g., S3 access for voting data)

### Network
- Tasks run in private subnets only
- Security group allows ingress from ALB only (port container_port)
- Outbound: All traffic (for RDS, VPC endpoints, external APIs)

### Secrets Management
- Database passwords: Use AWS Secrets Manager ARN (not environment variables)
- API keys: Injected via task role at runtime
- ECR pull credentials: Managed by IAM task execution role

### Container Configuration
- No privileged containers
- Read-only root filesystem (recommended)
- Resource limits enforced (CPU, memory)

## Testing

### Expected Behavior
- ECR repositories created (one per service)
- Task definitions registered
- ECS services running desired count of tasks
- ALB target groups healthy (health check passing)
- Services accessible via ALB DNS name
- Logs appearing in CloudWatch log groups
- Auto-scaling policies configured

### Edge Cases
- Test service deployment with no running tasks (ALB target group unhealthy)
- Verify health check failures trigger task replacement
- Test scaling up/down based on CPU metrics
- Validate Secrets Manager injection (database password not in logs)
- Check ALB routing for multiple services (path-based rules)

### LocalStack Testing
```bash
# Start LocalStack
docker run -d -p 4566:4566 \
  -e SERVICES=ec2,ecs,ecr,elasticloadbalancing,cloudwatch,logs \
  localstack/localstack:4.4.0

# Configure
export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"

# Build and push test image to ECR
aws --endpoint-url=http://localhost:4566 ecr create-repository \
  --repository-name voting-service

# Test
tofu init
tofu plan -var="services={...}"
tofu apply -auto-approve

# Validate
aws --endpoint-url=http://localhost:4566 ecs list-services
aws --endpoint-url=http://localhost:4566 ecs describe-services
aws --endpoint-url=http://localhost:4566 logs describe-log-groups

# Destroy
tofu destroy -auto-approve
```

## Dependencies
- `network` module: VPC ID, private subnet IDs, VPC endpoint IDs
- `platform` module: ECS cluster, ALB, target group
- `database` module: RDS endpoint

## Module Integration Points
- Input `ecs_cluster_arn` from platform module
- Input `alb_arn` from platform module
- Input `db_instance_endpoint` from database module
- Input `vpc_endpoint_ids` for ECR endpoint access
- Output `ecr_repository_urls` consumed by CI/CD pipeline
- Output `service_endpoints` for external API calls

## Deployment Patterns

### Blue-Green Deployment
1. Create new task definition (revision N+1)
2. Update ECS service with new task definition
3. ALB automatically drains connections from old tasks
4. Rollback available via previous task definition

### Canary Deployment
1. Run new version in parallel (small % of traffic)
2. Monitor metrics (latency, error rate)
3. Gradually increase traffic percentage
4. Rollback if anomalies detected

## Notes
- ECR image tag: Use commit SHA or semantic versioning (not "latest" in prod)
- Task count: Recommended minimum 2 for HA
- Container insights: Useful for debugging, adds ~$0.50/hour per service
- Auto-scaling: CPU-based (recommended), memory-based (advanced)
- Connection draining: Graceful shutdown respects deregistration delay from ALB
