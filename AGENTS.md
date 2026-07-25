# E-Voting AWS Infrastructure — AI Agent Guide

## Project Overview

**Purpose**: Deploy a highly available, scalable microservices architecture on AWS with minimal blast radius and progressive module development.

**Tech Stack**: OpenTofu + Terragrunt orchestration, ECS Fargate compute, RDS PostgreSQL, CloudFront + WAF for public exposure

**Key Architecture Decision**: Private-only subnets (no IGW in data plane). All traffic flows through CloudFront (frontend/API) or NAT gateways (egress).

## Verified AWS Design

✅ **CloudFront VPC Origins** support private ALBs — provides direct VPC origin connectivity without internet exposure
✅ **ECS Fargate in Private Subnets** — standard pattern with NAT gateways for ECR pulls, log streaming, and external API calls
✅ **RDS Multi-AZ in Private Subnets** — best practice for production databases with security group isolation

See AWS docs: [VPC origins](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-vpc-origins.html), [ECS best practices](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-networking.html)

## Module Structure & Dependency Graph

Modules are designed for independent deployment and testing. Deploy in this order:

```
1. network                    (No dependencies)
   ├─ VPC, subnets, NACL, route tables
   ├─ VPC endpoints (ECR, S3, CloudWatch Logs, Secrets Manager)
   └─ NAT gateways for private egress

2. database                   (Depends: network)
   ├─ RDS subnet group
   ├─ RDS PostgreSQL cluster (Multi-AZ)
   └─ Security group allowing ECS ingress

3. platform                   (Depends: network)
   ├─ ECS cluster (Fargate)
   ├─ ALB in private subnets
   └─ Security groups (ALB ← CloudFront, ECS ← ALB)

4. ecs-services               (Depends: platform, database)
   ├─ Task definitions + ECR repos (per service)
   ├─ ECS services
   └─ ALB listener rules & target groups

5. s3-frontend                (Depends: network)
   ├─ S3 bucket (private, versioning)
   └─ Bucket policy (CloudFront-only access)

6. cdn-waf                    (Depends: platform, s3-frontend)
   ├─ WAF rules (rate limiting, geo-blocking, etc.)
   ├─ CloudFront distribution (VPC origin → ALB)
   └─ CloudFront distribution (S3 origin → frontend)

7. monitoring                 (Depends: platform, database)
   ├─ CloudWatch alarms (ECS, RDS, ALB)
   └─ Dashboards

8. disaster-recovery          (Depends: database, s3-frontend)
   ├─ RDS automated backups + snapshots
   ├─ S3 versioning + cross-region replication
   └─ Recovery procedures/runbooks
```

## OpenTofu + Terragrunt Conventions

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
│   └── [other modules follow same pattern]
│
└── global/
    ├── variables.tf
    ├── locals.tf
    └── outputs.tf
```

### Terragrunt Layout
```
terragrunt/
├── terragrunt.hcl                    # Root config (common settings, path helpers)
├── dev/
│   ├── terragrunt.hcl
│   ├── network/terragrunt.hcl
│   ├── database/terragrunt.hcl
│   └── [other services]
├── staging/
│   └── [same structure]
└── prod/
    └── [same structure]
```

### Key Patterns

**Remote State**: Each module's state stored in S3 with DynamoDB locking (configured in root `terragrunt.hcl`)

**Input Variables**: Module `variables.tf` defines inputs; Terragrunt `terragrunt.hcl` provides values via `inputs {}` block

**Dependencies**: Use `dependency` blocks in Terragrunt to reference outputs from other modules:
```hcl
dependency "network" {
  config_path = "../network"
  mock_outputs = { vpc_id = "vpc-fake" }
}

inputs = {
  vpc_id = dependency.network.outputs.vpc_id
}
```

**Locals**: Reusable values in `terragrunt.hcl`:
```hcl
locals {
  environment = "dev"
  region      = "us-east-1"
  tags = {
    Environment = local.environment
    Project     = "e-voting"
    ManagedBy   = "terragrunt"
  }
}
```

## Module Development Workflow

### 1. Define Module Spec
Create `SPEC.md` in module directory with the following structure:
- **Purpose**: 1-2 line summary
- **Implementation Steps**: Numbered, granular steps for building the module (see examples below)
- **Inputs**: Variable names, types, descriptions
- **Outputs**: Output names, descriptions
- **Resources**: List of AWS resources created
- **Security**: Security group rules, IAM policies
- **Testing**: Expected behavior, edge cases

### 2. Implementation Steps Pattern
Each module SPEC.md should include detailed implementation steps. Example for **Network Module**:

```
## Implementation Steps

1. **Create VPC**
   - Resource: aws_vpc
   - Inputs: vpc_cidr, enable_dns_hostnames, enable_dns_support
   - Output: vpc_id
   - File: main.tf

2. **Create VPC Endpoints Security Group**
   - Resource: aws_security_group
   - Rules: Inbound HTTPS (443) from VPC CIDR
   - Output: vpc_endpoint_sg_id
   - File: main.tf

3. **Create Tier-based Subnets**
   - Resources: aws_subnet (6 total: 2 web, 2 app, 2 db)
   - Logic: for_each over subnets_by_tier local
   - Inputs: availability_zones, private_subnet_cidrs
   - Output: private_subnet_ids_by_tier
   - File: subnets.tf

4. **Create Tier-specific Route Tables**
   - Resources: aws_route_table (3 total: web, app, db)
   - Logic: One per tier with VPC CIDR local route
   - Output: private_route_table_ids_by_tier
   - File: route_tables.tf

5. **Associate Subnets to Route Tables**
   - Resources: aws_route_table_association (6 total)
   - Logic: for_each web/app/db subnets
   - Dependencies: Subnets (step 3), Route tables (step 4)
   - File: route_tables.tf

6. **Create Tier-specific Network ACLs**
   - Resources: aws_network_acl (3 total)
   - Logic: Inline subnet_ids association
   - Output: nacl_ids_by_tier
   - File: nacls.tf

7. **Define NACL Rules**
   - Resources: aws_network_acl_rule (multiple)
   - Logic: for_each over tier CIDR blocks for dynamic rules
   - Rules per tier:
     - Web: inbound from app (1024-65535), outbound to app (8080-65535), HTTPS, DNS
     - App: inbound from web (1024-65535), outbound to db (5432), HTTPS, DNS
     - Db: inbound from app (5432), outbound HTTPS, DNS
   - File: nacls.tf

8. **Create VPC Endpoints**
   - Resources: aws_vpc_endpoint (gateway + interface)
   - Logic: Separate gateway (s3, dynamodb) from interface endpoints via locals
   - Placement: App tier subnets only
   - Output: vpc_endpoint_ids
   - File: vpc_endpoints.tf

9. **Optional: VPC Flow Logs**
   - Resources: aws_flow_log, aws_cloudwatch_log_group, aws_iam_role, aws_iam_role_policy
   - Condition: if var.enable_flow_logs == true
   - File: main.tf
```

### 3. Implement Module
- Start with `variables.tf` (define all inputs with validation)
- Follow implementation steps in order (each step is typically one file or logical grouping)
- Implement resources in domain-specific files (main.tf, subnets.tf, nacls.tf, etc.)
- Define `outputs.tf` (must match spec outputs)
- Add comments for each step's purpose
- Use consistent naming: `aws_<resource>_<descriptor>` (e.g., `aws_security_group_vpc_endpoints`)

### 4. Test with LocalStack

**Prerequisites**: Docker running, LocalStack v4.4.0 installed

**Test Steps**:
```bash
# 1. Start LocalStack
docker run -d -p 4566:4566 \
  -e SERVICES=ec2,rds,s3,elasticloadbalancing,ecs,cloudwatch \
  localstack/localstack:4.4.0

# 2. Configure OpenTofu to use LocalStack
export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_REGION="us-east-1"

# 3. Initialize and test module
tofu init
tofu plan
tofu apply -auto-approve

# 4. Validate resources
aws --endpoint-url=http://localhost:4566 ec2 describe-vpcs
aws --endpoint-url=http://localhost:4566 rds describe-db-instances

# 5. Destroy and cleanup
tofu destroy -auto-approve
docker stop $(docker ps -q --filter "ancestor=localstack/localstack:4.4.0")
```

### 4. Integrate into Terragrunt
- Create environment-specific `terragrunt.hcl`
- Use `dependency` blocks for cross-module references
- Run `terragrunt run-all plan` to validate entire environment
- Test in dev first, then staging, then prod

## Development Conventions

### Naming
- **Resources**: `aws_<type>_<descriptor>` (e.g., `aws_security_group_alb`)
- **Variables**: `snake_case` (e.g., `enable_enhanced_monitoring`)
- **Locals**: `snake_case` (e.g., `common_tags`)
- **Outputs**: `descriptive_identifier` (e.g., `rds_cluster_endpoint`)

### Tagging
All resources tagged with:
```
{
  Environment = var.environment
  Project     = "e-voting"
  Module      = var.module_name
  ManagedBy   = "terraform"
}
```

### Outputs
Always provide:
1. **Primary Output** (e.g., VPC ID, RDS endpoint)
2. **IDs for Cross-References** (e.g., security group IDs)
3. **Metadata for Debugging** (e.g., availability zones, subnet CIDR blocks)

### Documentation
- Add `README.md` to each module explaining purpose, inputs, outputs
- Use comments for complex logic (e.g., conditional resource creation)
- Document security group rules: why each ingress/egress rule exists

## Testing Strategy

### Unit Tests (LocalStack)
- **Scope**: Individual module in isolation
- **Tool**: LocalStack v4.4.0
- **Frequency**: Before committing module code
- **Validation**: Resource count, security group rules, outputs populated

### Integration Tests (Staging)
- **Scope**: Module + dependencies (e.g., ECS + RDS + network)
- **Frequency**: Before PR merge
- **Validation**: Cross-module connectivity (RDS reachable from ECS)

### Infrastructure Tests (prod-like)
- **Scope**: Full environment deployment
- **Frequency**: Weekly or before release
- **Validation**: Health checks, latency, failover behavior

## Common Pitfalls & Solutions

| Pitfall | Cause | Solution |
|---------|-------|----------|
| **State Lock Timeout** | DynamoDB throttling or stale lock | Increase DynamoDB capacity; use `force-unlock` sparingly |
| **NAT Gateway Cost Overruns** | Hourly charges + data transfer | Monitor with CloudWatch; use VPC endpoints for AWS services |
| **ECS Task Failures** | Missing VPC endpoint or IAM role | Pre-validate VPC endpoints; use task role for Secrets Manager |
| **Blast Radius Expansion** | Module outputs used outside dependency chain | Enforce `dependency` blocks; review `terraform show` before apply |
| **LocalStack Divergence** | AWS behavior not fully simulated | Focus on infrastructure shape, not AWS-specific features; always validate in staging |
| **RDS Multi-AZ Failures** | Subnets span only 1 AZ | Verify DB subnet group covers ≥2 AZs; test failover |

## Environment-Specific Behavior

### Dev
- Smaller instance types (cost optimization)
- Single-AZ deployments (RDS single-AZ OK for dev)
- Minimal monitoring (CloudWatch alarms only on critical resources)

### Staging
- Production-like sizes (validate performance)
- Multi-AZ deployments
- Full monitoring suite

### Prod
- Rightsized instances (validated by staging)
- Multi-AZ mandatory (all stateful services)
- Enhanced monitoring (detailed CloudWatch logs, X-Ray tracing)
- Disaster recovery enabled (RDS automated backups, S3 cross-region replication)

## Setup Instructions

See [README.md](./README.md#setup) for quick-start: OpenTofu, Terragrunt, and LocalStack installation.

## Key Files to Review

- **AWS Architecture**: [README.md](./README.md#aws-architecture-diagram)
- **Deployment Guide**: `docs/DEPLOYMENT.md`
- **Module Specs**: `tofu/modules/[MODULE]/SPEC.md`
- **Terragrunt Docs**: `terragrunt/README.md`
