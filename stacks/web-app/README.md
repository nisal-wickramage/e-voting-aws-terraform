# Web App Stack

**Purpose**: Deploy a complete full-stack web application (frontend + API)

**Components**:
- 🌐 Network: VPC, subnets, security groups
- 🎯 Cluster: ECS cluster with Application Load Balancer
- 🗄️ Database: RDS PostgreSQL Multi-AZ
- 📦 API Service: ECS service with ALB integration
- 🖼️ Frontend: S3 static website with versioning
- 🔄 Migrations: Database schema setup
- 📊 Monitoring: CloudWatch alarms + SNS
- 🛡️ CDN: CloudFront with WAF (dual origin - API + S3)

**Architecture**:
```
Internet → CloudFront + WAF
           ├─ /api/* → Private ALB → ECS Service
           └─ /* → S3 Frontend
                    ↓
                RDS PostgreSQL
```

**Deploy**:
```bash
cd stacks/web-app
terragrunt stack generate
terragrunt stack run -- init
terragrunt stack run -- plan
terragrunt stack run -- apply

# Then upload frontend to S3:
aws s3 sync ./frontend/dist s3://$(terraform output frontend_bucket_name)/
```

**Key Features**:
- ✅ Dual CloudFront origins (API + Frontend)
- ✅ S3 static site with versioning enabled
- ✅ Path-based routing: /api/* to ALB, /* to S3
- ✅ All infrastructure in private subnets
- ✅ Automatic failover and CDN caching
- ✅ Complete monitoring stack

**Frontend Path Patterns**:
- `/` → CloudFront S3 origin (static files)
- `/api/*` → CloudFront ALB origin (REST API)
- `/static/*` → CloudFront S3 origin (cached assets)

**Time to Deploy**: ~20-25 minutes

**Cost Estimate** (dev environment):
- Network: $0 (VPC endpoints only)
- Cluster: ~$20/month
- RDS: ~$50/month
- S3: ~$5/month (static content)
- CloudFront: ~$15/month (dual origin)
- **Total**: ~$90/month (dev)

**Next Steps**:
1. Deploy this stack
2. Build and upload frontend: `aws s3 sync ./frontend/dist s3://your-bucket/`
3. Test API at `https://yourdomain.cloudfront.net/api/health`
4. Test frontend at `https://yourdomain.cloudfront.net/`

**Frontend Integration**:
Update your frontend's API base URL:
```javascript
const API_BASE = process.env.VITE_API_URL || 'https://yourdomain.cloudfront.net/api'
```

**S3 Bucket Configuration**:
- Private bucket (no public access)
- Versioning enabled
- CloudFront OAI for access
- Block public ACLs
