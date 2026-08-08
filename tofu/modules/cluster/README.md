# Cluster Module

## Purpose

Creates the ECS cluster and Application Load Balancer foundation in private subnets, providing compute orchestration and traffic distribution for microservices.

## Overview

This module provisions:
- **ECS Cluster**: Fargate capacity provider with Container Insights support
- **Application Load Balancer**: Internal load balancer in private subnets
- **Security Groups**: Isolation between ALB, ECS tasks, and network tiers
- **Target Groups**: HTTP traffic routing to ECS services
- **Logging**: CloudWatch log groups for monitoring

## Inputs

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `vpc_id` | string | - | VPC ID from network module |
| `private_subnet_ids` | list(string) | - | Private subnet IDs (≥2 for HA) |
| `cluster_name` | string | - | ECS cluster name |
| `alb_name` | string | - | ALB name |
| `enable_container_insights` | bool | `true` | Enable Container Insights |
| `enable_execute_command` | bool | `false` | Enable ECS Exec |
| `alb_internal` | bool | `true` | ALB must be internal |
| `enable_cross_zone_load_balancing` | bool | `true` | Distribute across AZs |
| `deregistration_delay` | number | `30` | Connection drain timeout |
| `environment` | string | - | dev/staging/prod |
| `project_name` | string | - | Project name |
| `common_tags` | map(string) | `{}` | Common tags |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `ecs_cluster_id` | string | ECS cluster ID |
| `ecs_cluster_arn` | string | ECS cluster ARN |
| `ecs_cluster_name` | string | ECS cluster name |
| `ecs_capacity_providers` | list(string) | Capacity providers |
| `alb_id` | string | ALB ID |
| `alb_arn` | string | ALB ARN |
| `alb_dns_name` | string | ALB DNS name |
| `alb_security_group_id` | string | ALB SG ID |
| `ecs_security_group_id` | string | ECS tasks SG ID |
| `default_target_group_arn` | string | Default target group ARN |

## Implementation Steps

1. **ECS Cluster** - Creates cluster with Fargate capacity and Container Insights
2. **Capacity Providers** - Registers FARGATE and FARGATE_SPOT
3. **CloudWatch Logs** - Log group for Container Insights (conditional)
4. **ALB Security Group** - Allows HTTPS inbound from CloudFront
5. **ECS Security Group** - Allows ephemeral ports inbound from ALB
6. **Application Load Balancer** - Internal ALB in private subnets
7. **Target Group** - Default HTTP target group for routing

## Security

- ALB is internal-only (no internet exposure)
- All ingress via CloudFront/NAT gateway
- ECS tasks isolated in security group
- Security groups restrict to tier-specific traffic
- Container Insights enabled for auditing

## Usage

```hcl
module "cluster" {
  source = "./modules/cluster"

  vpc_id               = module.network.vpc_id
  private_subnet_ids   = module.network.private_subnet_ids_by_tier["app"]
  cluster_name         = "e-voting-cluster"
  alb_name             = "e-voting-alb"
  enable_container_insights = true
  environment          = "dev"
  project_name         = "e-voting"

  common_tags = {
    Environment = "dev"
    Project     = "e-voting"
    ManagedBy   = "terragrunt"
  }
}
```

## Dependencies

- **network module**: VPC and subnets (must be created first)

## Cost Considerations

- ECS Fargate: Pay per task (2 vCPU, 4 GB memory default)
- ALB: Fixed hourly charge + data processing
- Fargate Spot: ~70% discount for fault-tolerant services
- CloudWatch Container Insights: ~0.50/cluster/month + metrics

## Troubleshooting

**Tasks not launching**: Check security group rules and VPC endpoint access
**ALB unhealthy**: Verify target group health check and service response
**High latency**: Enable cross-zone load balancing for balanced distribution
