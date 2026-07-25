# Monitoring Module Specification

## Purpose
Create CloudWatch alarms, dashboards, and log groups for operational visibility into ECS tasks, RDS database, ALB, and application health.

## Inputs

| Variable | Type | Description | Required | Example |
|----------|------|-------------|----------|---------|
| `ecs_cluster_name` | string | ECS cluster name from platform | Yes | (from dependency) |
| `alb_arn_suffix` | string | ALB ARN suffix for CloudWatch metrics | Yes | (from dependency) |
| `alb_target_group_arn_suffix` | string | Target group ARN suffix | Yes | (from dependency) |
| `db_instance_id` | string | RDS instance ID from database | Yes | (from dependency) |
| `alarm_email` | string | Email for SNS notifications | No | `"ops@example.com"` |
| `alarm_sns_topic_arn` | string | SNS topic ARN for alarms (optional) | No | `""` |
| `ecs_cpu_threshold` | number | ECS CPU utilization threshold (%) | No | `80` |
| `ecs_memory_threshold` | number | ECS memory utilization threshold (%) | No | `80` |
| `ecs_task_count_threshold` | number | Minimum running tasks before alert | No | `1` |
| `rds_cpu_threshold` | number | RDS CPU utilization threshold (%) | No | `80` |
| `rds_storage_threshold` | number | RDS storage utilization threshold (%) | No | `80` |
| `alb_target_unhealthy_threshold` | number | Max unhealthy targets before alert | No | `1` |
| `alb_response_time_threshold` | number | ALB response time threshold (ms) | No | `1000` |
| `alb_http_5xx_threshold` | number | HTTP 5xx errors per minute threshold | No | `10` |
| `enable_detailed_monitoring` | bool | Enable detailed (1-min) vs standard (5-min) | No | `false` |
| `log_retention_days` | number | CloudWatch log retention (days) | No | `30` |
| `environment` | string | Environment name (dev/staging/prod) | Yes | `"prod"` |
| `project_name` | string | Project name for resource tagging | Yes | `"e-voting"` |
| `enable_dashboard` | bool | Create CloudWatch dashboard | Yes | `true` |
| `dashboard_name` | string | Dashboard name | No | `"e-voting-monitoring"` |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `sns_topic_arn` | string | SNS topic ARN for alarm notifications |
| `sns_topic_name` | string | SNS topic name |
| `dashboard_arn` | string | CloudWatch dashboard ARN |
| `dashboard_name` | string | CloudWatch dashboard name |
| `cloudwatch_log_group_names` | map(string) | Log group names by service |
| `alarm_arns` | map(string) | Alarm ARNs by alarm name |
| `alarm_names` | list(string) | All alarm names |
| `metric_filter_names` | list(string) | Metric filter names (for custom metrics) |

## Resources

- **aws_sns_topic**: SNS topic for alarm notifications
- **aws_sns_topic_subscription**: Email subscription to SNS topic
- **aws_cloudwatch_log_group** (multiple): Per-service and application logs
- **aws_cloudwatch_log_group_policy**: Log group access policy
- **aws_cloudwatch_metric_alarm** (multiple):
  - ECS: CPU, memory, running task count
  - RDS: CPU, storage, database connections
  - ALB: Unhealthy targets, response time, HTTP errors
  - Application: Custom metrics (voting submissions, errors)
- **aws_cloudwatch_log_metric_filter** (multiple): Extract metrics from logs
- **aws_cloudwatch_dashboard**: Custom dashboard with widgets
- **aws_cloudwatch_event_rule**: Event-based triggers (optional)

## Implementation Steps

1. **Create SNS Topic for Alarms** (`notifications.tf`)
   - Resource: `aws_sns_topic`
   - Output: `sns_topic_arn`, `sns_topic_name`
   - Purpose: Central notification hub for all alarms

2. **Subscribe Email to SNS Topic** (`notifications.tf`) - Conditional on `alarm_email`
   - Resource: `aws_sns_topic_subscription`
   - Input: `alarm_email`
   - Confirmation: Manual email confirmation required

3. **Create CloudWatch Log Groups** (`logs.tf`)
   - Resources: `aws_cloudwatch_log_group` (per service/component)
   - Input: `log_retention_days`
   - Logs for: ECS tasks, RDS, ALB, Application

4. **Create ECS Alarms** (`alarms_ecs.tf`)
   - Resources: `aws_cloudwatch_metric_alarm` (3 types)
   - Alarms:
     - CPU utilization: Threshold `ecs_cpu_threshold`
     - Memory utilization: Threshold `ecs_memory_threshold`
     - Running task count: Alert if below `ecs_task_count_threshold`
   - Inputs: `ecs_cluster_name`, `alarm_email`, Threshold values
   - Dependency: SNS topic (step 1)

5. **Create RDS Alarms** (`alarms_rds.tf`)
   - Resources: `aws_cloudwatch_metric_alarm` (3 types)
   - Alarms:
     - CPU utilization: Threshold `rds_cpu_threshold`
     - Storage utilization: Threshold `rds_storage_threshold`
     - Database connections: Alert on high connections
   - Inputs: `db_instance_id`, Threshold values
   - Dependency: SNS topic (step 1)

6. **Create ALB Alarms** (`alarms_alb.tf`)
   - Resources: `aws_cloudwatch_metric_alarm` (4 types)
   - Alarms:
     - Unhealthy targets: Alert if > `alb_target_unhealthy_threshold`
     - Response time: Alert if > `alb_response_time_threshold` ms
     - HTTP 5xx errors: Alert if > `alb_http_5xx_threshold` per minute
     - Target response time: P99 latency
   - Inputs: `alb_arn_suffix`, `alb_target_group_arn_suffix`, Threshold values
   - Dependency: SNS topic (step 1)

7. **Create Log Metric Filters** (`metric_filters.tf`) - Optional for custom metrics
   - Resources: `aws_cloudwatch_log_metric_filter`
   - Filters: Application-specific patterns (e.g., error counts, voting submissions)
   - Purpose: Convert log events into custom metrics

8. **Create CloudWatch Dashboard** (`dashboard.tf`) - Conditional on `enable_dashboard`
   - Resource: `aws_cloudwatch_dashboard`
   - Input: `dashboard_name`
   - Widgets: ECS metrics, RDS metrics, ALB metrics, custom application metrics
   - Layout: Grid layout with key performance indicators
   - Output: `dashboard_arn`, `dashboard_name`

## Security

### Access Control
- SNS topic: Only CloudWatch alarms can publish
- Log groups: Retention policy to prevent unlimited growth
- Dashboard: Limited to IAM roles with CloudWatch permissions

### Sensitive Data
- No secrets in log messages (use Secrets Manager for credential rotation)
- PII filtering: Exclude user data from logs (implement in application)
- Log encryption: Enabled by default (KMS managed key)

### Audit Trail
- CloudTrail logs alarm configuration changes
- SNS subscription audit (who receives alerts)

## Testing

### Expected Behavior
- SNS topic created and email subscription confirmed
- Log groups created for ECS, RDS, ALB
- Alarms created for each metric
- Dashboard displays metrics and alarms
- Log retention policy enforced
- Metric filters extract custom metrics

### Edge Cases
- Test alarm trigger: Manually modify ECS task count to trigger alarm
- Verify SNS email: Check inbox for subscription and alarm notifications
- Test log retention: Verify old logs deleted after retention period
- Validate dashboard: Widgets display correct metrics
- Test metric filters: Send test message to log group, verify metric

### LocalStack Testing
```bash
# Start LocalStack
docker run -d -p 4566:4566 \
  -e SERVICES=cloudwatch,logs,sns,ecs \
  localstack/localstack:4.4.0

# Configure
export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"

# Test
tofu init
tofu plan
tofu apply -auto-approve

# Validate
aws --endpoint-url=http://localhost:4566 cloudwatch describe-alarms
aws --endpoint-url=http://localhost:4566 logs describe-log-groups
aws --endpoint-url=http://localhost:4566 sns list-subscriptions

# Destroy
tofu destroy -auto-approve
```

## Dependencies
- `platform` module: ECS cluster name, ALB ARN suffix
- `database` module: RDS instance ID

## Module Integration Points
- Input `ecs_cluster_name` from platform module
- Input `alb_arn_suffix` from platform module
- Input `db_instance_id` from database module
- Output `sns_topic_arn` for external integrations (Slack, PagerDuty)
- Output `dashboard_name` for console URL

## Monitoring Strategy

### Key Metrics (4 Golden Signals)
1. **Latency**: ALB response time (target latency < 1 second)
2. **Traffic**: Requests per second (ALB RequestCount)
3. **Errors**: HTTP 4xx/5xx rates (ALB HTTP error codes)
4. **Saturation**: CPU/memory utilization (ECS, RDS)

### Alerting Levels
- **Critical**: Service unavailable, data loss risk (p0)
- **Warning**: Degraded performance, high resource utilization (p1)
- **Info**: Scaling events, deployment changes (p2)

### Thresholds
| Metric | Warning | Critical |
|--------|---------|----------|
| ECS CPU | 70% | 90% |
| ECS Memory | 75% | 90% |
| RDS CPU | 70% | 85% |
| RDS Storage | 70% | 85% |
| ALB Response Time | 500ms | 2000ms |
| ALB HTTP 5xx | 5/min | 20/min |
| Unhealthy Targets | 0 | 1+ |

### Custom Metrics
- Voting submissions per minute
- Database query duration
- API error rates by endpoint
- Payment processing latency

## Logging Strategy

### Log Groups
- **ECS Tasks**: `/ecs/voting-service`, `/ecs/auth-service`, etc.
- **ALB**: `/aws/alb/e-voting` (if enabled)
- **RDS**: `/aws/rds/instance/e-voting-db`
- **Application**: Custom application logs (structured JSON)

### Log Levels
- **ERROR**: Application errors, exceptions
- **WARN**: Degraded performance, retries, rate limits
- **INFO**: Service startup/shutdown, important events
- **DEBUG**: Verbose debugging (dev only, not prod)

### Structured Logging
```json
{
  "timestamp": "2026-07-21T10:30:00Z",
  "level": "INFO",
  "service": "voting-service",
  "request_id": "abc123",
  "action": "vote_submitted",
  "user_id": "user123",
  "duration_ms": 45,
  "status": "success"
}
```

## Dashboard Layout

### System Health
- ECS cluster CPU/memory utilization
- RDS CPU/connections
- ALB unhealthy targets count
- NAT gateway traffic

### Application Performance
- Requests per second (ALB)
- API response time distribution
- Error rate (4xx, 5xx)
- Voting submissions per minute

### Cost Optimization
- NAT gateway data transfer
- S3 access patterns
- CloudFront cache hit ratio

## Notes
- CloudWatch pricing: $0.30 per alarm/month + metric storage
- Log storage: $0.50 per GB ingested, $0.03 per GB stored
- SNS email: Free tier includes 1,000 emails/month
- Dashboard: 3 free dashboards, then $3 per dashboard/month
- Metric filters: Extract metrics from log messages (1000 matches/sec free)
- Log retention: Set appropriate retention (not unlimited) to manage costs
