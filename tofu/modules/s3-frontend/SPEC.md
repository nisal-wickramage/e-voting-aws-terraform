# S3 Frontend Module Specification

## Purpose
Create a private S3 bucket for static frontend assets (SPA) with versioning, encryption, and CloudFront-only access via bucket policy.

## Inputs

| Variable | Type | Description | Required | Example |
|----------|------|-------------|----------|---------|
| `bucket_name` | string | S3 bucket name (globally unique) | Yes | `"e-voting-frontend-prod"` |
| `enable_versioning` | bool | Enable bucket versioning for DR | Yes | `true` |
| `enable_server_side_encryption` | bool | Enable SSE-S3 encryption | Yes | `true` |
| `enable_public_access_block` | bool | Block all public access | Yes | `true` |
| `cloudfront_oai_id` | string | CloudFront OAI ID for bucket policy | Yes | (from cdn-waf module) |
| `enable_cross_region_replication` | bool | Enable cross-region replication for DR | No | `false` |
| `replication_destination_bucket` | string | Destination bucket for replication | No | `""` |
| `replication_destination_region` | string | Destination region for replication | No | `""` |
| `lifecycle_transition_days` | number | Days before transition to cheaper storage | No | `90` |
| `environment` | string | Environment name (dev/staging/prod) | Yes | `"prod"` |
| `project_name` | string | Project name for resource tagging | Yes | `"e-voting"` |
| `enable_cors` | bool | Enable CORS for cross-origin requests | No | `false` |
| `cors_allowed_origins` | list(string) | Allowed CORS origins | No | `[]` |
| `enable_access_logs` | bool | Enable S3 access logging | No | `false` |
| `access_logs_bucket` | string | Bucket for access logs | No | `""` |
| `tag_environment` | string | Environment tag value | Yes | `"prod"` |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `bucket_id` | string | S3 bucket name |
| `bucket_arn` | string | S3 bucket ARN |
| `bucket_region` | string | S3 bucket region |
| `bucket_domain_name` | string | S3 bucket domain (e.g., bucket.s3.amazonaws.com) |
| `bucket_regional_domain_name` | string | Regional domain (e.g., bucket.s3.us-east-1.amazonaws.com) |
| `bucket_versioning_enabled` | bool | Versioning status |
| `bucket_encryption_enabled` | bool | Encryption status |
| `bucket_public_access_blocked` | bool | Public access block status |
| `bucket_replication_role_arn` | string | IAM role ARN for replication (if enabled) |
| `bucket_policy_statement` | string | Bucket policy (for audit) |

## Resources

- **aws_s3_bucket**: Private bucket for frontend assets
- **aws_s3_bucket_versioning**: Enable versioning for recovery
- **aws_s3_bucket_server_side_encryption_configuration**: SSE-S3 encryption
- **aws_s3_bucket_public_access_block**: Block all public access
- **aws_s3_bucket_policy**: Allow CloudFront OAI only
- **aws_s3_bucket_cors_configuration** (optional): CORS rules
- **aws_s3_bucket_lifecycle_configuration** (optional): Transition to cheaper storage
- **aws_s3_bucket_replication_configuration** (optional): Cross-region replication
- **aws_iam_role** (if replication enabled): Replication role
- **aws_s3_bucket_logging** (optional): Access logs to separate bucket

## Security

### Access Control
- **Bucket Policy**: Allow CloudFront OAI (Origin Access Identity) only
  - No public access via direct S3 URL
  - All traffic must go through CloudFront
  - GET/HEAD operations only (no PUT/DELETE)

### Encryption
- **At Rest**: SSE-S3 (AWS managed keys)
- **In Transit**: HTTPS only (enforced by CloudFront)
- **Versioning**: Enables recovery from accidental deletion

### Public Access
- **Block All Public Access**: Enabled
- **ACLs**: Private (no public ACL grants)
- **Object Ownership**: Bucket owner enforced

### Monitoring
- **S3 Access Logs**: Optional, tracks all requests
- **CloudTrail**: Logs S3 API calls for audit

## Testing

### Expected Behavior
- S3 bucket created as private (no public access)
- Versioning enabled
- Encryption enabled
- Bucket policy grants CloudFront OAI access only
- Direct S3 URLs return 403 Forbidden
- CloudFront distribution can read objects

### Edge Cases
- Test versioning: Upload same filename, verify previous versions retained
- Test encryption: Verify objects encrypted (check object metadata)
- Test public access block: Attempt public list-bucket and object GET
- Test bucket policy: Verify only OAI can access (with test credentials)
- Test lifecycle: Verify transitions occur on schedule

### LocalStack Testing
```bash
# Start LocalStack
docker run -d -p 4566:4566 -e SERVICES=s3 localstack/localstack:4.4.0

# Configure
export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"

# Test
tofu init
tofu plan
tofu apply -auto-approve

# Validate
aws --endpoint-url=http://localhost:4566 s3 ls
aws --endpoint-url=http://localhost:4566 s3 versioning ls s3://e-voting-frontend-dev
aws --endpoint-url=http://localhost:4566 s3api get-bucket-encryption \
  --bucket e-voting-frontend-dev

# Test bucket policy
aws --endpoint-url=http://localhost:4566 s3api get-bucket-policy \
  --bucket e-voting-frontend-dev

# Destroy
tofu destroy -auto-approve
```

## Dependencies
- `network` module: Used for cross-stack reference only (no hard dependency)
- `cdn-waf` module: CloudFront OAI ID required for bucket policy

## Module Integration Points
- Input `cloudfront_oai_id` from cdn-waf module
- Output `bucket_id` used by cdn-waf for CloudFront origin
- Output `bucket_regional_domain_name` used by cdn-waf S3 origin
- Output `bucket_arn` for disaster recovery policy

## Deployment Patterns

### SPA Deployment
1. Build frontend (React, Vue, Angular)
2. Output to `dist/` directory
3. Upload to S3: `aws s3 sync dist/ s3://bucket-name/`
4. CloudFront invalidates cache (handled by cdn-waf module)

### Version Management
- Keep bucket versioning enabled
- Delete old versions based on lifecycle policy
- Reference specific versions for rollback

### Cross-Region Replication (DR)
- Enable replication to second region
- Replicated bucket also private with same policy
- Failover: Update DNS/CloudFront to point to replica

## Notes
- Bucket name must be globally unique across AWS (add account ID suffix)
- Versioning adds storage cost (keep old versions ~30 days, then delete)
- Replication cost: $0.02 per 1,000 objects + data transfer
- CloudFront caching reduces S3 access costs
- Consider S3 Intelligent-Tiering for automatic cost optimization
- OAI (Origin Access Identity) is being phased out in favor of Origin Access Control (OAC) — future migration
