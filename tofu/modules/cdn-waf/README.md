# CDN + WAF Module

Provisions CloudFront distributions for both API (ALB origin) and frontend (S3 origin) with AWS WAF protection.

## Purpose

- **API Distribution**: Routes API traffic through CloudFront CDN to private ALB in VPC
- **Frontend Distribution**: Serves static assets from private S3 bucket via CloudFront
- **WAF Protection**: Rate limiting, OWASP Top 10 protection, geo-blocking (optional)
- **Caching**: Intelligent caching strategies for API and static content
- **HTTPS**: Enforces HTTPS with redirect-to-https policy

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│                    Internet Users                          │
└─────────────────────────────────┬──────────────────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
                    ▼                           ▼
        ┌──────────────────────┐    ┌──────────────────────┐
        │  AWS WAF WebACL      │    │  AWS WAF WebACL      │
        │  - Rate Limiting     │    │  - Rate Limiting     │
        │  - OWASP Top 10      │    │  - OWASP Top 10      │
        │  - Geo-blocking      │    │  - Geo-blocking      │
        └──────────────────────┘    └──────────────────────┘
                    │                           │
                    ▼                           ▼
        ┌──────────────────────┐    ┌──────────────────────┐
        │ CloudFront (ALB)     │    │ CloudFront (S3)      │
        │ - API distribution   │    │ - Frontend dist.     │
        │ - Caching layer      │    │ - Caching layer      │
        └──────────────────────┘    └──────────────────────┘
                    │                           │
          ┌─────────┴──────────┐                │
          │                    │                │
          ▼                    ▼                ▼
      ┌────────────┐     ┌────────────┐   ┌──────────┐
      │ ALB (Priv) │     │ ALB (Priv) │   │ S3       │
      │ - AZ1      │     │ - AZ2      │   │ (Priv)   │
      └────────────┘     └────────────┘   └──────────┘
          │                    │
          └────────┬───────────┘
                   │
          ┌────────┴─────────┐
          │                  │
          ▼                  ▼
      ┌─────────┐      ┌──────────┐
      │ ECS API │      │ RDS      │
      │ Service │      │ Database │
      └─────────┘      └──────────┘
```

## Key Resources

| Resource | Purpose |
|----------|---------|
| `aws_wafv2_web_acl` | WebACL with rate limiting, OWASP, geo-blocking rules |
| `aws_cloudfront_distribution` (ALB) | CDN for API endpoints (ALB origin) |
| `aws_cloudfront_distribution` (S3) | CDN for frontend assets (S3 origin) |
| `aws_cloudwatch_metric_alarm` | Alarm on WAF blocked requests >10 per 5min |

## WAF Rules

1. **Rate Limiting**: Adaptive rate limiting per IP (default: 2000 req/5min)
2. **AWS Managed - Common Rule Set**: OWASP Top 10 protection (SQLi, XSS, etc.)
3. **AWS Managed - Known Bad Inputs**: Additional SQLi/XSS pattern detection
4. **Geographic Blocking** (optional): Block specified countries

## Usage

```hcl
module "cdn_waf" {
  source = "../../modules/cdn-waf"

  project_name                      = "e-voting"
  environment                       = "dev"
  alb_domain_name                   = "alb-12345.us-east-1.elb.amazonaws.com"
  s3_bucket_regional_domain_name    = "bucket.s3.us-east-1.amazonaws.com"
  cloudfront_oai_iam_arn           = "arn:aws:iam::123456789012:root"

  enable_waf                 = true
  waf_rate_limit            = 2000
  waf_geo_blocking_enabled  = true
  waf_geo_blocked_countries = ["CN", "RU", "KP"]

  viewer_protocol_policy = "redirect-to-https"
  compress              = true
  default_ttl           = 3600
  max_ttl              = 86400

  tags = {
    CostCenter = "engineering"
  }
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project_name` | string | required | Project name (1-32 chars) |
| `environment` | string | required | Environment (dev, staging, prod) |
| `alb_domain_name` | string | required | ALB DNS name (e.g., `alb-123.elb.amazonaws.com`) |
| `alb_origin_path` | string | `""` | Optional path prefix for ALB origin (e.g., `/api`) |
| `s3_bucket_regional_domain_name` | string | required | S3 bucket regional domain (e.g., `bucket.s3.region.amazonaws.com`) |
| `cloudfront_oai_iam_arn` | string | required | CloudFront OAI IAM ARN (from s3-frontend module) |
| `enable_waf` | bool | `true` | Enable AWS WAF |
| `waf_rate_limit` | number | `2000` | Rate limit per IP (requests per 5 minutes) |
| `waf_geo_blocking_enabled` | bool | `false` | Enable geo-blocking |
| `waf_geo_blocked_countries` | list(string) | `[]` | Country codes to block (e.g., `["CN", "RU"]`) |
| `default_ttl` | number | `3600` | Default cache TTL (seconds) |
| `max_ttl` | number | `86400` | Maximum cache TTL (seconds) |
| `compress` | bool | `true` | Enable gzip compression |
| `viewer_protocol_policy` | string | `"redirect-to-https"` | Protocol policy (allow-all, https-only, redirect-to-https) |
| `tags` | map(string) | `{}` | Common tags for all resources |

## Outputs

| Name | Description |
|------|-------------|
| `api_cloudfront_domain_name` | CloudFront domain for API (ALB) |
| `api_cloudfront_distribution_id` | Distribution ID for API (for invalidations) |
| `frontend_cloudfront_domain_name` | CloudFront domain for frontend (S3) |
| `frontend_cloudfront_distribution_id` | Distribution ID for frontend |
| `waf_web_acl_id` | WAF WebACL ID |
| `waf_web_acl_arn` | WAF WebACL ARN |
| `api_distribution_invoke_url` | Full HTTPS URL for API |
| `frontend_distribution_invoke_url` | Full HTTPS URL for frontend |

## Security

- **Private Origins**: Both ALB and S3 bucket are private; only CloudFront can access
- **HTTPS Enforcement**: Redirect-to-https policy forces encrypted traffic
- **WAF Protection**: Rate limiting + OWASP Top 10 rules prevent common attacks
- **CloudFront OAI**: S3 bucket only accessible via CloudFront (via OAI)
- **Compression**: gzip enabled to reduce payload size

## Caching Strategy

### API (ALB Origin)
- All HTTP methods allowed (GET, POST, PUT, DELETE, PATCH)
- Query string forwarding: enabled
- Cookie forwarding: all cookies forwarded (session state)
- Headers: Accept, Authorization, Content-Type, Host, Referer, User-Agent
- TTL: 0-3600 seconds (short-lived, mostly cache misses)

### Frontend (S3 Origin)
- Static assets: Cacheable with long TTL (1 hour default, 24 hours max)
- index.html: No caching (0s TTL) to ensure fresh content on app updates
- Query strings: Not forwarded (static content)

## Cache Invalidation

When updating API or frontend, invalidate CloudFront cache:

```bash
# Invalidate API cache
aws cloudfront create-invalidation \
  --distribution-id <api-dist-id> \
  --paths "/*"

# Invalidate frontend cache (especially index.html)
aws cloudfront create-invalidation \
  --distribution-id <frontend-dist-id> \
  --paths "/index.html" "/"
```

## Monitoring

### CloudWatch Metrics
- `BytesDownloaded`: Data downloaded from CloudFront
- `BytesUploaded`: Data uploaded to CloudFront
- `Requests`: Total CloudFront requests
- `4xxErrorRate`: Client errors (4xx)
- `5xxErrorRate`: Server errors (5xx)

### WAF Metrics
- `AllowedRequests`: Requests allowed by WAF
- `BlockedRequests`: Requests blocked by WAF
- `CountedRequests`: Requests counted by WAF rules (count-only mode)

## Cost Optimization

1. **Price Class**: Use `PriceClass_100` for dev (only North America, Europe)
2. **Compression**: Enable gzip to reduce data transfer
3. **Caching**: Set appropriate TTLs to maximize cache hit rates
4. **Geo-Blocking**: Block expensive regions if not needed (e.g., China, Russia)

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| ALB returns 502 | Origin misconfigured | Verify ALB domain name and security group allows CloudFront |
| S3 Access Denied | OAI not in bucket policy | Confirm S3 module bucket policy references correct OAI |
| Cache not invalidating | Invalidation not propagated | Wait 1-5 minutes; use specific paths, not just /* |
| WAF blocking legitimate traffic | Rules too strict | Adjust rate limit threshold; check logs in WAF console |
| High latency | Suboptimal TTL | Increase default_ttl for cacheable content |

## Dependencies

- **s3-frontend module**: Provides S3 bucket domain and CloudFront OAI
- **platform module**: Provides ALB domain name (ALB already deployed)
- **database module**: Not direct, but API behind ALB accesses RDS

## Deployment

```bash
# Deploy S3 frontend first
cd terragrunt/dev/s3-frontend
terragrunt apply

# Then deploy CDN + WAF
cd ../cdn-waf
terragrunt apply

# Test APIs
curl -v https://<api-cloudfront-domain>/api/health

# Test frontend
curl -v https://<frontend-cloudfront-domain>/
```
