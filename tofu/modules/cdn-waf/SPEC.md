# CDN + WAF Module Specification

## Purpose
Deploy CloudFront distributions for frontend and API with VPC origin support, Web Application Firewall (WAF) rules for DDoS/SQL injection protection, and SSL/TLS termination.

## Inputs

| Variable | Type | Description | Required | Example |
|----------|------|-------------|----------|---------|
| `alb_dns_name` | string | ALB DNS name from platform (VPC origin) | Yes | (from dependency) |
| `alb_zone_id` | string | ALB hosted zone ID | Yes | (from dependency) |
| `s3_bucket_domain_name` | string | S3 bucket domain from s3-frontend | Yes | (from dependency) |
| `api_domain_name` | string | Public domain for API (CNAME) | No | `"api.e-voting.com"` |
| `frontend_domain_name` | string | Public domain for frontend (CNAME) | No | `"app.e-voting.com"` |
| `certificate_arn` | string | ACM certificate ARN for custom domains | No | `""` |
| `enable_waf` | bool | Enable WAF protection | Yes | `true` |
| `enable_geo_blocking` | bool | Enable geo-blocking rules | No | `false` |
| `allowed_countries` | list(string) | Allowed country codes (ISO 3166-1 alpha-2) | No | `["US", "CA", "GB"]` |
| `blocked_countries` | list(string) | Blocked country codes | No | `[]` |
| `enable_rate_limiting` | bool | Enable rate limiting (requests/5 min) | No | `true` |
| `rate_limit_threshold` | number | Requests per 5 minutes from single IP | No | `2000` |
| `enable_ip_reputation` | bool | Enable AWS Managed Rules (IP reputation) | No | `true` |
| `enable_sql_injection_protection` | bool | Enable SQL injection protection | No | `true` |
| `enable_xss_protection` | bool | Enable XSS protection | No | `true` |
| `environment` | string | Environment name (dev/staging/prod) | Yes | `"prod"` |
| `project_name` | string | Project name for resource tagging | Yes | `"e-voting"` |
| `cache_default_ttl` | number | Default cache TTL (seconds) | No | `3600` |
| `cache_max_ttl` | number | Max cache TTL (seconds) | No | `86400` |
| `cache_min_ttl` | number | Min cache TTL (seconds) | No | `0` |
| `enable_http2` | bool | Enable HTTP/2 | No | `true` |
| `enable_ipv6` | bool | Enable IPv6 | No | `true` |
| `price_class` | string | CloudFront price class (PriceClass_All, PriceClass_100, PriceClass_200) | No | `"PriceClass_100"` |
| `web_acl_tags` | map(string) | Tags for WAF Web ACL | No | `{}` |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `cloudfront_api_distribution_id` | string | CloudFront distribution ID (API) |
| `cloudfront_api_domain_name` | string | CloudFront domain (API, e.g., d1234abcd.cloudfront.net) |
| `cloudfront_frontend_distribution_id` | string | CloudFront distribution ID (Frontend) |
| `cloudfront_frontend_domain_name` | string | CloudFront domain (Frontend) |
| `cloudfront_oai_id` | string | CloudFront OAI ID (for S3 bucket policy) |
| `waf_web_acl_arn` | string | WAF Web ACL ARN |
| `waf_web_acl_id` | string | WAF Web ACL ID |
| `api_dns_records` | map(string) | Route53 DNS records for API (CNAME) |
| `frontend_dns_records` | map(string) | Route53 DNS records for frontend (CNAME) |
| `cache_invalidation_path` | string | Path pattern for cache invalidation |

## Resources

- **aws_cloudfront_distribution** (2x): API (VPC origin) and Frontend (S3 origin)
- **aws_cloudfront_origin_access_identity**: OAI for S3 bucket access
- **aws_wafv2_web_acl**: Web ACL containing all WAF rules
- **aws_wafv2_ip_set**: IP set for rate limiting
- **aws_wafv2_rule** (multiple):
  - AWS Managed Rules (IP reputation, SQL injection, XSS)
  - Rate limiting rule
  - Geo-blocking rule (if enabled)
  - Custom rules (optional)
- **aws_cloudfront_cache_policy**: Cache behavior policy
- **aws_cloudfront_origin_request_policy**: Origin request headers
- **aws_cloudfront_response_headers_policy**: Security headers (HSTS, X-Frame-Options, etc.)

## Security

### WAF Rules
- **AWS Managed Rules**:
  - AWSManagedRulesCommonRuleSet (CRS): SQL injection, XSS, etc.
  - AWSManagedRulesAmazonIpReputationList: Block known malicious IPs
  - AWSManagedRulesKnownBadInputsRuleSet: Common attack patterns
- **Rate Limiting**: 2000 requests per 5 minutes per IP (configurable)
- **Geo-Blocking**: Restrict access to allowed countries (optional)

### HTTP Headers
- **Strict-Transport-Security (HSTS)**: Enforce HTTPS
- **X-Content-Type-Options**: `nosniff` (prevent MIME sniffing)
- **X-Frame-Options**: `DENY` (prevent clickjacking)
- **X-XSS-Protection**: `1; mode=block` (older XSS protection)
- **Referrer-Policy**: `strict-origin-when-cross-origin` (privacy)

### CloudFront Configuration
- **HTTPS Only**: Redirect HTTP to HTTPS
- **TLS Version**: TLSv1.2_2021-06 minimum (align with security best practices)
- **Viewer Policy**: `redirect-to-https`
- **Origin Protocol Policy**: `https-only` (ALB is private, but use HTTPS)
- **Price Class**: PriceClass_100 (North America, Europe, Asia) or PriceClass_All

### SSL/TLS
- **API Certificate**: Custom ACM certificate (if domain_name provided)
- **Frontend Certificate**: CloudFront default certificate or custom ACM
- **Certificate Validation**: DNS validation (automated)

## Testing

### Expected Behavior
- CloudFront distributions created and deployed
- WAF Web ACL created and associated
- API distribution uses VPC origin (ALB)
- Frontend distribution uses S3 origin
- Cache policies applied (appropriate TTLs)
- Security headers present in responses

### Edge Cases
- Test rate limiting: Send >2000 requests from single IP in 5 minutes
- Verify geo-blocking: Access from blocked country (403)
- Test cache invalidation: Update S3 object, verify cache refresh
- Validate SSL/TLS: Check certificate validity
- Test WAF: Send SQL injection payload, verify WAF blocks (403)

### LocalStack Testing
```bash
# Start LocalStack
docker run -d -p 4566:4566 \
  -e SERVICES=cloudfront,wafv2,s3,elasticloadbalancing \
  localstack/localstack:4.4.0

# Configure
export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"

# Test
tofu init
tofu plan -var="alb_dns_name=internal-alb-1234.us-east-1.elb.amazonaws.com"
tofu apply -auto-approve

# Validate
aws --endpoint-url=http://localhost:4566 cloudfront list-distributions
aws --endpoint-url=http://localhost:4566 wafv2 list-web-acls --scope CLOUDFRONT

# Destroy
tofu destroy -auto-approve
```

## Dependencies
- `platform` module: ALB DNS name, ALB zone ID
- `s3-frontend` module: S3 bucket domain name
- `cdn-waf` outputs (`cloudfront_oai_id`) to `s3-frontend` for bucket policy

## Module Integration Points
- Input `alb_dns_name` from platform module (VPC origin)
- Input `s3_bucket_domain_name` from s3-frontend module
- Output `cloudfront_oai_id` to s3-frontend module (bucket policy)
- Output `cloudfront_api_domain_name` for public DNS CNAME
- Output `cloudfront_frontend_domain_name` for public DNS CNAME

## Deployment Patterns

### A/B Testing
- Create temporary CloudFront behavior with different origin
- Route subset of traffic to new origin
- Monitor metrics (latency, error rate)
- Promote or rollback based on results

### Blue-Green Deployment
- Use CloudFront origin groups (primary/fallback)
- Deploy new ALB target group
- Switch CloudFront origin to new ALB
- Rollback if needed by reverting origin

### Cache Invalidation
- Deploy new frontend version: `aws cloudfront create-invalidation --distribution-id D123 --paths "/*"`
- Cost: First 3 invalidations/month free, then $0.005 per path

## Notes
- WAF Web ACL: Shared by both API and Frontend distributions
- Regional vs Global: WAF in us-east-1 (required for CloudFront)
- Pricing: CloudFront $0.085/GB (US), WAF $5/month + $0.60 per rule
- DDoS Protection: CloudFront provides standard DDoS mitigation; AWS Shield Standard is free
- Custom domains: Require ACM certificate (must be in us-east-1 for CloudFront)
- Logging: Enable CloudFront access logs to S3 (separate bucket, recommended)
