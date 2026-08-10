# Multi-Service API Stack

**Purpose**: Deploy a microservices architecture with synchronous and asynchronous services

**Components**:
- 🌐 Network: VPC, subnets, security groups
- 🎯 Cluster: ECS cluster with Application Load Balancer
- 🗄️ Database: RDS PostgreSQL Multi-AZ (shared between services)
- 📦 API Service: Synchronous REST API (handles HTTP requests)
- ⚙️ Worker Service: Asynchronous service (processes SQS jobs)
- 📨 SQS Queue: Job queue for async processing (with DLQ)
- 🔄 Migrations: Database schema setup
- 📊 Monitoring: CloudWatch alarms + SNS for all services
- 🛡️ CDN: CloudFront with WAF

**Architecture**:
```
Client
  ↓
CloudFront + WAF
  ↓
Private ALB
  ├─ /api/* → API Service
  │           ↓
  │      RDS PostgreSQL
  │           ↑
  │    Enqueue job to SQS
  │           ↓
  └─ Worker Service ← SQS Queue (with DLQ)
                       ↓
                  RDS PostgreSQL
```

**Service Communication**:

**API Service**:
- Accepts REST requests
- Validates input
- Stores data in RDS
- Enqueues long-running jobs to SQS
- Returns immediately to client

**Worker Service**:
- Listens to SQS queue
- Processes messages (1+ per poll)
- Updates RDS with results
- Retries on failure
- Dead-letter queue for persistent failures

**Deploy**:
```bash
cd stacks/multi-service-api
terragrunt stack generate
terragrunt stack run -- init
terragrunt stack run -- plan
terragrunt stack run -- apply
```

**Key Features**:
- ✅ Decoupled sync/async services
- ✅ SQS for reliable message processing
- ✅ Dead-letter queue for failed messages
- ✅ Automatic scaling per service
- ✅ Shared RDS for data consistency
- ✅ Independent CloudWatch alarms per service
- ✅ Full observability via CloudWatch

**Use Cases**:
- Image processing (upload → queue → worker → stored in S3)
- Report generation (request → queue → worker → email notification)
- Data validation (receive → queue → worker → database update)
- Batch operations (accept many → queue → worker processes → aggregate)

**Time to Deploy**: ~25-30 minutes

**Cost Estimate** (dev environment):
- Network: $0 (VPC endpoints only)
- Cluster: ~$40/month (2 services)
- RDS: ~$50/month
- SQS: ~$1/month (dev volume)
- **Total**: ~$91/month (dev)

**Configuration**:

**API Service Environment**:
```hcl
environment_variables = {
  SERVICE_TYPE = "api"
  SQS_QUEUE_URL = "https://sqs.us-east-1.amazonaws.com/123456789012/..."
  SQS_REGION = "us-east-1"
}
```

**Worker Service Environment**:
```hcl
environment_variables = {
  SERVICE_TYPE = "worker"
  WORKER_CONCURRENCY = "10"
  SQS_QUEUE_URL = "https://sqs.us-east-1.amazonaws.com/123456789012/..."
  SQS_REGION = "us-east-1"
}
```

**SQS Queue Settings**:
- Visibility Timeout: 300s (5 minutes)
- Message Retention: 14 days
- Max Receive Count: 3 (then to DLQ)
- Dead-Letter Queue: Enabled

**Monitoring**:
- API Service: Request latency, error rate, ALB health
- Worker Service: Queue depth, processing time, DLQ count
- RDS: CPU, connection count, read/write latency
- SQS: Queue depth, oldest message age, DLQ depth

**Scaling**:
- API: Scale based on ALB target group requests
- Worker: Scale based on SQS queue depth (messages / desired count)
- RDS: Multi-AZ failover on failure

**Next Steps**:
1. Deploy this stack
2. Monitor SQS queue depth in CloudWatch
3. Enqueue test messages via API
4. Verify worker processes messages
5. Check DLQ for any failed messages

**Example Job Flow**:
```
1. Client POST /api/process?data=value
2. API Service validates, stores in RDS, enqueues SQS message
3. API returns 202 Accepted with job_id
4. Worker Service polls SQS
5. Worker processes message, updates RDS with result
6. Client can poll GET /api/status/{job_id} to check result
```

**Troubleshooting**:
- Messages stuck in DLQ? Check worker service logs in CloudWatch
- Queue growing? Worker service scaling too slow or failing
- High latency? Check RDS CPU and connection count
- No messages processed? Verify worker service is running and has SQS permissions
