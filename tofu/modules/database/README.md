# Database Module

## Purpose

Creates a production-ready RDS PostgreSQL database in private subnets with multi-AZ high availability, automated backups, and monitoring.

## Overview

This module provisions:
- **RDS PostgreSQL**: db.t3.micro (smallest, cost-optimized for dev)
- **DB Subnet Group**: Multi-AZ placement in private subnets
- **Security Group**: Restricted access from ECS tasks only
- **Parameter Group**: PostgreSQL 15 with audit logging
- **Monitoring**: CloudWatch alarms for low storage

## Inputs

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `vpc_id` | string | - | VPC ID from network module |
| `private_subnet_ids` | list(string) | - | Database subnets (≥2 for HA) |
| `ecs_security_group_id` | string | - | ECS tasks SG for database access |
| `db_instance_class` | string | `db.t3.micro` | RDS instance size |
| `db_allocated_storage` | number | `20` | Storage in GB (minimum 20) |
| `db_name` | string | `evoting` | Initial database name |
| `db_username` | string | `postgres` | Master username |
| `db_password` | string | - | Master password (8+ chars) |
| `db_backup_retention_days` | number | `7` | Backup retention (1-35 days) |
| `db_multi_az` | bool | `true` | Multi-AZ deployment |
| `db_skip_final_snapshot` | bool | `true` | Skip final snapshot (dev only) |
| `environment` | string | - | dev/staging/prod |
| `project_name` | string | - | Project name |
| `common_tags` | map(string) | `{}` | Common tags |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `rds_endpoint` | string | RDS endpoint (host:port) |
| `rds_address` | string | RDS host address |
| `rds_port` | number | RDS port (5432) |
| `rds_identifier` | string | RDS instance ID |
| `rds_security_group_id` | string | RDS SG ID |
| `connection_string` | string | PostgreSQL connection URI |

## Architecture

- **Engine**: PostgreSQL 15.4
- **Instance**: db.t3.micro (1 vCPU, 1 GB RAM)
- **Storage**: 20 GB SSD (gp3)
- **High Availability**: Multi-AZ with automatic failover
- **Backups**: 7-day retention with automated snapshots
- **Access**: Private subnets only, restricted by security group
- **Logging**: PostgreSQL logs exported to CloudWatch Logs

## Security

- No public internet access
- Inbound 5432 only from ECS security group
- Master password stored as sensitive in state
- Audit logging enabled (ddl for prod, all for dev)
- Encrypted snapshots (default encryption)

## Cost Optimization

- **Dev**: db.t3.micro (~$0.018/hour), 20 GB storage (~$2/month)
- **Staging**: db.t3.small (~$0.042/hour), 50 GB storage
- **Prod**: db.t3.medium (~$0.084/hour), 100 GB storage

Total dev cost: ~$15-20/month

## Usage

```hcl
module "database" {
  source = "./modules/database"

  vpc_id                    = module.network.vpc_id
  private_subnet_ids        = module.network.private_subnet_ids_by_tier["db"]
  ecs_security_group_id     = module.platform.ecs_security_group_id
  
  db_instance_class         = "db.t3.micro"
  db_allocated_storage      = 20
  db_password               = var.db_password  # Pass via tfvars or env
  
  environment   = "dev"
  project_name  = "e-voting"

  common_tags = {
    Environment = "dev"
    Project     = "e-voting"
    ManagedBy   = "terragrunt"
  }
}
```

## Dependencies

- **network module**: VPC and subnets (must be created first)
- **platform module**: ECS security group (must be created first)

## Monitoring

CloudWatch alarms created for:
- **Low Storage**: Alert when free space < 10% of allocated

Metrics exported:
- CPU Utilization
- Database Connections
- Read/Write Latency
- Storage Space

## Troubleshooting

**RDS creation fails**: Verify network module deployed and subnets available
**ECS can't connect**: Check security group rule allows ECS → RDS (5432)
**High latency**: Consider upgrading to db.t3.small or db.t4g.medium
**Storage filling**: Enable auto-scaling or increase allocated_storage

## Disaster Recovery

- **Automated Backups**: 7-day retention (configurable)
- **Manual Snapshots**: Create via console or API
- **Multi-AZ Failover**: Automatic in case of primary failure (~1-2 minutes)
- **Cross-region**: Manual replication to standby region (future)

## Future Enhancements

- [ ] Cross-region read replicas
- [ ] Enhanced monitoring with Performance Insights
- [ ] Parameter group customization via inputs
- [ ] Custom backup windows
- [ ] RDS proxy for connection pooling
