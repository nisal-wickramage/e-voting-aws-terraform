# S3 Frontend Module

Provisions a private S3 bucket for storing static frontend assets with CloudFront-only access.

## Purpose

- **Private Storage**: S3 bucket with all public access blocked
- **CloudFront Integration**: Origin Access Identity (OAI) for secure CloudFront access
- **Versioning**: Optional versioning for disaster recovery and rollback capability
- **Encryption**: Server-side encryption with S3-managed keys
- **Access Logging**: Optional S3 access logs to another bucket

## Architecture

```
┌─────────────────────────────────────────┐
│         CloudFront Distribution         │
│  (cdn-waf module)                       │
└──────────────────┬──────────────────────┘
                   │ (OAI authenticated)
                   ▼
        ┌──────────────────────┐
        │   S3 Bucket          │
        │  (frontend assets)   │
        │ - Private            │
        │ - Versioning         │
        │ - Encryption         │
        └──────────────────────┘
```

## Key Resources

| Resource | Purpose |
|----------|---------|
| `aws_s3_bucket` | Private S3 bucket for frontend files |
| `aws_s3_bucket_public_access_block` | Enforce private access (no public read) |
| `aws_s3_bucket_versioning` | Enable object versioning for rollback |
| `aws_s3_bucket_server_side_encryption_configuration` | Encrypt objects at rest |
| `aws_cloudfront_origin_access_identity` | CloudFront OAI for secure bucket access |
| `aws_s3_bucket_policy` | Allow OAI read-only access |
| `aws_s3_bucket_cors_configuration` | Enable CORS for cross-origin requests |

## Usage

```hcl
module "s3_frontend" {
  source = "../../modules/s3-frontend"

  project_name  = "e-voting"
  environment   = "dev"
  enable_versioning = true
  enable_logging    = false

  tags = {
    CostCenter = "engineering"
    Owner      = "platform-team"
  }
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project_name` | string | required | Project name (1-32 chars) |
| `environment` | string | required | Environment (dev, staging, prod) |
| `enable_versioning` | bool | `true` | Enable S3 versioning |
| `enable_logging` | bool | `false` | Enable S3 access logging |
| `logging_bucket` | string | `null` | S3 bucket for access logs |
| `tags` | map(string) | `{}` | Common tags for all resources |

## Outputs

| Name | Description |
|------|-------------|
| `bucket_name` | S3 bucket name |
| `bucket_arn` | S3 bucket ARN |
| `bucket_regional_domain_name` | Regional domain name (e.g., `bucket.s3.us-east-1.amazonaws.com`) |
| `cloudfront_oai_id` | CloudFront OAI ID |
| `cloudfront_oai_iam_arn` | CloudFront OAI IAM ARN (for bucket policy) |

## Security

- **No Public Access**: `aws_s3_bucket_public_access_block` prevents any public read
- **CloudFront-Only Access**: Bucket policy restricts reads to CloudFront OAI
- **Encryption**: All objects encrypted with AES256 at rest
- **Versioning**: Prevents accidental deletion; can enable MFA delete in prod for extra safety
- **Logging** (optional): Track all access to the bucket via S3 access logs

## Deployment

Deploy this module before `cdn-waf`:

```bash
cd terragrunt/dev/s3-frontend
terragrunt plan
terragrunt apply
```

Then deploy `cdn-waf` which depends on this module's outputs.

## Uploading Frontend Assets

```bash
# Upload built frontend files to S3
aws s3 sync ./dist s3://<bucket-name>/ --delete

# Invalidate CloudFront cache to reflect changes
aws cloudfront create-invalidation --distribution-id <dist-id> --paths "/*"
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Access Denied from CloudFront | OAI not in bucket policy | Verify OAI ARN in policy matches output |
| Bucket name conflict | Name already exists globally | Check S3 bucket naming (must be globally unique) |
| Objects not visible | Public access block too restrictive | Confirm bucket policy and OAI |
| Versioning not working | Status set to "Suspended" | Set `enable_versioning = true` |

## Cost Considerations

- **Storage**: Standard S3 storage ~$0.023/GB/month (dev), higher for prod
- **Requests**: Negligible for typical frontend traffic via CloudFront caching
- **Data Transfer**: CloudFront origin fees apply; typically $0.01-0.03/GB to CloudFront
- **Versioning**: Each version consumes storage; clean old versions to manage costs

## Disaster Recovery

### Backup Strategy
- Enable versioning (enabled by default)
- Optional: Enable S3 access logging to audit access
- For prod: Consider cross-region replication to another bucket

### Restore Strategy
- Restore specific version: `aws s3api get-object --bucket <name> --key <key> --version-id <id> <file>`
- Rebuild CloudFront cache: `aws cloudfront create-invalidation --distribution-id <id> --paths "/*"`
