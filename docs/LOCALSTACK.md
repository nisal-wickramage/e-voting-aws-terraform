# LocalStack Deployment Guide

## Overview

This guide explains how to deploy the e-voting infrastructure to LocalStack for local testing and development.

## Prerequisites

- **LocalStack 4.4.0** running on `localhost:4566`
- **OpenTofu** v1.0+ installed
- **Terragrunt** v0.54.5+ installed
- **macOS/Linux** terminal

## Quick Start

### 1. Start LocalStack

```bash
docker run -d --name localstack \
  -p 4566:4566 \
  -e DOCKER_HOST=unix:///var/run/docker.sock \
  localstack/localstack:4.4.0

# Verify it's running
curl http://localhost:4566/_localstack/health
```

### 2. Configure LocalStack Credentials

```bash
# Option 1: Source the setup script (recommended)
cd /Users/nisal/Documents/git-repos/e-voting-aws-terraform
source .localstack-setup.sh

# Option 2: Set manually
export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_REGION="us-east-1"
```

### 3. Deploy Network Module (Step 1)

```bash
cd terragrunt/dev/network
terragrunt plan
terragrunt apply -auto-approve
```

### 4. Verify Deployment

```bash
# Check VPC creation
aws --endpoint-url=http://localhost:4566 ec2 describe-vpcs

# Check state file
ls -la .terraform/terraform.tfstate
```

## Deployment Order

1. **network** - VPC, subnets, route tables, NACLs, VPC endpoints
2. **database** - RDS (depends on network)
3. **platform** - ECS cluster, ALB (depends on network)
4. **ecs-services** - Services, task definitions (depends on platform + database)
5. **s3-frontend** - Frontend bucket (depends on network)
6. **cdn-waf** - CloudFront, WAF (depends on platform + s3-frontend)
7. **monitoring** - CloudWatch alarms (depends on all)
8. **disaster-recovery** - Backups, replication (depends on database + s3-frontend)

## Module Implementation Status

### ✓ Complete
- **network/Step 1** - VPC creation ✓

### 🔄 In Progress
- **network/Steps 2-9** - Subnets, route tables, NACLs, VPC endpoints

### ⏸ Pending
- database, platform, ecs-services, s3-frontend, cdn-waf, monitoring, disaster-recovery

## Testing Full Environment

To deploy entire dev environment:

```bash
source .localstack-setup.sh
cd terragrunt/dev

# Plan all modules
terragrunt run-all plan

# Apply all modules (sequential)
terragrunt run-all apply -auto-approve

# Destroy all (cleanup)
terragrunt run-all destroy -force
```

## Troubleshooting

### Credentials Error

```
Error: No valid credential sources found
```

**Solution**: Make sure you've sourced the environment setup:
```bash
source .localstack-setup.sh
```

### LocalStack Not Running

```
Error: connection refused
```

**Solution**: Verify LocalStack is healthy:
```bash
curl http://localhost:4566/_localstack/health
```

### Stale Terraform State

```
tofu init
tofu get -update
terragrunt plan
```

### Cleanup LocalStack

```bash
docker stop localstack
docker rm localstack

# Full cleanup with volumes
docker volume prune -f
```

## Environment Variables

**LocalStack Configuration**:
- `AWS_ENDPOINT_URL=http://localhost:4566` - LocalStack endpoint
- `AWS_ACCESS_KEY_ID=test` - Dummy credentials (any value works)
- `AWS_SECRET_ACCESS_KEY=test` - Dummy credentials (any value works)
- `AWS_REGION=us-east-1` - AWS region

**Terragrunt**:
- `ENVIRONMENT=dev` - Environment selector (dev/staging/prod)

**OpenTofu**:
- `TF_LOG=DEBUG` - Enable debug logging
- `TF_LOG_PATH=/tmp/tf-debug.log` - Log file location

## Architecture in LocalStack

The deployed architecture in LocalStack mirrors the production design:

```
┌─────────────────────────────────────┐
│  LocalStack (localhost:4566)        │
├─────────────────────────────────────┤
│  VPC: 10.0.0.0/16                  │
│  ├─ Web Tier Subnets                │
│  ├─ App Tier Subnets                │
│  ├─ DB Tier Subnets                 │
│  └─ VPC Endpoints                   │
│      ├─ ECR (ecr.api, ecr.dkr)     │
│      ├─ S3 (gateway)                │
│      ├─ CloudWatch Logs             │
│      └─ Secrets Manager             │
└─────────────────────────────────────┘
```

## Next Steps

1. Implement network module Steps 2-9 (subnets, route tables, NACLs)
2. Implement database module
3. Implement platform module (ECS cluster, ALB)
4. Implement ecs-services module
5. Deploy to staging for validation
6. Deploy to production

## Useful Commands

```bash
# View current outputs
terragrunt output -all

# View specific module output
cd terragrunt/dev/network
terragrunt output vpc_id

# Validate infrastructure
tofu validate

# Format code
tofu fmt -recursive

# Show state
tofu show

# Inspect LocalStack services
curl http://localhost:4566/_localstack/health | jq .
```

## Reference

- [LocalStack Documentation](https://docs.localstack.cloud/)
- [OpenTofu Documentation](https://opentofu.org/docs/)
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/)
- See AGENTS.md for detailed module implementation patterns
