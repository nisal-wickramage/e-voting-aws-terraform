# Terragrunt Stacks - Composition Examples

This directory contains reusable Terragrunt stacks demonstrating different architectural patterns using the composable modules in this project.

Each stack shows how to combine multiple OpenTofu/Terragrunt modules into complete, production-ready systems.

## 📚 Available Stacks

### 1. [Basic API](./basic-api/)
**Best for**: Simple REST APIs with database backend

- ✅ REST API with ECS
- ✅ PostgreSQL database
- ✅ CloudFront + WAF
- ✅ Monitoring & alarms
- ✅ Zero public exposure

**Modules**: 8
**Deploy time**: ~15-20 min
**Monthly cost**: ~$80 (dev)

```
Internet → CloudFront + WAF → ECS API ↔ RDS
```

### 2. [Web App](./web-app/)
**Best for**: Full-stack applications (frontend + backend)

- ✅ React/Vue/Angular frontend on S3
- ✅ REST API backend on ECS
- ✅ Single CloudFront distribution (dual origin)
- ✅ Path-based routing (/api/* vs /*)
- ✅ Complete observability

**Modules**: 9 (includes S3 frontend)
**Deploy time**: ~20-25 min
**Monthly cost**: ~$90 (dev)

```
Internet → CloudFront + WAF
           ├─ /api/* → ECS API ↔ RDS
           └─ /* → S3 Frontend
```

### 3. [Multi-Service API](./multi-service-api/)
**Best for**: Microservices with sync/async processing

- ✅ Synchronous API service (REST)
- ✅ Asynchronous worker service
- ✅ SQS queue for job processing
- ✅ Dead-letter queue handling
- ✅ Per-service monitoring

**Modules**: 10 (includes SQS, multiple services)
**Deploy time**: ~25-30 min
**Monthly cost**: ~$91 (dev)

```
Client → CloudFront + WAF → ALB
         ├─ API Service → RDS
         │   ↓ (enqueue)
         └─ SQS Queue → Worker Service → RDS
                           ↓ (failed)
                        Dead-Letter Queue
```

## 🎯 Quick Comparison

| Feature | Basic API | Web App | Multi-Service |
|---------|-----------|---------|---------------|
| Frontend | ❌ | ✅ S3 | ❌ |
| API Service | ✅ | ✅ | ✅ |
| Async Worker | ❌ | ❌ | ✅ |
| SQS Queue | ❌ | ❌ | ✅ |
| Database | ✅ RDS | ✅ RDS | ✅ RDS |
| Monitoring | ✅ | ✅ | ✅ |
| Modules | 8 | 9 | 10 |

## 🚀 Getting Started

### Prerequisites
```bash
# Install required tools
terraform/tofu --version  # >= 1.2.0
terragrunt --version      # >= 1.1.0
aws --version             # >= 2.0
```

### Choose Your Stack
1. **Basic API** - Start here if you just need an API
2. **Web App** - Choose if you have a frontend
3. **Multi-Service** - Choose if you need background workers

### Deploy a Stack

```bash
cd stacks/basic-api  # or web-app or multi-service-api

# Generate the stack (resolves dependencies)
terragrunt stack generate

# Initialize
terragrunt stack run -- init

# Plan
terragrunt stack run -- plan

# Apply
terragrunt stack run -- apply

# View outputs
terragrunt stack output
```

## 📦 What's Included in Each Stack?

### Network & Cluster (all stacks)
- VPC with private subnets (public access through CloudFront only)
- ECS cluster with ALB
- Security groups with tier-based access (web, app, db)
- VPC endpoints for AWS services (no NAT gateway costs)

### Database (all stacks)
- RDS PostgreSQL Multi-AZ
- Automated backups
- Read replicas optional

### API Service (all stacks)
- Container from ECR (or custom image)
- Environment variables & secrets support
- Custom IAM permissions
- CloudWatch logs

### Frontend (web-app only)
- S3 static website bucket
- Versioning enabled
- CloudFront OAI for private access

### Workers (multi-service only)
- Separate ECS service for async processing
- SQS integration
- Dead-letter queue

### Monitoring (all stacks)
- SNS topic for notifications
- CloudWatch alarms for:
  - ECS: CPU, memory, running tasks
  - RDS: CPU, connections, replication lag
  - SQS: Queue depth, DLQ count (if applicable)
- Custom metrics and dashboards

### CDN & Security (all stacks)
- CloudFront distribution
- WAF with basic rules
- DDoS protection
- Geo-blocking optional

## 🔄 Module Dependency Flow

Each stack has a specific dependency order:

```
Core Infrastructure:
  network ─→ cluster
  network ─→ database

Services:
  cluster + database ─→ ecs_service_api
  cluster + database ─→ ecs_service_async
  sqs_queue ─→ ecs_service_async (multi-service only)

Monitoring:
  notification ← ecs_alarms ← ecs_service
  notification ← rds_alarms ← database
  notification ← sqs_alarms ← sqs_queue (multi-service only)

CDN:
  cluster ─→ cdn_waf
  s3_frontend ─→ cdn_waf (web-app only)
```

## 💡 Use Cases

### Basic API Stack
- REST API for mobile apps
- Microservice API for internal use
- GraphQL server
- Webhook receiver

### Web App Stack
- Full-stack web application
- Single-page app (SPA) backend
- Progressive web app (PWA) backend
- Admin dashboard + API

### Multi-Service Stack
- Image processing platform
- Report generation service
- Data validation pipeline
- Job queue system
- Event processing architecture

## 🛠️ Customization

Each stack uses Terragrunt configs from `terragrunt/dev/`. To customize:

1. **Change module source**: Edit `unit` block `source` path
2. **Add modules**: Add new `unit` block
3. **Change dependencies**: Edit `after` list
4. **Update variables**: Edit `source` path Terragrunt config

Example:
```hcl
unit "custom_service" {
  source = "../../terragrunt/dev/ecs-service-custom"
  description = "My custom service"
  after = [unit.cluster, unit.database]
}
```

## 📋 Common Tasks

### View stack plan without applying
```bash
cd stacks/basic-api
terragrunt stack generate
terragrunt stack run -- plan -out=tfplan
```

### Destroy a stack
```bash
cd stacks/basic-api
terragrunt stack run -- destroy -auto-approve
```

### Check specific module
```bash
# After generating stack, you can check individual module state
terraform -chdir=.terragrunt-cache/*/unit_name show
```

## 📊 Monitoring & Outputs

Each stack generates outputs:
```bash
terragrunt stack output

# Examples:
# - api_endpoint: HTTPS URL of API
# - rds_endpoint: Database endpoint
# - cloudfront_domain: CDN domain
# - sqs_queue_url: Queue URL (multi-service only)
```

## ⚠️ Important Notes

1. **Private Only**: All stacks deploy infrastructure in private subnets. Access is only through CloudFront/ALB.

2. **Cost**: These are development configurations. Production should use larger instance sizes.

3. **Security**: Update WAF rules, add IP restrictions, and enable logging before production.

4. **Backup**: Enable S3 cross-region replication and RDS automated backups.

5. **Testing**: Always test in dev environment first.

## 🎓 Learning Path

1. **Start**: Deploy Basic API stack
2. **Verify**: Check CloudFront access works
3. **Expand**: Add Web App stack (or new ECS service)
4. **Scale**: Progress to Multi-Service stack
5. **Customize**: Modify for your use case

## 📖 Additional Resources

- [Module Documentation](../tofu/modules/README.md)
- [Terragrunt Guide](../docs/TERRAGRUNT.md)
- [AWS Architecture](../README.md#aws-architecture-diagram)
- [Migration Guide](../MIGRATION_ECS_COMPOSABLE.md)

## 🤝 Contributing

To add a new stack:
1. Create `stacks/new-stack/` directory
2. Add `terragrunt.stack.hcl` with modules
3. Create `README.md` with documentation
4. Test with `terragrunt stack generate && terragrunt stack run -- plan`
5. Submit PR with description

---

**Happy composing! 🚀**
