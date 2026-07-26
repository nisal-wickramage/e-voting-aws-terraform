# Disaster Recovery Module

Provisions RDS backup automation, monitoring, and recovery infrastructure for the e-voting system.

## Purpose

- **Automated Backups**: Configure RDS automated backup retention and windows
- **Manual Snapshots**: Daily scheduled snapshots via EventBridge + SNS
- **Backup Monitoring**: CloudWatch alarms for backup failures and storage usage
- **Notifications**: SNS topic for backup events and alerts
- **Recovery Automation**: IAM roles for future Lambda-based recovery workflows

## Architecture

```
┌─────────────────────────────────────────────┐
│         RDS Database Cluster                │
│   (Multi-AZ PostgreSQL in private subnets)  │
│                                             │
│  Automated Backups:                         │
│  - Retention: 7-35 days (configurable)     │
│  - Backup Window: 3AM-4AM UTC (default)    │
│  - Encryption: KMS (optional)               │
└────────────┬────────────────────────────────┘
             │
    ┌────────┴─────────┬───────────────┐
    │                  │               │
    ▼                  ▼               ▼
┌────────────┐  ┌──────────────┐  ┌──────────┐
│ EventBridge│  │ CloudWatch   │  │ SNS      │
│ Rule       │  │ Alarms       │  │ Topic    │
│ (Daily)    │  │ - Backup     │  │ (Events) │
└────────────┘  │ - Storage    │  └──────────┘
                └──────────────┘
                      │
                      ▼
            ┌──────────────────┐
            │ CloudWatch Logs  │
            │ & Dashboard      │
            └──────────────────┘
```

## Key Resources

| Resource | Purpose |
|----------|---------|
| `aws_sns_topic` | SNS topic for backup notifications |
| `aws_cloudwatch_log_group` | Log group for RDS backup events |
| `aws_cloudwatch_metric_alarm` | Alarms for backup failures and storage |
| `aws_cloudwatch_event_rule` | EventBridge rule for daily snapshots |
| `aws_iam_role` | IAM role for backup automation |
| `aws_cloudwatch_dashboard` | Monitoring dashboard for backup metrics |

## Backup Strategy

### Automated Backups (RDS Native)
- **Retention**: Configurable 1-35 days (default: 7 days for dev, 30 days for prod)
- **Window**: 3AM-4AM UTC (customizable)
- **Encryption**: Optional KMS encryption
- **Scope**: Includes transaction logs for point-in-time recovery

### Manual Snapshots (Daily via EventBridge)
- **Frequency**: Daily at 2AM UTC (configurable)
- **Storage**: Long-term snapshot retention
- **Automation**: EventBridge triggers SNS notification (Lambda integration ready)

## Usage

```hcl
module "disaster_recovery" {
  source = "../../modules/disaster-recovery"

  project_name  = "e-voting"
  environment   = "dev"
  rds_cluster_id = "e-voting-dev-cluster"

  # Backup Configuration
  rds_backup_retention_days = 7
  backup_window            = "03:00-04:00"
  maintenance_window       = "sun:04:00-sun:05:00"

  # Security
  enable_backup_encryption = true
  kms_key_id              = "arn:aws:kms:us-east-1:123456789012:key/..."

  # Automation
  enable_manual_snapshots = true
  snapshot_retention_days = 30

  # Monitoring
  enable_backup_monitoring = true

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
| `rds_cluster_id` | string | required | RDS cluster identifier |
| `rds_backup_retention_days` | number | required | Backup retention (1-35 days) |
| `backup_window` | string | `"03:00-04:00"` | Backup window in UTC (HH:MM-HH:MM) |
| `maintenance_window` | string | `"sun:04:00-sun:05:00"` | Maintenance window in UTC |
| `enable_backup_encryption` | bool | `true` | Enable KMS encryption for backups |
| `kms_key_id` | string | `null` | KMS key ARN (required if encryption enabled) |
| `enable_manual_snapshots` | bool | `true` | Enable daily manual snapshots |
| `snapshot_retention_days` | number | `30` | Manual snapshot retention (days) |
| `enable_backup_monitoring` | bool | `true` | Enable CloudWatch monitoring |
| `backup_failure_threshold_count` | number | `1` | Failed backups before alarm |
| `tags` | map(string) | `{}` | Common tags for all resources |

## Outputs

| Name | Description |
|------|-------------|
| `sns_topic_arn` | SNS topic ARN for backup events |
| `sns_topic_name` | SNS topic name |
| `cloudwatch_log_group_name` | CloudWatch log group name |
| `backup_automation_role_arn` | IAM role ARN for automation |
| `daily_snapshot_rule_arn` | EventBridge rule ARN |
| `backup_alarm_failed_arn` | Backup failure alarm ARN |
| `backup_alarm_storage_arn` | Storage alarm ARN |
| `dashboard_name` | CloudWatch dashboard name |

## Monitoring

### CloudWatch Alarms
1. **Backup Failed**: Triggers when RDS backup fails
2. **Storage High**: Triggers when backup storage exceeds 80GB

### CloudWatch Dashboard
Displays:
- Storage usage (Used vs. Free)
- Database connections
- CPU utilization
- Backup frequency

### SNS Notifications
Subscribe to SNS topic for:
- Backup completion events
- Backup failure alerts
- Storage usage warnings
- Manual snapshot triggers

## Recovery Procedures

### Restore from Automated Backup (Point-in-Time)
```bash
# List available automated backups
aws rds describe-db-cluster-backups \
  --db-cluster-identifier e-voting-dev-cluster \
  --region us-east-1

# Restore to specific point in time
aws rds restore-db-cluster-to-point-in-time \
  --db-cluster-identifier e-voting-dev-cluster-restored \
  --source-db-cluster-identifier e-voting-dev-cluster \
  --restore-type copy-on-write \
  --restore-to-time 2026-07-26T10:00:00Z \
  --region us-east-1
```

### Restore from Snapshot
```bash
# List available snapshots
aws rds describe-db-cluster-snapshots \
  --db-cluster-identifier e-voting-dev-cluster \
  --region us-east-1

# Restore from snapshot
aws rds restore-db-cluster-from-snapshot \
  --db-cluster-identifier e-voting-dev-cluster-restored \
  --snapshot-identifier e-voting-dev-snapshot-20260726 \
  --engine aurora-postgresql \
  --region us-east-1
```

## RPO/RTO Targets

| Scenario | RPO | RTO | Strategy |
|----------|-----|-----|----------|
| **Single-AZ Failure** | < 1 hour | < 15 min | Automated failover to read replica |
| **Regional Outage** | < 24 hours | < 1 hour | Cross-region snapshot restore |
| **Data Corruption** | < 1 hour | < 1 hour | Point-in-time recovery |
| **Human Error** | < 30 min | < 30 min | Rollback via snapshot |

## Automation Ready

The module provides IAM roles and event routing for future Lambda-based automation:

```python
# Example Lambda for automated snapshot management
import boto3

rds = boto3.client('rds')

def cleanup_old_snapshots(event, context):
    """Delete snapshots older than retention period"""
    cluster_id = event['cluster_id']
    retention_days = event['retention_days']
    
    snapshots = rds.describe_db_cluster_snapshots(
        DBClusterIdentifier=cluster_id
    )
    
    for snapshot in snapshots['DBClusterSnapshots']:
        age_days = (datetime.now() - snapshot['SnapshotCreateTime']).days
        if age_days > retention_days:
            rds.delete_db_cluster_snapshot(
                DBClusterSnapshotIdentifier=snapshot['DBClusterSnapshotIdentifier']
            )
```

## Cost Optimization

1. **Backup Storage**: Charged per GB-month (~$0.023/GB)
   - Reduce retention period for dev/staging
   - Use automated backups (cheaper than manual snapshots)

2. **Snapshots**: Charged per GB-month for incremental changes
   - Daily snapshots add cost; consider weekly for non-prod
   - Clean up old snapshots regularly

3. **Data Transfer**: Charged for cross-region copies
   - Only enable cross-region replication for prod

## Backup Best Practices

- ✅ Test restore procedures monthly
- ✅ Monitor backup completion and errors
- ✅ Encrypt backups for sensitive data
- ✅ Retain backups for at least 7 days
- ✅ Use automated backups + periodic manual snapshots
- ✅ Document RTO/RPO for each environment
- ✅ Review access to backup data regularly

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Backup failed | Storage full or timeout | Check available space; increase retention window |
| Restore failed | Incompatible parameter | Verify restored instance specs match original |
| High backup cost | Too many snapshots | Implement snapshot cleanup Lambda |
| Slow restore | Large database | Restore to larger instance type temporarily |

## Deployment

```bash
# Deploy disaster recovery (depends on database module)
cd terragrunt/dev/disaster-recovery
terragrunt apply

# Verify backups
aws rds describe-db-cluster-backups --db-cluster-identifier e-voting-dev-cluster

# Subscribe to SNS topic for notifications
aws sns subscribe --topic-arn <sns-topic-arn> --protocol email --notification-endpoint your-email@example.com
```

## Next Steps

1. Set up SNS email subscriptions for backup alerts
2. Create Lambda function for automated snapshot cleanup
3. Document manual restore procedures in runbook
4. Test restore procedure monthly
5. Set up cross-region replication for prod (optional)
