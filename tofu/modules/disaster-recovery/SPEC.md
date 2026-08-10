# Disaster Recovery Module Specification

## Purpose
Enable automated backups, snapshots, and cross-region replication for RDS and S3 to ensure data protection and rapid recovery from infrastructure failures.

## Inputs

| Variable | Type | Description | Required | Example |
|----------|------|-------------|----------|---------|
| `db_instance_id` | string | RDS instance ID from database | Yes | (from dependency) |
| `s3_bucket_id` | string | S3 bucket ID from s3-frontend | Yes | (from dependency) |
| `db_backup_retention_days` | number | RDS backup retention (days) | Yes | `30` |
| `db_backup_window` | string | RDS backup window (UTC) | Yes | `"03:00-04:00"` |
| `enable_rds_snapshots` | bool | Enable automated RDS snapshots | No | `true` |
| `rds_snapshot_schedule` | string | Snapshot schedule (cron expression) | No | `"0 2 * * *"` (daily 2 AM UTC) |
| `rds_snapshot_retention_days` | number | Manual snapshot retention (days) | No | `90` |
| `enable_rds_cross_region_backup` | bool | Enable cross-region backup copy | No | `false` |
| `rds_backup_destination_region` | string | Destination region for RDS backup | No | `"us-west-2"` |
| `enable_s3_cross_region_replication` | bool | Enable S3 cross-region replication | No | `false` |
| `s3_replica_bucket_name` | string | S3 replica bucket name (must exist) | No | `""` |
| `s3_replica_region` | string | Replica bucket region | No | `"us-west-2"` |
| `enable_s3_versioning` | bool | Enable S3 versioning (required for DR) | Yes | `true` |
| `s3_version_retention_days` | number | Delete old S3 versions after (days) | No | `90` |
| `environment` | string | Environment name (dev/staging/prod) | Yes | `"prod"` |
| `project_name` | string | Project name for resource tagging | Yes | `"e-voting"` |
| `rpo_target_hours` | number | Recovery Point Objective (hours) | No | `24` |
| `rto_target_hours` | number | Recovery Time Objective (hours) | No | `4` |
| `enable_dr_runbook` | bool | Generate DR runbook document | No | `true` |
| `dr_runbook_path` | string | Path for DR runbook | No | `"./docs/DR_RUNBOOK.md"` |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `rds_backup_window` | string | RDS automated backup window |
| `rds_backup_retention_days` | number | RDS backup retention period |
| `rds_snapshot_schedule` | string | RDS snapshot schedule |
| `rds_snapshot_arn_template` | string | ARN template for RDS snapshots |
| `s3_replication_role_arn` | string | IAM role ARN for S3 replication |
| `s3_replication_status` | string | S3 replication status (Enabled/Disabled) |
| `s3_version_noncurrent_retention_days` | number | Noncurrent version retention |
| `disaster_recovery_runbook_url` | string | URL to DR runbook (local file) |
| `recovery_metrics` | object | RPO/RTO metrics and recovery procedures |
| `backup_inventory` | map(string) | Backup locations and retention info |

## Resources

- **aws_db_instance** (updated): Enable automated backups, backup window
- **aws_db_snapshot**: Manual snapshot (created as part of scheduled task)
- **aws_backup_vault**: AWS Backup centralized vault (optional, alternative to DMS)
- **aws_backup_plan**: Backup plan with RDS/EBS policies
- **aws_backup_selection**: Resources to backup
- **aws_s3_bucket_replication_configuration**: S3 cross-region replication
- **aws_s3_bucket_versioning**: S3 versioning (from s3-frontend, referenced here)
- **aws_s3_bucket_lifecycle_configuration**: Delete old versions per retention policy
- **aws_iam_role**: S3 replication role
- **aws_iam_role_policy**: Replication permissions
- **aws_cloudwatch_metric_alarm**: Backup success/failure alarms
- **aws_sns_topic**: Notifications for backup failures
- **local_file**: DR runbook documentation (optional)

## Implementation Steps

1. **Configure RDS Automated Backups** (`rds_backups.tf`)
   - Resource: Reference aws_db_instance from database module (update with backup settings)
   - Settings: `backup_retention_days`, `backup_window`
   - Output: Backup window and retention info for documentation

2. **Create AWS Backup Vault** (`backup_vault.tf`) - Optional centralized backup
   - Resource: `aws_backup_vault`
   - Encryption: AWS managed or KMS key
   - Locks: MFA delete protection (for prod)

3. **Create RDS Snapshot Schedule** (`rds_snapshots.tf`) - Conditional on `enable_rds_snapshots`
   - Resources: `aws_backup_plan`, `aws_backup_selection`
   - Or: `aws_lambda_function` + `aws_events_rule` (for manual snapshot control)
   - Input: `rds_snapshot_schedule` (cron)
   - Retention: `rds_snapshot_retention_days`

4. **Enable S3 Versioning** (`s3_versioning.tf`) - Conditional on `enable_s3_versioning`
   - Resource: `aws_s3_bucket_versioning` (from s3-frontend module)
   - Purpose: Enable recovery from accidental deletion/overwrite

5. **Configure S3 Lifecycle Policy** (`s3_lifecycle.tf`)
   - Resource: `aws_s3_bucket_lifecycle_configuration`
   - Policy: Delete noncurrent versions after `s3_version_retention_days`
   - Purpose: Cost optimization while maintaining recovery capability

6. **Create S3 Cross-Region Replication** (`s3_replication.tf`) - Conditional on `enable_s3_cross_region_replication`
   - Resources: `aws_s3_bucket_replication_configuration`, `aws_iam_role`, `aws_iam_role_policy`
   - Inputs: `s3_replica_bucket_name`, `s3_replica_region`
   - Destination: Replica bucket in different region
   - Replication: All objects or filtered by prefix

7. **Create RDS Cross-Region Backup Copy** (`rds_cross_region.tf`) - Conditional on `enable_rds_cross_region_backup`
   - Resources: `aws_backup_region_copy_plan` or Lambda + copy snapshots
   - Input: `rds_backup_destination_region`
   - Purpose: Protect against region-wide outages
   - Retention: Same as primary backups

8. **Create Backup Failure Alarms** (`alarms.tf`)
   - Resources: `aws_cloudwatch_metric_alarm` (per service)
   - Alarms: RDS backup failed, S3 replication lagging
   - Notifications: SNS topic for ops team

9. **Generate DR Runbook** (`runbook.tf`) - Conditional on `enable_dr_runbook`
   - Resource: `local_file` or template_file
   - Content: Recovery procedures for RDS and S3, estimated RTO/RPO
   - Output: `disaster_recovery_runbook_url`

## Security

### Access Control
- **RDS Backups**: AWS managed, encrypted with default key or custom KMS key
- **RDS Snapshots**: Manual snapshots encrypted, private (no public share)
- **S3 Replication**: Requires source bucket write, destination bucket read/write
- **Cross-Region Access**: VPC endpoint for backup copy (if applicable)

### Encryption
- **RDS Backups**: Encrypted at rest (AWS managed or KMS key)
- **S3 Backups**: Encrypted with SSE-S3 or SSE-KMS
- **Cross-Region Transfer**: Encrypted in transit (TLS)

### Audit Trail
- **AWS Backup**: All backup activities logged to CloudTrail
- **S3 Replication**: Replication metrics in CloudWatch
- **Manual Snapshots**: Tagged with creation date and purpose

## Testing

### Expected Behavior
- RDS automated backups enabled with specified retention
- Manual snapshots created on schedule
- S3 versioning enabled and working
- S3 replication (if enabled) successfully replicating objects
- Backup metrics and alarms in place
- DR runbook generated with recovery procedures

### Edge Cases
- Test RDS restore from backup: Create snapshot, restore to new instance
- Test S3 version recovery: Delete object, restore from previous version
- Verify backup encryption: Check snapshot encrypted property
- Test replication failover: Simulate primary region failure
- Validate alarm: Manually trigger backup failure


## Dependencies
- `database` module: RDS instance ID
- `s3-frontend` module: S3 bucket ID

## Module Integration Points
- Input `db_instance_id` from database module
- Input `s3_bucket_id` from s3-frontend module
- Output `disaster_recovery_runbook_url` for operational reference
- Output `recovery_metrics` for SLA tracking

## Disaster Recovery Strategy

### Recovery Point Objective (RPO) vs Recovery Time Objective (RTO)

| Layer | RPO | RTO | Method |
|-------|-----|-----|--------|
| **RDS Database** | 1 hour | 2-4 hours | Automated backups, restore to new instance |
| **S3 Frontend** | 15 minutes | 15 minutes | Cross-region replication + versioning |
| **ECS Services** | N/A | 10-15 minutes | Redeploy from source, ALB health checks |
| **Complete Infrastructure** | 24 hours | 4 hours | Automated Terraform/Terragrunt redeploy |

### Backup Strategy

**RDS**:
- Automated daily backups: 30-day retention
- Manual snapshots: Weekly (tag with week number)
- Cross-region: Optional copy to secondary region for DR

**S3**:
- Versioning: Enabled, old versions retained 90 days
- Cross-region replication: Real-time to secondary region
- Lifecycle: Transition to cheaper storage (Glacier) after 90 days

**Infrastructure Code**:
- Git repository: Single source of truth
- Terraform/Terragrunt state: S3 + DynamoDB locking
- State backups: Daily snapshot to secondary region

### Failover Procedures

#### RDS Single-AZ Failure
1. Detect: CloudWatch alarm (database unreachable)
2. Restore: `aws rds restore-db-instance-from-db-snapshot --db-snapshot-identifier snapshot-id`
3. Update: Point ECS tasks to new RDS endpoint (via Secrets Manager or new deployment)
4. Verify: Run integration tests

#### RDS Multi-AZ Failure (Automatic)
1. Detect: CloudWatch alarm (primary unhealthy)
2. AWS Auto-Failover: Promotes standby in ~1-2 minutes
3. Update: Automatic (application continues with same endpoint)
4. Verify: Monitor replication lag in CloudWatch

#### S3 Bucket Failure
1. Detect: CloudWatch alarm (S3 errors)
2. Failover: Update CloudFront origin to replica bucket (manual DNS change)
3. Verify: Test CloudFront distribution
4. Restore: Sync changes back to primary (after recovery)

#### Complete Infrastructure Failure (Region Down)
1. Detect: Multi-region monitoring/alerting
2. Prepare: Bring up replica infrastructure in secondary region
3. Deploy: `terragrunt run-all apply` in secondary region (using backed-up state)
4. Update: Point public DNS to secondary region ALB/CloudFront
5. Verify: Smoke tests, end-to-end validation

## DR Runbook Contents

The generated runbook includes:
- **Detection Procedures**: How to identify failures
- **Escalation Paths**: Who to notify at each severity level
- **Recovery Steps**: Step-by-step procedures for each failure scenario
- **Validation**: Tests to confirm recovery success
- **Communication**: Notification templates and contacts
- **Lessons Learned**: Post-incident review template

## Backup Inventory

### RDS Backups
- Location: AWS Backup vaults (multiple regions)
- Retention: 30 days automated, 90 days manual snapshots
- Cost: ~$0.05 per GB-month
- Restore Time: 5-15 minutes

### S3 Backups
- Location: Primary bucket (versioning) + secondary region (replication)
- Retention: 90 days for versions, lifecycle to Glacier
- Cost: ~$0.50 per GB-month (versioning) + replication transfer
- Restore Time: Immediate (versioning) or ~5 min (replication)

### Infrastructure Code
- Location: Git repository (GitHub/GitLab)
- Retention: Indefinite (version control)
- Restore Time: Minutes (terraform apply)

## Cost Estimation

| Component | Monthly Cost |
|-----------|--------------|
| RDS Backups (100 GB DB, 30-day retention) | $5 |
| RDS Manual Snapshots (500 GB, 90-day retention) | $25 |
| S3 Versioning (1 GB frontend) | $0.50 |
| S3 Cross-Region Replication | $1-5 (data transfer) |
| CloudWatch Alarms (5 alarms) | $1.50 |
| **Total** | ~$33/month |

## Notes
- Backups are encrypted by default (no additional cost)
- Test restore procedures quarterly (RTO/RPO validation)
- Keep DR runbook updated with team changes
- Cross-region replication one-way only (not bidirectional by default)
- Automated backups start 1-2 hours after DB creation
- Manual snapshots can be shared cross-account for disaster recovery
