# E-Voting AWS Infrastructure — AI Agent Guide

## Project Overview

**Purpose**: Deploy a highly available, scalable microservices architecture on AWS with a single `tofu apply` command.

**Tech Stack**: OpenTofu, ECS Fargate compute, RDS PostgreSQL, CloudFront + WAF for public exposure

**Key Architecture Decision**: Private-only subnets (no IGW in data plane). All traffic flows through CloudFront (frontend/API) or NAT gateways (egress).

## Verified AWS Design

✅ **CloudFront VPC Origins** support private ALBs — provides direct VPC origin connectivity without internet exposure
✅ **ECS Fargate in Private Subnets** — standard pattern with NAT gateways for ECR pulls, log streaming, and external API calls
✅ **RDS Multi-AZ in Private Subnets** — best practice for production databases with security group isolation

See AWS docs: [VPC origins](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-vpc-origins.html), [ECS best practices](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-networking.html)

## Module Structure & Dependency Graph

All modules are deployed together in dependency order via a single root `main.tf`:

```
1. network                    (No dependencies)
   ├─ VPC, subnets, NACL, route tables
   ├─ VPC endpoints (ECR, S3, CloudWatch Logs, Secrets Manager)
   └─ NAT gateways for private egress

2. database                   (Depends: network)
   ├─ RDS subnet group
   ├─ RDS PostgreSQL cluster (Multi-AZ)
   └─ Security group allowing ECS ingress

3. cluster                    (Depends: network)
   ├─ ECS cluster (Fargate)
   ├─ ALB in private subnets
   └─ Security groups (ALB ← CloudFront, ECS ← ALB)

4. ecs-api                    (Depends: cluster, database)
   ├─ Task definition for API service
   ├─ ECS service
   └─ ALB listener rules & target groups

5. s3-frontend                (Depends: network)
   ├─ S3 bucket (private, versioning)
   └─ Bucket policy (CloudFront-only access)

6. cdn-waf                    (Depends: cluster, s3-frontend)
   ├─ WAF rules (rate limiting, geo-blocking, etc.)
   ├─ CloudFront distribution (VPC origin → ALB)
   └─ CloudFront distribution (S3 origin → frontend)

7. disaster-recovery          (Depends: database, s3-frontend)
   ├─ RDS automated backups + snapshots
   ├─ S3 versioning + cross-region replication
   └─ Recovery procedures/runbooks
```

## OpenTofu Project Structure

### Module Locations
```
tofu/
├── modules/
│   ├── network/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── vpc.tf
│   │   ├── subnets.tf
│   │   ├── vpc_endpoints.tf
│   │   └── README.md
│   ├── cluster/
│   ├── database/
│   ├── ecs-api/
│   ├── s3-frontend/
│   ├── cdn-waf/
│   └── disaster-recovery/
```

### Root Configuration
```
e-voting-aws-terraform/
├── main.tf                   # Module orchestration (7 modules)
├── variables.tf              # Input variables for all modules
├── outputs.tf                # Aggregated outputs
├── locals.tf                 # Common values (tags, etc.)
├── terraform.tf              # Provider & backend config
└── tofu/modules/             # Reusable modules
```

### Key Patterns

**Remote State**: S3 backend with DynamoDB locking (configured in `terraform.tf`)

**Input Variables**: Global variables in root `variables.tf` passed to all modules

**Dependencies**: Module dependencies defined in root `main.tf` with explicit `depends_on` blocks:
```hcl
module "database" {
  source = "./tofu/modules/database"
  
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids_by_tier["db"]
  
  depends_on = [module.network]
}
```

**Locals**: Common values in `locals.tf`:
```hcl
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    CreatedAt   = timestamp()
  }
}
```

## Module Development Workflow

### 1. Define Module Spec
Create `SPEC.md` in module directory with the following structure:
- **Purpose**: 1-2 line summary
- **Implementation Steps**: Numbered, granular steps for building the module
- **Inputs**: Variable names, types, descriptions
- **Outputs**: Output names, descriptions
- **Resources**: List of AWS resources created
- **Security**: Security group rules, IAM policies
- **Testing**: Expected behavior, edge cases

### 2. Implement Module
- Start with `variables.tf` (define all inputs with validation)
- Follow implementation steps in order
- Implement resources in domain-specific files (main.tf, subnets.tf, nacls.tf, etc.)
- Define `outputs.tf` (must match spec outputs)
- Add comments for each step's purpose
- Use consistent naming: `aws_<resource>_<descriptor>` (e.g., `aws_security_group_vpc_endpoints`)

### 3. Add Module to Root main.tf
Once a module is complete:
1. Add module block in `main.tf` with proper dependency ordering
2. Pass required variables from `variables.tf`
3. Reference outputs from dependent modules using `module.<name>.output.<value>`
4. Run `tofu plan` to validate the integration
5. Test with `tofu apply` in dev environment

### 4. Testing Strategy

**Unit Tests (Module-level)**
- Test individual module in isolation
- Verify outputs are populated correctly
- Check security group rules and IAM policies

**Integration Tests (Full Stack)**
- Deploy entire infrastructure with `tofu apply`
- Verify cross-module connectivity (RDS reachable from ECS, etc.)
- Test failover behavior for Multi-AZ resources
- Run smoke tests against deployed services

## Development Conventions

### Naming
- **Resources**: `aws_<type>_<descriptor>` (e.g., `aws_security_group_alb`)
- **Variables**: `snake_case` (e.g., `enable_enhanced_monitoring`)
- **Locals**: `snake_case` (e.g., `common_tags`)
- **Outputs**: `descriptive_identifier` (e.g., `rds_cluster_endpoint`)

### Tagging
All resources tagged with:
```hcl
tags = merge(
  var.common_tags,
  {
    Name = "${var.project_name}-${var.environment}-${local.component_name}"
  }
)
```

Common tags applied globally via provider default_tags in `terraform.tf`.

### Outputs
Always provide:
1. **Primary Output** (e.g., VPC ID, RDS endpoint)
2. **IDs for Cross-References** (e.g., security group IDs)
3. **Metadata for Debugging** (e.g., availability zones, subnet CIDR blocks)

### Documentation
- Add `README.md` to each module explaining purpose, inputs, outputs
- Use comments for complex logic (e.g., conditional resource creation)
- Document security group rules: why each ingress/egress rule exists
- Keep SPEC.md updated with implementation details

## Deployment Workflow

### Development Environment

1. **Configure Backend**:
   ```bash
   aws s3 mb s3://evoting-terraform-state-dev
   aws dynamodb create-table \
     --table-name terraform-locks \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST
   ```

2. **Initialize**:
   ```bash
   tofu init \
     -backend-config="bucket=evoting-terraform-state-dev" \
     -backend-config="key=dev.tfstate" \
     -backend-config="region=us-east-1" \
     -backend-config="dynamodb_table=terraform-locks"
   ```

3. **Plan & Apply**:
   ```bash
   tofu plan -out=tfplan
   tofu apply tfplan
   ```

4. **Verify**:
   ```bash
   tofu output infrastructure_summary
   ```

### Staging/Production

Repeat steps above for staging/prod environments, using different state buckets and tfvars files.

## Common Pitfalls & Solutions

| Pitfall | Cause | Solution |
|---------|-------|----------|
| **State Lock Timeout** | DynamoDB throttling or stale lock | Increase DynamoDB capacity; use `force-unlock` sparingly |
| **NAT Gateway Cost Overruns** | Hourly charges + data transfer | Monitor with CloudWatch; use VPC endpoints for AWS services |
| **ECS Task Failures** | Missing VPC endpoint or IAM role | Pre-validate VPC endpoints; use task role for Secrets Manager |
| **Module Output Not Found** | Typo in module reference | Verify module name and output name in `main.tf` |
| **RDS Multi-AZ Failures** | Subnets span only 1 AZ | Verify DB subnet group covers ≥2 AZs; test failover |
| **CloudFront Can't Reach ALB** | ALB security group too restrictive | Verify ALB allows ingress from CloudFront security group |

## Environment-Specific Behavior

### Dev
- Smaller instance types (cost optimization)
- Single-AZ deployments acceptable (RDS single-AZ OK for dev)
- Minimal monitoring (CloudWatch alarms only on critical resources)
- Example tfvars:
  ```hcl
  environment = "dev"
  db_instance_class = "db.t3.micro"
  desired_count = 1
  ```

### Staging
- Production-like sizes (validate performance)
- Multi-AZ deployments
- Full monitoring suite
- Example tfvars:
  ```hcl
  environment = "staging"
  db_instance_class = "db.t3.small"
  desired_count = 2
  ```

### Prod
- Rightsized instances (validated by staging)
- Multi-AZ mandatory (all stateful services)
- Enhanced monitoring (detailed CloudWatch logs)
- Disaster recovery enabled (RDS automated backups, S3 cross-region replication)
- Example tfvars:
  ```hcl
  environment = "prod"
  db_instance_class = "db.t3.medium"
  desired_count = 3
  enable_cross_region_replication = true
  ```

## Setup Instructions

See [README.md](./README.md#deployment-steps) for quick-start: OpenTofu installation and deployment.

## Key Files to Review

- **AWS Architecture**: [README.md](./README.md#aws-architecture-diagram)
- **Quick Start**: [README.md](./README.md#quick-start)
- **Module Specs**: `tofu/modules/[MODULE]/SPEC.md`
- **Module READMEs**: `tofu/modules/[MODULE]/README.md`
- **Root Configuration**: `main.tf`, `variables.tf`, `outputs.tf`
