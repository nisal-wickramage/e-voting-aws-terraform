# Monitoring Module

Comprehensive CloudWatch monitoring for the e-voting system with alarms for infrastructure health, database performance, message queues, and service availability.

## Purpose

- **Real-time Alerts**: CloudWatch alarms for critical infrastructure metrics
- **Queue Monitoring**: Track SQS queue depth, old messages, and DLQ backlogs
- **Database Health**: Monitor RDS CPU, memory, connections, and outages
- **Load Balancer**: Track unhealthy targets and response times
- **Service Availability**: Monitor ECS task counts for each service
- **Unified Dashboard**: Single pane of glass for all metrics
- **SNS Notifications**: Centralized alert routing to email/SMS/Slack

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                 CloudWatch Metrics                      │
│  (ALB, RDS, SQS, ECS, Lambda)                          │
└────────────────┬────────────────────────────────────────┘
                 │
         ┌───────┴────────┬────────────┬─────────┐
         │                │            │         │
         ▼                ▼            ▼         ▼
    ┌─────────┐      ┌────────┐   ┌──────┐  ┌──────┐
    │   ALB   │      │  RDS   │   │ SQS  │  │ ECS  │
    │ Alarms  │      │ Alarms │   │Alarms│  │Alarms│
    └────┬────┘      └────┬───┘   └──┬───┘  └──┬───┘
         │                │          │        │
         └────────────────┼──────────┼────────┘
                          │
                          ▼
                  ┌─────────────────┐
                  │   SNS Topic     │
                  │  (Monitoring    │
                  │   Alerts)       │
                  └────────┬────────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
              ▼            ▼            ▼
          ┌────────┐  ┌─────────┐  ┌───────┐
          │ Email  │  │  Slack  │  │  SMS  │
          └────────┘  └─────────┘  └───────┘
```

## Alarms

### Load Balancer (ALB)

| Alarm | Metric | Threshold | Condition |
|-------|--------|-----------|-----------|
| **Unhealthy Targets** | UnHealthyHostCount | ≥1 | ALB has one or more unhealthy targets |

### RDS Database

| Alarm | Metric | Threshold | Condition |
|-------|--------|-----------|-----------|
| **CPU High** | CPUUtilization | >80% | Database CPU utilization exceeds threshold |
| **Memory Low** | FreeableMemory | <500MB | Database available memory drops below threshold |
| **Database Outage** | DatabaseConnections | <1 | No active connections (possible outage) |

### SQS Queues

| Alarm | Metric | Threshold | Condition |
|-------|--------|-----------|-----------|
| **Queue Depth High** | ApproximateNumberOfMessagesVisible | >1000 | Queue has >1000 pending messages |
| **Old Messages** | ApproximateAgeOfOldestMessage | >60min | Oldest message is older than threshold |
| **DLQ Messages** | ApproximateNumberOfMessagesVisible | ≥5 | Dead-letter queue has accumulated messages |

### ECS Services

| Alarm | Metric | Threshold | Condition |
|-------|--------|-----------|-----------|
| **Running Count Low** | RunningCount | <1 | Service has fewer running tasks than desired |

## Usage

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  project_name  = "e-voting"
  environment   = "dev"

  # ALB
  alb_name                    = "e-voting-alb"
  alb_target_group_name       = "e-voting-api-tg"
  unhealthy_target_threshold  = 1

  # RDS
  rds_cluster_id        = "e-voting-dev-cluster"
  rds_cpu_threshold     = 80
  rds_memory_threshold  = 500000000  # 500 MB

  # SQS
  sqs_queue_names                  = ["e-voting-async-api-requests"]
  sqs_dlq_names                    = ["e-voting-async-api-requests-dlq"]
  sqs_dlq_threshold                = 5
  sqs_old_message_threshold_minutes = 60

  # ECS
  ecs_cluster_name = "e-voting-cluster"
  ecs_service_names = [
    "e-voting-async-api",
    "e-voting-worker",
    "e-voting-api"
  ]

  # Alerts
  alarm_sns_topic_arn = aws_sns_topic.alerts.arn

  # Thresholds
  evaluation_periods      = 2
  datapoints_to_alarm     = 2
  alarm_period_seconds    = 300
  treat_missing_data      = "notBreaching"

  tags = {
    CostCenter = "engineering"
  }
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project_name` | string | required | Project name (1-32 chars) |
| `environment` | string | required | Environment (dev, staging, prod) |
| `alb_name` | string | required | ALB name for monitoring |
| `alb_target_group_name` | string | required | ALB target group name |
| `unhealthy_target_threshold` | number | `1` | Unhealthy target count threshold |
| `rds_cluster_id` | string | required | RDS cluster identifier |
| `rds_cpu_threshold` | number | `80` | RDS CPU % threshold |
| `rds_memory_threshold` | number | `500000000` | RDS free memory threshold (bytes) |
| `sqs_queue_names` | list(string) | `[]` | SQS queue names to monitor |
| `sqs_dlq_names` | list(string) | `[]` | SQS DLQ names to monitor |
| `sqs_dlq_threshold` | number | `5` | DLQ message count threshold |
| `sqs_old_message_threshold_minutes` | number | `60` | Old message age threshold (minutes) |
| `ecs_cluster_name` | string | required | ECS cluster name |
| `ecs_service_names` | list(string) | `[]` | ECS service names to monitor |
| `alarm_sns_topic_arn` | string | required | SNS topic ARN for notifications |
| `evaluation_periods` | number | `2` | Periods before triggering alarm |
| `datapoints_to_alarm` | number | `2` | Datapoints that must breach |
| `alarm_period_seconds` | number | `300` | Metric evaluation period |
| `treat_missing_data` | string | `"notBreaching"` | Missing data treatment |
| `tags` | map(string) | `{}` | Common tags |

## Outputs

| Name | Description |
|------|-------------|
| `monitoring_alerts_sns_topic_arn` | SNS topic ARN for alerts |
| `monitoring_alerts_sns_topic_name` | SNS topic name |
| `alb_unhealthy_targets_alarm_arn` | ALB unhealthy targets alarm ARN |
| `rds_cpu_utilization_alarm_arn` | RDS CPU alarm ARN |
| `rds_memory_utilization_alarm_arn` | RDS memory alarm ARN |
| `rds_database_connections_alarm_arn` | RDS outage detection alarm ARN |
| `sqs_dlq_message_alarms` | Map of DLQ alarms (name → ARN) |
| `sqs_old_message_alarms` | Map of old message alarms (queue → ARN) |
| `sqs_queue_depth_alarms` | Map of queue depth alarms (queue → ARN) |
| `ecs_running_count_alarms` | Map of ECS alarms (service → ARN) |
| `dashboard_name` | CloudWatch dashboard name |
| `all_alarm_arns` | List of all alarm ARNs |

## Dashboard

CloudWatch dashboard includes:
- **ALB Health**: Healthy/unhealthy targets, response time
- **RDS Metrics**: CPU, freeable memory, connections
- **SQS Queues**: Queue depth for all monitored queues
- **SQS DLQs**: Dead-letter queue message counts
- **ECS Services**: Running task counts per service

Access via:
```bash
# Open in AWS Console
aws cloudwatch get-dashboard \
  --dashboard-name e-voting-dev-monitoring \
  --region us-east-1
```

## Alert Routing

### Subscribe to SNS Topic
```bash
# Email
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:123456789012:e-voting-dev-monitoring-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com

# SMS
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:123456789012:e-voting-dev-monitoring-alerts \
  --protocol sms \
  --notification-endpoint +1234567890

# Slack (via lambda)
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:123456789012:e-voting-dev-monitoring-alerts \
  --protocol lambda \
  --notification-endpoint arn:aws:lambda:us-east-1:123456789012:function:slack-notifier
```

## Alert Response Playbook

### ALB Unhealthy Targets
1. **Check**: ECS task health
   ```bash
   aws ecs list-tasks --cluster e-voting-cluster
   aws ecs describe-tasks --cluster e-voting-cluster --tasks <task-arn>
   ```
2. **Review**: CloudWatch logs for task errors
3. **Remediate**: Redeploy service or restart tasks

### RDS CPU High / Memory Low
1. **Check**: Active queries
   ```bash
   psql -h <rds-endpoint> -U postgres -c "SELECT * FROM pg_stat_activity;"
   ```
2. **Review**: CloudWatch dashboard for trends
3. **Remediate**: Optimize queries, scale instance type, or reduce connections

### RDS Database Outage
1. **Verify**: RDS cluster status in AWS Console
2. **Check**: Security group rules allow access from ECS
3. **Remediate**: Failover to replica or restore from backup

### SQS Old Messages / Queue Depth High
1. **Check**: ECS worker service is running
   ```bash
   aws ecs describe-services --cluster e-voting-cluster --services e-voting-worker
   ```
2. **Review**: Worker logs for processing errors
3. **Remediate**: Scale worker tasks or fix processing bottleneck

### SQS DLQ Messages
1. **Check**: DLQ messages for error details
   ```bash
   aws sqs receive-message --queue-url <dlq-url> --max-number-of-messages 10
   ```
2. **Review**: Message body for failure reason
3. **Remediate**: Fix async-api or worker, then replay DLQ

### ECS Running Count Low
1. **Check**: Deployment status
   ```bash
   aws ecs describe-services --cluster e-voting-cluster --services <service-name>
   ```
2. **Review**: CloudWatch logs for task errors
3. **Remediate**: Check task definition, IAM role, or scaling limits

## Thresholds (Environment-Specific)

### Dev
- RDS CPU: 80%
- RDS Memory: 500 MB
- SQS Queue Depth: 1000 messages
- SQS Old Message Age: 60 minutes
- SQS DLQ: 5 messages

### Prod
- RDS CPU: 70%
- RDS Memory: 1 GB
- SQS Queue Depth: 500 messages
- SQS Old Message Age: 15 minutes
- SQS DLQ: 1 message (immediate alert)

## Cost Considerations

- **CloudWatch Metrics**: ~$0.10/metric/month (1st 10,000)
- **CloudWatch Alarms**: Free tier for 10 alarms; $0.10/alarm/month after
- **SNS Notifications**: $0.50/million SNS requests (negligible for typical usage)
- **Dashboard**: No additional cost

## Deployment

```bash
# Create SNS topic first (if not via other module)
aws sns create-topic --name e-voting-dev-monitoring-alerts

# Deploy monitoring
cd terragrunt/dev/monitoring
terragrunt apply

# Subscribe to alerts
aws sns subscribe \
  --topic-arn $(terragrunt output -raw monitoring_alerts_sns_topic_arn) \
  --protocol email \
  --notification-endpoint devops@example.com

# View dashboard
aws cloudwatch get-dashboard \
  --dashboard-name e-voting-dev-monitoring \
  --region us-east-1
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Alarms not firing | Missing data / insufficient sample | Check metric publishing; adjust `treat_missing_data` |
| Too many false alarms | Threshold too sensitive | Increase threshold or increase `evaluation_periods` |
| Metrics not visible | Alarm targeting wrong resource | Verify resource IDs in dimensions match actual resources |
| SNS not receiving | Topic policy restrictive | Check SNS topic policy allows CloudWatch |

## Future Enhancements

1. **Custom Metrics**: Business metrics (vote processed rate, user registrations)
2. **Log Insights**: Automated log analysis for errors
3. **Anomaly Detection**: ML-based anomaly detection for unexpected behavior
4. **Composite Alarms**: Combine multiple alarms into composite alert
5. **Scheduled Actions**: Auto-scale on schedule or based on alarms
