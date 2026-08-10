# E-Voting AWS Infrastructure

OpenTofu configuration for deploying a highly available, scalable microservices architecture on AWS with a frontend application.

## Architecture Overview

This project provisions a complete AWS infrastructure with a single `tofu apply` command:

- **Network Layer**: VPC with private subnets across multiple availability zones
- **Database**: RDS PostgreSQL in private subnets with automated backups
- **Compute**: ECS Fargate for the API service in private subnets
- **Load Balancing**: Application Load Balancer in private subnets
- **Frontend**: S3-hosted single page application (SPA) with CloudFront CDN
- **Security**: Web Application Firewall (WAF) and API gateway protection
- **Disaster Recovery**: Automated backups and recovery strategies

## Project Structure

```
e-voting-aws-terraform/
├── tofu/
│   └── modules/                      # Reusable modules
│       ├── network/                  # VPC, subnets, networking
│       ├── database/                 # RDS PostgreSQL
│       ├── cluster/                  # ECS cluster + ALB
│       ├── ecs-api/                  # API service task definition
│       ├── s3-frontend/              # Frontend S3 bucket
│       ├── cdn-waf/                  # CloudFront + WAF
│       └── disaster-recovery/        # Backup strategies
├── main.tf                           # Module orchestration
├── variables.tf                      # Input variables
├── outputs.tf                        # Output values
├── locals.tf                         # Local values
├── terraform.tf                      # Provider & backend config
├── README.md                         # This file
├── LICENSE                           # License
└── AGENTS.md                         # AI agent guide
```

## Key Features

- **Single Apply Deployment**: All infrastructure deployed with one `tofu apply` command
- **Modular Design**: Each component is a separate module for clarity and maintainability
- **Terraform/OpenTofu Native**: No Terragrunt orchestration, simpler to understand
- **Infrastructure as Code**: Full version control and audit trail
- **Private Compute**: Services and databases in private subnets only
- **High Availability**: Multi-AZ deployment with automated failover
- **Security First**: Private endpoints, VPC isolation, WAF protection

## AWS Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Account                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    CloudFront + WAF                      │   │
│  │        (Frontend SPA & API Gateway)                      │   │
│  └──────────────────────────────────────────────────────────┘   │
│                            │                                      │
│  ┌─────────────────────────┼──────────────────────────────────┐  │
│  │                    VPC (10.0.0.0/16)                      │  │
│  │                                                            │  │
│  │  ┌──────────────────┐          ┌──────────────────────┐   │  │
│  │  │  NAT Gateways   │          │   Private Subnets    │   │  │
│  │  │  (2 AZs)        │          │  (AZ 1A, 1B)        │   │  │
│  │  └──────────────────┘          │                      │   │  │
│  │                                │ ┌────────────────┐   │   │  │
│  │                                │ │  ECS Fargate   │   │   │  │
│  │                                │ │  API Service   │   │   │  │
│  │                                │ └────────────────┘   │   │  │
│  │                                │                      │   │  │
│  │                                │ ┌────────────────┐   │   │  │
│  │                                │ │ App Load       │   │   │  │
│  │                                │ │ Balancer       │   │   │  │
│  │                                │ └────────────────┘   │   │  │
│  │                                │                      │   │  │
│  │                                │ ┌────────────────┐   │   │  │
│  │                                │ │ RDS PostgreSQL │   │   │  │
│  │                                │ │ (Multi-AZ)     │   │   │  │
│  │                                │ └────────────────┘   │   │  │
│  │                                │                      │   │  │
│  │                                │ S3 Frontend         │   │  │
│  │                                │ (Static Files)      │   │  │
│  │                                └──────────────────────┘   │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Module Dependency Graph

```
┌─ Network (no dependencies)
│
├─ Database → Network
│
├─ Cluster → Network
│
├─ ECS API → Cluster + Database
│
├─ S3 Frontend → Network
│
├─ CloudFront/WAF → Cluster + S3 Frontend
│
└─ Disaster Recovery → Database + S3 Frontend
```

## Quick Start

### Prerequisites

- AWS Account with appropriate permissions
- **OpenTofu** (v1.6+) or **Terraform** (v1.0+)
- AWS CLI v2 configured with credentials
- Bash shell

### Install OpenTofu

**macOS** (Homebrew):
```bash
brew install opentofu
tofu version
```

**Linux** (Ubuntu/Debian):
```bash
wget -O - https://get.opentofu.org/opentofu.gpg | sudo gpg --dearmor -o /usr/share/keyrings/opentofu-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/opentofu-archive-keyring.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main" | sudo tee /etc/apt/sources.list.d/opentofu.list
sudo apt-get update && sudo apt-get install -y tofu
```

**Windows** (Chocolatey):
```powershell
choco install opentofu
```

### Deployment Steps

#### 1. Configure Backend State

Create an S3 bucket for remote state:
```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://evoting-terraform-state-$(date +%s) --region us-east-1

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

#### 2. Initialize Terraform

```bash
cd /path/to/e-voting-aws-terraform

tofu init \
  -backend-config="bucket=evoting-terraform-state-XXXXXXX" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=terraform-locks" \
  -backend-config="encrypt=true"
```

#### 3. Create terraform.tfvars

```bash
cat > terraform.tfvars << 'EOF'
aws_region       = "us-east-1"
environment      = "dev"
project_name     = "evoting"
vpc_cidr         = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

# Database
db_instance_class  = "db.t3.micro"
db_allocated_storage = 20
db_username        = "postgres"
db_password        = "ChangeMe@12345"  # Change this!
db_name            = "evotingdb"

# ECS
container_port     = 8080
container_image    = "public.ecr.aws/docker/library/nginx:latest"
desired_count      = 2

# Disaster Recovery
rds_backup_retention_days = 7
enable_vpc_flow_logs      = true
enable_waf                = true
enable_versioning         = true
EOF
```

#### 4. Plan Infrastructure

```bash
tofu plan -out=tfplan
```

Review the plan output to verify all resources to be created.

#### 5. Apply Configuration

```bash
tofu apply tfplan
```

The deployment typically takes 10-15 minutes. OpenTofu will output:
- VPC ID
- RDS endpoint
- ECS cluster name
- ALB DNS name
- CloudFront domain name

#### 6. Verify Deployment

```bash
# Check ECS service
aws ecs describe-services \
  --cluster evoting-dev-cluster \
  --services api \
  --region us-east-1

# Check RDS
aws rds describe-db-instances \
  --db-instance-identifier evoting-dev-postgres \
  --region us-east-1

# Check CloudFront
aws cloudfront list-distributions --query 'DistributionList.Items[0]'
```

### Destroying Infrastructure

⚠️ **Warning**: This will delete all resources including the database.

```bash
tofu destroy
```

## Input Variables

Key variables in `variables.tf`:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `aws_region` | string | `us-east-1` | AWS region |
| `environment` | string | `dev` | Environment: dev, staging, prod |
| `project_name` | string | `evoting` | Project name for naming resources |
| `vpc_cidr` | string | `10.0.0.0/16` | VPC CIDR block |
| `db_instance_class` | string | `db.t3.micro` | RDS instance size |
| `db_password` | string | *required* | RDS master password (sensitive) |
| `container_image` | string | `nginx:latest` | Docker image for API service |
| `desired_count` | number | `2` | Number of ECS tasks |
| `rds_backup_retention_days` | number | `7` | RDS backup retention |

## Outputs

After `tofu apply`, outputs include:

```bash
# View outputs
tofu output

# Specific output
tofu output cloudfront_domain_name
tofu output rds_endpoint
```

Key outputs:
- `vpc_id` - VPC identifier
- `rds_endpoint` - Database host
- `alb_dns_name` - Application Load Balancer DNS
- `cloudfront_domain_name` - CDN endpoint
- `infrastructure_summary` - Complete deployment summary

## Module Specifications

Each module is self-contained with:
- `variables.tf` - Input variables
- `main.tf` - Resource definitions
- `outputs.tf` - Module outputs
- `README.md` - Module documentation
- `SPEC.md` - Technical specifications (if applicable)

Browse `tofu/modules/` for detailed module documentation.

## Security Considerations

- ✅ All databases and compute in private subnets (no public IPs)
- ✅ VPC endpoints for AWS services (ECR, S3, CloudWatch Logs, Secrets Manager)
- ✅ WAF rules for API and frontend protection
- ✅ Encryption at rest and in transit
- ✅ Automated backup retention policies
- ✅ IAM roles with least privilege access
- ✅ Security groups with minimal required access
- ✅ RDS Multi-AZ for high availability

## Cost Optimization

- ECS Fargate with appropriate task sizing
- RDS sizing based on environment (dev: db.t3.micro, prod: larger)
- S3 lifecycle policies for log retention
- CloudFront caching for frontend and API responses
- NAT Gateway traffic optimization via VPC endpoints

## Backup & Disaster Recovery

**Database**:
- Automated daily backups (configurable retention: 1-35 days)
- Point-in-time recovery capability
- Multi-AZ deployment for high availability
- RTO: 1 hour, RPO: 1 hour

**Frontend**:
- S3 versioning enabled
- Object lock available for compliance
- Cross-region replication (optional)

## Troubleshooting

### State Lock Issues

```bash
# View lock info
aws dynamodb scan --table-name terraform-locks --region us-east-1

# Force unlock (use cautiously!)
tofu force-unlock <LOCK_ID>
```

### ECS Task Failures

```bash
# Check ECS logs
aws logs tail /ecs/evoting-dev-api --follow --region us-east-1

# Describe tasks
aws ecs describe-tasks \
  --cluster evoting-dev-cluster \
  --tasks <TASK_ARN> \
  --region us-east-1
```

### Database Connection Issues

```bash
# Test connectivity from EC2 bastion or local
psql -h <RDS_ENDPOINT> -U postgres -d evotingdb -c "SELECT version();"

# Check security group
aws ec2 describe-security-groups \
  --group-ids <SG_ID> \
  --region us-east-1
```

## Contributing

1. Create a feature branch
2. Modify module code or root configuration
3. Run `tofu plan` and review changes
4. Test in dev environment
5. Create PR with plan output
6. Review and merge after approval

## License

See [LICENSE](LICENSE) file for details.

## Support

For detailed information:
- See [AGENTS.md](AGENTS.md) for AI agent guidance
- Review module README files in `tofu/modules/*/`
- Check AWS documentation for service specifics
