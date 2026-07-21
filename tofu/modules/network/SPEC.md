# Network Module Specification

## Purpose
Create a private-only VPC with multi-AZ tier-based subnets (web, app, db), VPC endpoints for AWS services, and tier-specific NACLs for network segmentation without internet exposure.

## Inputs

| Variable | Type | Description | Required | Example |
|----------|------|-------------|----------|---------|
| `vpc_cidr` | string | CIDR block for VPC | Yes | `"10.0.0.0/16"` |
| `private_subnet_cidrs` | map(list(string)) | CIDR blocks by tier (web, app, db), 2 AZs each | Yes | `{web: ["10.0.1.0/24", "10.0.2.0/24"], app: ["10.0.11.0/24", "10.0.12.0/24"], db: ["10.0.21.0/24", "10.0.22.0/24"]}` |
| `vpc_endpoint_services` | list(string) | AWS services for VPC endpoints | Yes | `["s3", "dynamodb", "ec2", "elasticloadbalancing", "cloudwatch", "secretsmanager", "ecr.api", "ecr.dkr", "logs"]` |
| `s3_prefix_list_id` | string | AWS S3 prefix list ID for region (optional) | No | `"pl-12345678"` |
| `dynamodb_prefix_list_id` | string | AWS DynamoDB prefix list ID for region (optional) | No | `"pl-87654321"` |
| `environment` | string | Environment name (dev/staging/prod) | Yes | `"dev"` |
| `project_name` | string | Project name for resource tagging | Yes | `"e-voting"` |
| `common_tags` | map(string) | Common tags for all resources | Yes | `{Environment: "dev", Project: "e-voting", ManagedBy: "terraform"}` |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `vpc_id` | string | VPC ID |
| `vpc_cidr` | string | VPC CIDR block |
| `private_subnet_ids_by_tier` | map(list(string)) | Private subnet IDs organized by tier (web, app, db) |
| `private_subnet_cidrs_by_tier` | map(list(string)) | Private subnet CIDR blocks organized by tier |
| `availability_zones` | list(string) | Availability zones used (us-east-1a, us-east-1b) |
| `vpc_endpoint_ids` | map(string) | VPC endpoint IDs by service |
| `vpc_endpoint_sg_id` | string | Security group ID for VPC endpoint access |
| `nacl_ids_by_tier` | map(string) | Network ACL IDs by tier (web, app, db) |
| `private_route_table_ids_by_tier` | map(string) | Route table IDs by tier |

## Resources

- **aws_vpc**: Main VPC (10.0.0.0/16)
- **aws_subnet** (6x): Private subnets organized by tier (web, app, db), 2 per tier in different AZs
- **aws_route_table** (3x): One per tier with local route only
- **aws_route_table_association** (6x): Attach subnets to tier-specific route tables
- **aws_vpc_endpoint** (multiple): For services in `vpc_endpoint_services` list
- **aws_vpc_endpoint_route_table_association**: Associate S3/DynamoDB endpoints with route tables
- **aws_network_acl** (3x): One per tier (web, app, db) for network segmentation
- **aws_network_acl_rule** (multiple): Tier-specific ingress/egress rules
- **aws_security_group**: For VPC endpoint access (HTTPS 443)

## Security

### Network ACLs (Tier-Specific)
**Web Tier**:
- Inbound: Allow from ALB (app tier) only
- Outbound: Allow to app tier (port 8080+), VPC endpoints (443), DNS (53)
- Block: Database tier traffic (db subnet CIDR)

**App Tier**:
- Inbound: Allow from web tier (dynamic ports)
- Outbound: Allow to db tier (5432), VPC endpoints (443), DNS (53)
- Block: Direct database access from web tier

**Database Tier**:
- Inbound: Allow from app tier (5432) only
- Outbound: Allow VPC endpoints (443), DNS (53)
- Block: All other inbound traffic

### Security Groups
- **VPC Endpoint SG**: Allow inbound HTTPS (443) from VPC CIDR
- Tier subnets assigned to endpoint security group

### Route Tables
- All tiers: Route VPC CIDR (10.0.0.0/16) to local
- S3/DynamoDB endpoints: Associated with route tables (prefix list routes if specified)
- No default route to internet or NAT gateway

### Compliance
- No public internet access from data plane
- No NAT gateway (services don't access internet)
- Tier-based network segmentation (web cannot reach db directly)
- All AWS service communication via VPC endpoints (PrivateLink)
- Least privilege: Each tier has minimal necessary outbound rules

## Testing

### Expected Behavior
- VPC created with specified CIDR block (10.0.0.0/16)
- 6 private subnets created (2 per tier: web, app, db), spanning us-east-1a and us-east-1b
- VPC endpoints created for each service in `vpc_endpoint_services` list
- NACLs created and rules applied per tier
- Route tables created (one per tier) with VPC local routes
- S3/DynamoDB prefix list routes added (if IDs provided)
- No internet gateway or NAT gateway attached
- Common tags applied to all resources

### Edge Cases
- Test NACL rules: Web tier cannot reach DB tier directly (blocked by NACL)
- Verify app tier can reach both web and db tiers
- Test VPC endpoint connectivity from all tiers (HTTPS 443)
- Validate ephemeral ports allowed for internal communication
- Confirm S3/DynamoDB prefix list routes added to correct route tables
- Test subnet spanning across both AZs (us-east-1a, us-east-1b)

### LocalStack Testing
```bash
# Start LocalStack
docker run -d -p 4566:4566 -e SERVICES=ec2 localstack/localstack:4.4.0

# Configure
export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"

# Test
tofu init
tofu plan
tofu apply -auto-approve

# Validate
aws --endpoint-url=http://localhost:4566 ec2 describe-vpcs
aws --endpoint-url=http://localhost:4566 ec2 describe-subnets
aws --endpoint-url=http://localhost:4566 ec2 describe-network-acls
aws --endpoint-url=http://localhost:4566 ec2 describe-vpc-endpoints
aws --endpoint-url=http://localhost:4566 ec2 describe-route-tables

# Test NACL rules (web cannot reach db)
aws --endpoint-url=http://localhost:4566 ec2 describe-network-acl-entries \
  --network-acl-id acl-12345

# Destroy
tofu destroy -auto-approve
```

## Dependencies
- None (foundation module)

## Module Integration Points
- Output `vpc_id` used by: database, platform, s3-frontend, monitoring
- Output `private_subnet_ids_by_tier` used by: platform (web tier), ecs-services (app tier), database (db tier)
- Output `vpc_endpoint_ids` used by: ecs-services (ECR, Secrets Manager access)
- Output `nacl_ids_by_tier` provides reference for audit/troubleshooting

## Notes
- No NAT gateway needed (services are fully private, AWS traffic via VPC endpoints)
- Tier-based NACL rules enforce network segmentation without security groups
- S3/DynamoDB prefix list IDs can be obtained: `aws ec2 describe-prefix-lists --filter Name=prefix-list-name,Values="com.amazonaws.region.s3"`
- VPC endpoint pricing: ~$7.20/month per endpoint + data transfer
- Consider VPC Flow Logs for security auditing (not included in this module)
- NACL rules are stateless (must define both inbound and outbound)
- Route tables use prefix list IDs for S3/DynamoDB routing (reduces internet gateway requirement)
