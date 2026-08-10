# Database Module Specification

## Purpose
Create a production-grade RDS PostgreSQL Multi-AZ cluster with automated backups, monitoring role, and security isolation for microservices access.

## Inputs

| Variable | Type | Description | Required | Example |
|----------|------|-------------|----------|---------|
| `vpc_id` | string | VPC ID from network module | Yes | (from dependency) |
| `private_subnet_ids` | list(string) | Private subnet IDs for DB subnet group | Yes | (from dependency) |
| `db_name` | string | Initial database name | Yes | `"evoting_db"` |
| `db_master_username` | string | Master database username | Yes | `"postgres"` |
| `db_master_password` | string | Master database password (use Secrets Manager in prod) | Yes | (from variable/secrets) |
| `db_instance_class` | string | RDS instance type | Yes | `"db.t3.micro"` (dev), `"db.r5.large"` (prod) |
| `db_allocated_storage` | number | Storage in GB | Yes | `20` |
| `db_engine_version` | string | PostgreSQL version | No | `"15.4"` |
| `db_backup_retention_days` | number | Backup retention days | No | `7` |
| `enable_multi_az` | bool | Enable Multi-AZ deployment | Yes | `true` |
| `enable_enhanced_monitoring` | bool | Enable enhanced monitoring | No | `true` |
| `environment` | string | Environment name (dev/staging/prod) | Yes | `"dev"` |
| `project_name` | string | Project name for resource tagging | Yes | `"e-voting"` |
| `enable_automatic_backups` | bool | Enable automated backups | Yes | `true` |
| `backup_window` | string | Backup window (UTC) | No | `"03:00-04:00"` |
| `maintenance_window` | string | Maintenance window | No | `"mon:04:00-mon:05:00"` |
| `ecs_security_group_id` | string | Security group ID of ECS tasks for ingress rule | Yes | (from platform module) |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `db_instance_id` | string | RDS instance identifier |
| `db_instance_arn` | string | RDS instance ARN |
| `db_instance_endpoint` | string | RDS writer endpoint (host:port) |
| `db_instance_address` | string | RDS writer endpoint hostname only |
| `db_instance_port` | number | RDS port (default 5432) |
| `db_instance_resource_id` | string | AWS resource ID |
| `db_subnet_group_id` | string | DB subnet group identifier |
| `db_subnet_group_arn` | string | DB subnet group ARN |
| `db_security_group_id` | string | Security group ID for RDS |
| `db_parameter_group_id` | string | Parameter group identifier |
| `db_monitoring_role_arn` | string | IAM role ARN for enhanced monitoring |
| `db_name` | string | Database name |
| `db_username` | string | Database master username |
| `db_availability_zones` | list(string) | AZs where RDS is deployed |
| `db_backup_retention_days` | number | Backup retention period |

## Resources

- **aws_db_subnet_group**: Defines subnets for RDS (must span 2+ AZs)
- **aws_rds_cluster_instance**: Primary and standby instances (Multi-AZ)
- **aws_security_group**: Allows ECS task security group ingress on port 5432
- **aws_db_parameter_group**: PostgreSQL configuration
- **aws_iam_role**: Enhanced monitoring role
- **aws_iam_role_policy_attachment**: Attach monitoring policy
- **aws_rds_cluster_parameter_group**: Cluster-level parameters

## Implementation Steps

1. **Create DB Subnet Group** (`main.tf`)
   - Resource: `aws_db_subnet_group`
   - Input: `private_subnet_ids` from network module
   - Validation: Must span 2+ availability zones
   - Output: `db_subnet_group_id`, `db_subnet_group_arn`

2. **Create Security Group for RDS** (`security.tf`)
   - Resource: `aws_security_group`
   - Rules: Inbound TCP 5432 from ECS security group only
   - Input: `vpc_id`, `ecs_security_group_id`
   - Output: `db_security_group_id`

3. **Create DB Parameter Group** (`parameters.tf`) - Optional: customizable
   - Resource: `aws_db_parameter_group`
   - Configuration: PostgreSQL version-specific, SSL enforcement
   - Output: `db_parameter_group_id`

4. **Create IAM Role for Enhanced Monitoring** (`monitoring.tf`) - Conditional on `enable_enhanced_monitoring`
   - Resources: `aws_iam_role`, `aws_iam_role_policy_attachment`
   - Policy: `AmazonRDSEnhancedMonitoringRolePolicy`
   - Output: `db_monitoring_role_arn`

5. **Create RDS Instance** (`main.tf`)
   - Resource: `aws_db_instance` or `aws_rds_cluster_instance`
   - Inputs: `db_name`, `db_master_username`, `db_master_password`, `db_instance_class`, `db_allocated_storage`
   - Multi-AZ: `enable_multi_az = true`
   - Backup: `backup_retention_days`, `backup_window`
   - Monitoring: Link to role from step 4
   - Outputs: `db_instance_endpoint`, `db_instance_address`, `db_instance_port`
   - Dependencies: Subnet group (step 1), Security group (step 2), Parameter group (step 3), Monitoring role (step 4)

## Security

### Security Group Rules
- **Inbound**: Allow TCP 5432 from ECS security group only
- **Outbound**: Allow all (for snapshots, backups)
- **No direct internet access**: Private subnets only

### IAM Policies
- Enhanced monitoring role: `AmazonRDSEnhancedMonitoringRole` policy
- No public accessibility flag set

### Encryption
- Encryption at rest: Enabled (AWS managed key)
- Encryption in transit: Required (SSL)
- Backup encryption: Enabled

### Database Configuration
- Master user: No wildcard permissions
- Parameter group: Enforce SSL connections
- Multi-AZ: Automatic failover enabled
- Automated backups: Enabled with retention policy

## Testing

### Expected Behavior
- RDS instance created in both AZs (standby)
- Security group allows ECS ingress, blocks public access
- Database reachable from ECS tasks via private endpoint
- Automated backups created on schedule
- Parameter group applied correctly
- Enhanced monitoring metrics available in CloudWatch

### Edge Cases
- Test failover to standby (manual reboot with failover)
- Verify backup restoration works
- Test security group rule: ingress from ECS only
- Validate parameter group: SSL required
- Check subnet group spans correct AZs


## Dependencies
- `network` module: VPC ID, private subnet IDs
- `platform` module: ECS security group ID

## Module Integration Points
- Input `private_subnet_ids` from network module
- Input `ecs_security_group_id` from platform module
- Output `db_instance_endpoint` consumed by ecs-services module
- Output `db_security_group_id` for cross-module reference

## Notes
- Multi-AZ failover typically takes 1-2 minutes
- Backup window should not overlap with maintenance window
- Consider read replicas for read-heavy workloads (not in this module)
- RDS Proxy can improve connection pooling (future module)
- Secrets Manager recommended for password rotation in production
