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

### LocalStack Testing
```bash
# Start LocalStack
docker run -d -p 4566:4566 -e SERVICES=rds,ec2 localstack/localstack:4.4.0

# Configure
export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"

# Test
tofu init
tofu plan -var="ecs_security_group_id=sg-12345" \
          -var="private_subnet_ids=[\"subnet-1\",\"subnet-2\"]"
tofu apply -auto-approve

# Validate
aws --endpoint-url=http://localhost:4566 rds describe-db-instances
aws --endpoint-url=http://localhost:4566 rds describe-db-security-groups

# Destroy
tofu destroy -auto-approve
```

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
