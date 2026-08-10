# Basic API Stack

**Purpose**: Deploy a production-ready REST API with database and CDN

**Components**:
- 🌐 Network: VPC, subnets, security groups (private-only)
- 🎯 Cluster: ECS cluster with Application Load Balancer
- 🗄️ Database: RDS PostgreSQL Multi-AZ
- 📦 API Service: Single ECS service with ALB integration
- 🔄 Migrations: Database schema setup (run-once task)
- 📊 Monitoring: CloudWatch alarms + SNS notifications
- 🛡️ CDN: CloudFront with WAF protection

**Architecture**:
```
Internet → CloudFront + WAF
             ↓
        Private ALB
             ↓
        ECS Service API
             ↓
        RDS PostgreSQL
```

**Deploy**:
```bash
cd stacks/basic-api
terragrunt stack generate
terragrunt stack run -- init
terragrunt stack run -- plan
terragrunt stack run -- apply
```

**Key Features**:
- ✅ All infrastructure in private subnets (no public IPs)
- ✅ Traffic only through CloudFront (DDoS protection via WAF)
- ✅ Multi-AZ RDS for high availability
- ✅ Automatic CloudWatch alarms and SNS notifications
- ✅ Database migrations isolated as separate task

**Time to Deploy**: ~15-20 minutes

**Cost Estimate** (dev environment):
- Network: $0 (VPC endpoints only)
- Cluster: ~$20/month (minimal resources)
- RDS: ~$50/month (db.t3.micro)
- CloudFront: ~$10/month (minimal traffic)
- **Total**: ~$80/month (dev)

**Next Steps**:
1. Deploy this stack first
2. Verify API is accessible through CloudFront
3. Run migrations task: `terragrunt run -- apply` in ecs-migrations folder
4. Test endpoints through CloudFront domain
