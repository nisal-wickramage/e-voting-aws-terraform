# ECS Migration Task Module

## Purpose

Defines an ECS task definition for running database schema migrations on Fargate. Handles database credentials securely via Secrets Manager and provides a ready-to-run CLI command for migrations.

## Overview

This module creates:
- **ECS Task Definition**: Fargate-compatible task for running migrations
- **IAM Task Role**: Permissions for accessing Secrets Manager and CloudWatch
- **CloudWatch Logs**: Dedicated log group for migration output
- **CLI Helper**: Ready-to-run `aws ecs run-task` command

## Architecture

```
User/CI-CD
    ↓
aws ecs run-task (e-voting-migrations)
    ↓
ECS Fargate Task (awsvpc network mode)
    ├─ Pulls migration image from ECR
    ├─ Mounts RDS credentials (via env vars + Secrets Manager)
    ├─ Executes: python -m alembic upgrade head
    └─ Logs to CloudWatch Logs (/ecs/e-voting-migrations)
    ↓
RDS PostgreSQL (5432)
    ├─ Creates/updates schema tables
    ├─ Runs migration scripts
    └─ Commits transactions on success
```

## Inputs

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `cluster_name` | string | ✅ | ECS cluster name |
| `cluster_arn` | string | ✅ | ECS cluster ARN |
| `task_family_name` | string | | Task definition family (default: evoting-migrations) |
| `container_image` | string | ✅ | Container image URI (must include Alembic/migration tool) |
| `container_memory` | number | | Memory in MB (default: 512) |
| `container_cpu` | number | | CPU units (default: 256 = 0.25 vCPU) |
| `db_host` | string | ✅ | RDS endpoint |
| `db_port` | number | | RDS port (default: 5432) |
| `db_name` | string | ✅ | Database name |
| `db_username` | string | ✅ | Database username (sensitive) |
| `db_password` | string | ✅ | Database password (sensitive) |
| `ecs_task_execution_role_arn` | string | ✅ | ECS task execution IAM role ARN |
| `ecs_security_group_ids` | list(string) | ✅ | Security groups for task |
| `ecs_subnet_ids` | list(string) | ✅ | Subnets for task |
| `environment` | string | ✅ | dev/staging/prod |
| `project_name` | string | ✅ | Project name |
| `common_tags` | map(string) | | Common tags |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `task_definition_arn` | string | ECS task definition ARN |
| `task_family_name` | string | Task family name |
| `cloudwatch_log_group_name` | string | CloudWatch log group name |
| `task_role_arn` | string | IAM task role ARN |
| `run_migration_command` | string | Ready-to-run AWS CLI command |

## Usage

### 1. Create Task Definition

```hcl
module "ecs_migrations" {
  source = "./modules/ecs-migrations"

  # ECS Cluster
  cluster_name = module.platform.ecs_cluster_name
  cluster_arn  = module.platform.ecs_cluster_arn

  # Container
  container_image = "${var.ecr_repo_url}:latest"  # Image with Alembic

  # Database
  db_host     = module.database.rds_address
  db_port     = module.database.rds_port
  db_name     = "evoting"
  db_username = var.db_username
  db_password = var.db_password

  # Network
  ecs_task_execution_role_arn = module.platform.ecs_task_execution_role_arn
  ecs_security_group_ids      = [module.platform.ecs_security_group_id]
  ecs_subnet_ids              = module.network.private_subnet_ids_by_tier["app"]

  environment  = "dev"
  project_name = "e-voting"
}
```

### 2. Run Migrations

```bash
# Get the command from outputs
MIGRATION_CMD=$(terraform output -raw run_migration_command)

# Run it
eval $MIGRATION_CMD

# Or run manually:
aws ecs run-task \
  --cluster e-voting-cluster \
  --task-definition evoting-migrations \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx,subnet-yyy],securityGroups=[sg-zzz],assignPublicIp=DISABLED}" \
  --region us-east-1
```

### 3. Monitor Migration

```bash
# Get task ID from run-task output
TASK_ID="abc123def456"

# Check task status
aws ecs describe-tasks \
  --cluster e-voting-cluster \
  --tasks $TASK_ID

# View logs
aws logs tail /ecs/e-voting-migrations --follow
```

## Container Image Requirements

The container image must include:
1. **Alembic** (Python migration tool) or equivalent
2. **psycopg2** (PostgreSQL Python driver)
3. Migration scripts in `/app/alembic/versions/`

### Example Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

RUN pip install alembic psycopg2-binary

COPY alembic/ /app/alembic/
COPY alembic.ini /app/

ENV SQLALCHEMY_DATABASE_URL=""

CMD ["python", "-m", "alembic", "upgrade", "head"]
```

## Secrets Manager Integration

Database credentials are securely created and stored in AWS Secrets Manager by this module:

1. **Secret Creation**: Module creates `{project_name}-db-credentials` secret
2. **Secret Contents**: Stores username, password, host, port, dbname
3. **Task Access**: Container receives `DB_PASSWORD` environment variable injected from secret
4. **IAM Permission**: Task role has permission to read the secret

**Task Execution Flow:**
- Database module outputs: RDS connection details
- ECS-Migrations module inputs: DB connection parameters
- Module creates: Secrets Manager secret with all credentials
- Container receives: DB_PASSWORD environment variable from secret
- Task connects to RDS using credentials from Secrets Manager

**IAM Permission** (in ECS task role):
```json
{
  "Effect": "Allow",
  "Action": ["secretsmanager:GetSecretValue"],
  "Resource": "arn:aws:secretsmanager:*:*:secret:e-voting-db-credentials-*"
}
```

**Manual Access:**
```bash
aws secretsmanager get-secret-value --secret-id e-voting-db-credentials --query SecretString | jq .
```

## Security

- **Database Password**: Stored in Secrets Manager (referenced at runtime)
- **Environment Variables**: Passed as plaintext (safe in private VPC)
- **IAM Task Role**: Limited to CloudWatch logs and Secrets Manager
- **Network**: Runs in private subnets, no public internet access
- **Sensitive Outputs**: Password marked as sensitive in state

## Common Patterns

### Pattern 1: CI/CD Pipeline
```bash
# In GitHub Actions/GitLab CI/Jenkins
aws ecs run-task --cluster $ECS_CLUSTER --task-definition evoting-migrations
aws ecs wait tasks-stopped
```

### Pattern 2: Pre-deployment Check
```bash
# Run migrations before ECS service deployment
aws ecs run-task --cluster $ECS_CLUSTER --task-definition evoting-migrations
TASK_ID=$(jq -r '.tasks[0].taskArn' <<< output)
while true; do
  STATUS=$(aws ecs describe-tasks --cluster $ECS_CLUSTER --tasks $TASK_ID | jq -r '.tasks[0].lastStatus')
  if [[ $STATUS == "STOPPED" ]]; then break; fi
  sleep 10
done
```

### Pattern 3: Manual Override
```bash
# Run custom migration command
aws ecs run-task \
  --cluster e-voting-cluster \
  --task-definition evoting-migrations \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-zzz]}" \
  --overrides '{"containerOverrides":[{"name":"migrations","command":["python","-m","alembic","downgrade","base"]}]}'
```

## Troubleshooting

**Task fails to start**:
- Check security group allows egress to RDS (5432)
- Verify IAM execution role has `ecr:GetAuthorizationToken` and `ecr:BatchGetImage`
- Check CloudWatch logs: `aws logs tail /ecs/e-voting-migrations`

**Connection refused**:
- Verify RDS is running: `aws rds describe-db-instances`
- Check security group rule: `aws ec2 describe-security-groups --group-ids sg-xxx`
- Verify database credentials are correct

**Task times out**:
- Increase `container_cpu` and `container_memory`
- Check migration scripts for long-running operations
- Monitor CloudWatch logs for stuck migrations

## Future Enhancements

- [ ] Automatic pre-deployment migration runs
- [ ] Dry-run mode for testing migrations
- [ ] Multi-step migration strategy (staging → prod)
- [ ] Rollback automation on migration failure
- [ ] Email/Slack notifications on migration completion
- [ ] Integration with AWS CodePipeline for automated deployments
