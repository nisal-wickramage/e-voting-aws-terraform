# E-Voting AWS Terraform Infrastructure

Terraform and Terragrunt configuration for deploying a highly available, scalable microservices architecture on AWS with a frontend application.

## Architecture Overview

This project provisions a complete AWS infrastructure with:

- **Network Layer**: VPC with private/public subnets across multiple availability zones
- **Database**: RDS PostgreSQL in private subnets with automated backups
- **Compute**: ECS Fargate services for microservices in private subnets
- **Load Balancing**: Application Load Balancer for traffic distribution
- **Frontend**: S3-hosted single page application (SPA) with CloudFront CDN
- **Security**: Web Application Firewall (WAF) and API gateway protection
- **Monitoring**: CloudWatch alarms and dashboards
- **Disaster Recovery**: Automated backups and RTO/RPO strategies

## Project Structure

```
e-voting-aws-terraform/
├── terraform/
│   ├── modules/                      # Reusable Terraform modules
│   │   ├── network/                  # VPC, subnets, networking
│   │   ├── platform/                 # ECS cluster, ALB base setup
│   │   ├── database/                 # RDS PostgreSQL
│   │   ├── ecs-services/             # ECS task definitions, services
│   │   ├── s3-frontend/              # Frontend S3 bucket
│   │   ├── cdn-waf/                  # CloudFront + WAF
│   │   ├── monitoring/               # CloudWatch, alarms
│   │   └── disaster-recovery/        # Backup strategies
│   └── variables.tf                  # Global variables
├── terragrunt/
│   ├── terragrunt.hcl               # Root Terragrunt config
│   ├── dev/                         # Development environment
│   ├── staging/                     # Staging environment
│   └── prod/                        # Production environment
├── docs/                            # Documentation
│   ├── ARCHITECTURE.md              # Detailed architecture
│   ├── MODULES.md                   # Module specifications
│   ├── DEPLOYMENT.md                # Deployment guide
│   └── OPERATIONS.md                # Operations guide
└── README.md                        # This file
```

## Key Features

- **Modular Design**: Each component is a separate module for independent scaling and changes
- **Low Blast Radius**: Infrastructure changes are isolated to specific modules
- **Environment Segregation**: Separate configurations for dev, staging, and production
- **Infrastructure as Code**: Full version control and audit trail
- **Private Compute**: Microservices and databases run in private subnets
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
│  │  │ Public Subnets   │          │   Private Subnets    │   │  │
│  │  │ (AZ 1A, 1B)      │          │  (AZ 1A, 1B)        │   │  │
│  │  │                  │          │                      │   │  │
│  │  │ NAT Gateways    │          │ ┌────────────────┐   │   │  │
│  │  │ IGW             │          │ │  ECS Fargate   │   │   │  │
│  │  │                  │          │ │  Microservices│   │   │  │
│  │  └──────────────────┘          │ └────────────────┘   │   │  │
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
│  │                                │ ┌────────────────┐   │   │  │
│  │                                │ │ S3 Frontend    │   │   │  │
│  │                                │ │ (Static Files) │   │   │  │
│  │                                │ └────────────────┘   │   │  │
│  │                                └──────────────────────┘   │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Module Dependencies

```
cloudfront-waf
  └── s3-frontend
  └── api (ecs-services exposed via ALB)

ecs-services
  └── platform (ECS cluster, ALB)
      └── network (VPC, subnets)
  └── database (RDS)
      └── network (VPC, subnets)

monitoring
  └── All modules (alarms for services)

disaster-recovery
  └── database (backups)
  └── s3-frontend (versioning)
```

## Setup

### Prerequisites
- macOS (Intel or Apple Silicon), Linux, or Windows (WSL2)
- AWS Account with appropriate permissions
- Docker (for LocalStack and building microservice images)
- AWS CLI v2 configured with credentials

### Install OpenTofu

**macOS** (Homebrew):
```bash
brew install opentofu
tofu version  # Verify installation
```

**Linux**:
```bash
# Ubuntu/Debian
wget -O - https://get.opentofu.org/opentofu.gpg | sudo gpg --dearmor -o /usr/share/keyrings/opentofu-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/opentofu-archive-keyring.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main" | sudo tee /etc/apt/sources.list.d/opentofu.list
sudo apt-get update && sudo apt-get install -y tofu
```

**Windows (Chocolatey)**:
```powershell
choco install opentofu
```

### Install Terragrunt

**macOS**:
```bash
brew install terragrunt
terragrunt --version  # Verify installation
```

**Linux**:
```bash
wget https://github.com/gruntwork-io/terragrunt/releases/download/v0.54.5/terragrunt_linux_amd64
chmod +x terragrunt_linux_amd64
sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt
```

**Windows (Chocolatey)**:
```powershell
choco install terragrunt
```

### Start LocalStack (v4.4.0)

```bash
docker run -d --name localstack \
  -p 4566:4566 \
  -e SERVICES=ec2,rds,s3,elasticloadbalancing,ecs,cloudwatch \
  -e DOCKER_HOST=unix:///var/run/docker.sock \
  localstack/localstack:4.4.0

# Verify health
curl http://localhost:4566/_localstack/health
```

To stop: `docker stop localstack && docker rm localstack`

## Quick Start

### 1. Initialize Terragrunt

```bash
cd terragrunt/dev
terragrunt init
```

### 2. Plan Infrastructure

```bash
terragrunt plan
```

### 3. Apply Configuration

```bash
terragrunt apply
```

### 4. Destroy Infrastructure (when needed)

```bash
terragrunt destroy
```

## Environment Configuration

Each environment (dev, staging, prod) has its own configuration:

- **Development**: Single AZ, cost-optimized
- **Staging**: Multi-AZ, production-like
- **Production**: Multi-AZ, high availability, automated backups

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed deployment instructions.

## Module Specifications

Detailed specifications for each module are available in:
- [docs/MODULES.md](docs/MODULES.md) - Module specifications
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - Detailed architecture decisions

## Documentation

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - High-level architecture decisions
- **[MODULES.md](docs/MODULES.md)** - Module specifications and inputs/outputs
- **[DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Step-by-step deployment guide
- **[OPERATIONS.md](docs/OPERATIONS.md)** - Operations and troubleshooting

## Security Considerations

- All databases and compute resources run in private subnets
- VPC endpoints for AWS services (S3, DynamoDB, CloudWatch)
- WAF rules for API and frontend protection
- Encryption at rest and in transit
- Automated backup retention policies
- IAM roles with least privilege access

## Cost Optimization

- ECS Fargate with capacity providers for auto-scaling
- RDS Reserved Instances (optional)
- S3 Lifecycle policies for log retention
- CloudFront caching for frontend and API responses
- NAT Gateway optimization through traffic patterns

## Monitoring & Alerts

- CloudWatch dashboards for key metrics
- Automated alarms for:
  - RDS CPU, storage, connections
  - ECS task health and performance
  - ALB target health
  - CloudFront error rates
  - WAF suspicious activities

## Disaster Recovery

- Automated daily RDS backups (configurable retention)
- Point-in-time recovery for databases
- S3 versioning and MFA delete protection
- Cross-region backup replication (optional)
- RTO: 4 hours, RPO: 1 hour (for database)

## Contributing

1. Create a feature branch
2. Make infrastructure changes
3. Plan and validate with Terragrunt
4. Create PR with plan output
5. Review and merge after approval
6. Apply in appropriate environment

## Support

For issues or questions:
1. Check [docs/OPERATIONS.md](docs/OPERATIONS.md)
2. Review Terraform state: `terragrunt show`
3. Check CloudWatch logs: `aws logs tail --follow`

## License

See [LICENSE](LICENSE) file for details.
