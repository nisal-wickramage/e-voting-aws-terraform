# Platform Module Specification

## Purpose
Create ECS cluster and Application Load Balancer foundation in private subnets, providing compute orchestration and traffic distribution for microservices.

## Inputs

| Variable | Type | Description | Required | Example |
|----------|------|-------------|----------|---------|
| `vpc_id` | string | VPC ID from network module | Yes | (from dependency) |
| `private_subnet_ids` | list(string) | Private subnet IDs for ALB and ECS | Yes | (from dependency) |
| `cluster_name` | string | ECS cluster name | Yes | `"e-voting-cluster"` |
| `alb_name` | string | Application Load Balancer name | Yes | `"e-voting-alb"` |
| `enable_container_insights` | bool | Enable ECS Container Insights | No | `true` |
| `enable_execute_command` | bool | Enable ECS Exec for debugging | No | `false` |
| `alb_internal` | bool | ALB internal (no internet access) | Yes | `true` |
| `alb_enable_deletion_protection` | bool | Prevent accidental ALB deletion | No | `false` |
| `deregistration_delay` | number | Connection draining timeout (seconds) | No | `30` |
| `environment` | string | Environment name (dev/staging/prod) | Yes | `"dev"` |
| `project_name` | string | Project name for resource tagging | Yes | `"e-voting"` |
| `enable_alb_access_logs` | bool | Enable ALB access logging to S3 | No | `false` |
| `alb_access_logs_s3_bucket` | string | S3 bucket for ALB logs | No | `""` |
| `enable_cross_zone_load_balancing` | bool | Distribute traffic across AZs | Yes | `true` |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `ecs_cluster_id` | string | ECS cluster ID |
| `ecs_cluster_arn` | string | ECS cluster ARN |
| `ecs_cluster_name` | string | ECS cluster name |
| `alb_id` | string | Application Load Balancer ID |
| `alb_arn` | string | ALB ARN |
| `alb_dns_name` | string | ALB DNS name (for internal reference) |
| `alb_security_group_id` | string | ALB security group ID |
| `ecs_security_group_id` | string | ECS tasks security group ID |
| `alb_zone_id` | string | ALB hosted zone ID (for Route53) |
| `default_target_group_arn` | string | Default target group ARN (for listener attachment) |
| `default_target_group_name` | string | Default target group name |
| `subnets_used` | list(string) | Private subnets used by ALB |
| `ecs_capacity_providers` | list(string) | Capacity providers (FARGATE, FARGATE_SPOT) |

## Resources

- **aws_ecs_cluster**: ECS cluster with Fargate capacity provider
- **aws_ecs_cluster_capacity_providers**: Fargate and Fargate Spot providers
- **aws_lb**: Application Load Balancer (internal, private subnets)
- **aws_lb_target_group**: Default target group (HTTP, health check)
- **aws_lb_listener**: HTTP listener (port 80) routing to default target group
- **aws_security_group** (ALB): Allows ingress from CloudFront security group (HTTPS placeholder)
- **aws_security_group** (ECS): Allows ingress from ALB security group on dynamic port range
- **aws_security_group_rule**: ALB ← CloudFront, ECS ← ALB
- **aws_cloudwatch_log_group**: ECS cluster logs (if Container Insights enabled)

## Implementation Steps

1. **Create ECS Cluster** (`cluster.tf`)
   - Resource: `aws_ecs_cluster`
   - Input: `cluster_name`, `enable_container_insights`
   - Outputs: `ecs_cluster_id`, `ecs_cluster_arn`, `ecs_cluster_name`

2. **Create ECS Cluster Capacity Providers** (`cluster.tf`)
   - Resources: `aws_ecs_cluster_capacity_providers`, `aws_ecs_cluster_capacity_providers_defaults`
   - Providers: FARGATE, FARGATE_SPOT
   - Dependencies: ECS cluster from step 1

3. **Create CloudWatch Log Group** (`logging.tf`) - Conditional on `enable_container_insights`
   - Resource: `aws_cloudwatch_log_group`
   - Input: `cluster_name`
   - Used for Container Insights metrics

4. **Create ALB Security Group** (`security.tf`)
   - Resource: `aws_security_group`
   - Rules: Inbound HTTPS (443) from CloudFront/VPC, Outbound to ECS SG
   - Input: `vpc_id`
   - Output: `alb_security_group_id`
   - Dependencies: VPC from network module

5. **Create ECS Security Group** (`security.tf`)
   - Resource: `aws_security_group`
   - Rules: Inbound dynamic ports (1024-65535) from ALB, Outbound all traffic
   - Input: `vpc_id`
   - Output: `ecs_security_group_id`
   - Dependencies: ALB security group from step 4

6. **Create Application Load Balancer** (`alb.tf`)
   - Resource: `aws_lb`
   - Inputs: `alb_name`, `alb_internal = true`, `enable_cross_zone_load_balancing`
   - Placement: Private subnets only
   - Security Group: From step 4
   - Outputs: `alb_id`, `alb_arn`, `alb_dns_name`, `alb_zone_id`
   - Dependencies: VPC from network module, Private subnets from network module, ALB security group (step 4)

7. **Create Default Target Group** (`alb.tf`)
   - Resource: `aws_lb_target_group`
   - Configuration: HTTP, health check (path /, interval 30s, timeout 5s)
   - Input: `vpc_id`, `deregistration_delay`
   - Output: `default_target_group_arn`, `default_target_group_name`
   - Dependencies: VPC from network module

8. **Create ALB Listener** (`alb.tf`)
   - Resource: `aws_lb_listener`
   - Configuration: HTTP (80) → Default target group (step 7)
   - Dependencies: ALB (step 6), Target group (step 7)

## Security

### Security Groups
- **ALB SG**: 
  - Inbound: HTTPS (443) from CloudFront security group / VPC CIDR (temporary)
  - Outbound: All traffic to ECS security group
- **ECS SG**:
  - Inbound: Dynamic port range (1024-65535) from ALB security group
  - Inbound: TCP 5432 from database module (for RDS access)
  - Outbound: All traffic (for ECR, VPC endpoints, external APIs)

### Network
- ALB deployed in private subnets (no internet exposure)
- Cross-zone load balancing enabled for HA
- Connection draining (graceful shutdown)

### Container Security
- ECS Exec disabled by default (enable for debugging only)
- Container Insights enabled for monitoring
- Task role separation (defined in ecs-services module)

## Testing

### Expected Behavior
- ECS cluster created and ready for tasks
- ALB in private subnets (internal = true)
- Health checks configured (HTTP 200)
- Security groups allow ALB ↔ ECS communication
- Default target group ready for service attachment
- Cross-zone load balancing enabled

### Edge Cases
- Test ALB with no registered targets (health check response)
- Verify deregistration delay (connection draining)
- Test security group: ECS can reach ALB, ALB cannot reach ECS (unidirectional)
- Validate Container Insights log group creation
- Check ALB deletion protection

### LocalStack Testing
```bash
# Start LocalStack
docker run -d -p 4566:4566 \
  -e SERVICES=ec2,elasticloadbalancing,ecs,cloudwatch \
  localstack/localstack:4.4.0

# Configure
export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"

# Test
tofu init
tofu plan -var="private_subnet_ids=[\"subnet-1\",\"subnet-2\"]"
tofu apply -auto-approve

# Validate
aws --endpoint-url=http://localhost:4566 ecs describe-clusters
aws --endpoint-url=http://localhost:4566 elbv2 describe-load-balancers
aws --endpoint-url=http://localhost:4566 elbv2 describe-target-groups

# Destroy
tofu destroy -auto-approve
```

## Dependencies
- `network` module: VPC ID, private subnet IDs

## Module Integration Points
- Output `ecs_cluster_arn` and `ecs_cluster_name` used by ecs-services
- Output `alb_arn` used by cdn-waf (CloudFront VPC origin)
- Output `default_target_group_arn` used by ecs-services
- Output `ecs_security_group_id` used by database (RDS security group rule)
- Output `alb_security_group_id` used by cdn-waf (WAF attachment)

## Notes
- ALB is internal (no public IP), traffic comes through CloudFront VPC origins
- Health checks: HTTP GET / every 30 seconds, healthy after 2 checks
- Target deregistration: graceful shutdown with connection draining
- Fargate Spot: Can use for non-critical services (cost optimization)
- Consider Application Insights for advanced diagnostics (future enhancement)
