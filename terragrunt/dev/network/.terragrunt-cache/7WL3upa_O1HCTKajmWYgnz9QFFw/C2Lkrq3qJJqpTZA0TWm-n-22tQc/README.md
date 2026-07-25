# Network Module

## Overview

This module creates a private-only VPC with tier-based subnets (web, app, database), VPC endpoints for AWS services, and tier-specific Network ACLs for network segmentation.

## Architecture

```
VPC: 10.0.0.0/16
├── Web Tier (10.0.1.0/24, 10.0.2.0/24)
│   ├── Subnet A (us-east-1a): 10.0.1.0/24
│   └── Subnet B (us-east-1b): 10.0.2.0/24
│   └── NACL: Allow inbound from app tier, outbound to app tier
│
├── App Tier (10.0.11.0/24, 10.0.12.0/24)
│   ├── Subnet A (us-east-1a): 10.0.11.0/24
│   └── Subnet B (us-east-1b): 10.0.12.0/24
│   └── NACL: Allow inbound from web tier, outbound to db tier
│
├── Database Tier (10.0.21.0/24, 10.0.22.0/24)
│   ├── Subnet A (us-east-1a): 10.0.21.0/24
│   └── Subnet B (us-east-1b): 10.0.22.0/24
│   └── NACL: Allow inbound from app tier only
│
└── VPC Endpoints (for S3, DynamoDB, EC2, ALB, CloudWatch, Secrets Manager, ECR, Logs)
    └── Security Group: Allow HTTPS (443) from VPC CIDR
```

## Features

- **No Internet Gateway**: Private-only architecture, no public internet access
- **No NAT Gateway**: Services don't need internet; AWS traffic via VPC endpoints
- **Tier-based NACLs**: Enforce network segmentation (web cannot reach db directly)
- **Multi-AZ**: All tiers span us-east-1a and us-east-1b
- **App Tier VPC Endpoints**: Configurable endpoints (S3, DynamoDB as gateway; others as interface) deployed to app tier only
- **Common Tagging**: All resources tagged consistently for cost allocation and organization
- **Optional VPC Flow Logs**: Enable for debugging connectivity issues

## Usage

### Basic Example

```hcl
module "network" {
  source = "../../modules/network"

  vpc_cidr = "10.0.0.0/16"
  
  private_subnet_cidrs = {
    web = ["10.0.1.0/24", "10.0.2.0/24"]
    app = ["10.0.11.0/24", "10.0.12.0/24"]
    db  = ["10.0.21.0/24", "10.0.22.0/24"]
  }
  
  vpc_endpoint_services = [
    "s3",
    "dynamodb",
    "ec2",
    "elasticloadbalancing",
    "cloudwatch",
    "secretsmanager",
    "ecr.api",
    "ecr.dkr",
    "logs"
  ]
  
  # Get prefix list IDs from AWS CLI:
  # aws ec2 describe-prefix-lists --filter Name=prefix-list-name,Values="com.amazonaws.us-east-1.s3" --query 'PrefixLists[0].PrefixListId'
  s3_prefix_list_id       = "pl-12345678"
  dynamodb_prefix_list_id = "pl-87654321"
  
  environment = "dev"
  project_name = "e-voting"
  
  common_tags = {
    Environment = "dev"
    Project     = "e-voting"
    ManagedBy   = "terraform"
    Team        = "platform"
  }
  
  enable_flow_logs           = false
  flow_logs_retention_days   = 7
}
```

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `vpc_cidr` | string | Yes | VPC CIDR block (e.g., "10.0.0.0/16") |
| `private_subnet_cidrs` | map(list(string)) | Yes | Tier names (web, app, db) mapped to lists of 2 CIDR blocks each |
| `vpc_endpoint_services` | list(string) | No | VPC endpoint services to create: s3, dynamodb (gateway), ec2, elasticloadbalancing, cloudwatch, secretsmanager, ecr.api, ecr.dkr, logs (interface). Default: [] (no endpoints) |
| `s3_prefix_list_id` | string | No | AWS S3 prefix list ID for app route table |
| `dynamodb_prefix_list_id` | string | No | AWS DynamoDB prefix list ID for app route table |
| `environment` | string | Yes | Environment (dev, staging, prod) |
| `project_name` | string | Yes | Project name for naming and tagging |
| `common_tags` | map(string) | No | Common tags for all resources |
| `enable_flow_logs` | bool | No | Enable VPC Flow Logs (default: false) |
| `flow_logs_retention_days` | number | No | Log retention days (default: 7) |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | VPC ID |
| `vpc_cidr` | VPC CIDR block |
| `private_subnet_ids_by_tier` | Subnet IDs organized by tier (web, app, db) |
| `private_subnet_cidrs_by_tier` | Subnet CIDR blocks organized by tier |
| `availability_zones` | Availability zones used (us-east-1a, us-east-1b) |
| `vpc_endpoint_ids` | VPC endpoint IDs by service |
| `vpc_endpoint_sg_id` | Security group ID for VPC endpoints |
| `nacl_ids_by_tier` | Network ACL IDs by tier |
| `private_route_table_ids_by_tier` | Route table IDs by tier |
| `vpc_endpoint_arns` | VPC endpoint ARNs by service |
| `subnets_by_tier_with_azs` | Detailed subnet info by tier and AZ |

## Network ACL Rules

### Web Tier
- **Inbound**: Allow TCP 1024-65535 from app tier (10.0.11.0/24, 10.0.12.0/24)
- **Outbound**: Allow TCP 8080-65535 to app tier, HTTPS (443) to VPC, DNS (53) to anywhere

### App Tier
- **Inbound**: Allow TCP 1024-65535 from web tier (10.0.1.0/24, 10.0.2.0/24)
- **Outbound**: Allow TCP 5432 to db tier (10.0.21.0/24, 10.0.22.0/24), HTTPS (443) to VPC, DNS (53) to anywhere

### Database Tier
- **Inbound**: Allow TCP 5432 from app tier (10.0.11.0/24, 10.0.12.0/24)
- **Outbound**: Allow HTTPS (443) to VPC, DNS (53) to anywhere

## VPC Endpoints

All VPC endpoints are deployed to the **App Tier** subnets only. Services passed in `vpc_endpoint_services` are automatically classified:

### Gateway Endpoints
- **s3**: Routed via app tier route table using S3 prefix list
- **dynamodb**: Routed via app tier route table using DynamoDB prefix list

### Interface Endpoints
- **ec2**: EC2 API (launch templates, security groups, etc.)
- **elasticloadbalancing**: ALB configuration and management
- **cloudwatch**: CloudWatch metrics and custom metrics
- **secretsmanager**: Database credentials, API keys, secrets
- **ecr.api**: ECR API (push/pull image metadata)
- **ecr.dkr**: Docker registry (actual image layers)
- **logs**: CloudWatch Logs (send and receive logs)

**Example**: Pass `vpc_endpoint_services = ["s3", "dynamodb", "ecr.api", "ecr.dkr", "logs"]` to create both gateway and interface endpoints.

### NACL Rules for S3/DynamoDB Access
- Gateway endpoints route through VPC local routes (via route table prefix list routes)
- App tier NACL allows outbound HTTPS (443) to VPC CIDR, which covers both gateway and interface endpoint access
- Traffic to S3 and DynamoDB prefix lists is routed by the route table to the gateway endpoints

## Getting Prefix List IDs

```bash
# S3 Prefix List ID
aws ec2 describe-prefix-lists \
  --filter Name=prefix-list-name,Values="com.amazonaws.us-east-1.s3" \
  --query 'PrefixLists[0].PrefixListId'

# DynamoDB Prefix List ID
aws ec2 describe-prefix-lists \
  --filter Name=prefix-list-name,Values="com.amazonaws.us-east-1.dynamodb" \
  --query 'PrefixLists[0].PrefixListId'
```

## Testing with LocalStack

```bash
# Start LocalStack
docker run -d -p 4566:4566 -e SERVICES=ec2 localstack/localstack:4.4.0

# Configure
export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"

# Initialize and apply
tofu init
tofu plan
tofu apply -auto-approve

# Validate
aws --endpoint-url=http://localhost:4566 ec2 describe-vpcs
aws --endpoint-url=http://localhost:4566 ec2 describe-subnets
aws --endpoint-url=http://localhost:4566 ec2 describe-network-acls
aws --endpoint-url=http://localhost:4566 ec2 describe-route-tables

# Cleanup
tofu destroy -auto-approve
docker stop $(docker ps -q --filter "ancestor=localstack/localstack:4.4.0")
```

## Cost Considerations

- **VPC**: Free
- **Subnets**: Free (6 subnets)
- **Route Tables**: Free (3 route tables)
- **NACLs**: Free (3 NACLs)
- **Gateway Endpoints** (S3, DynamoDB): Free
- **Interface Endpoints**: ~$7.20/month each + $0.01 per GB data processed
  - EC2, ALB, CloudWatch, Secrets Manager, ECR (API), ECR (DKR), Logs = 7 endpoints = ~$50/month
- **VPC Flow Logs** (optional): ~$0.50 per GB ingested + $0.03 per GB stored

## Notes

- NACL rules are stateless; responses require ephemeral port rules
- Prefix list IDs change between regions (must get for specific region)
- S3 and DynamoDB gateway endpoints don't incur additional costs
- Interface endpoints charge for hourly usage + data processing
- VPC Flow Logs useful for troubleshooting network connectivity
- Consider using security groups at compute layer for additional security

## Integration with Other Modules

- **database**: Uses `private_subnet_ids_by_tier[db]` for RDS subnet group
- **platform**: Uses `private_subnet_ids_by_tier[web]` for ALB placement, `private_subnet_ids_by_tier[app]` for ECS tasks
- **ecs-services**: Uses `vpc_endpoint_ids` for ECR and Secrets Manager access
- **monitoring**: Uses `vpc_id` for alarm resources

## Troubleshooting

### VPC Endpoint Connection Issues
- Verify security group allows HTTPS (443) from VPC CIDR
- Check NACL rules allow outbound HTTPS (443)
- Confirm route table has VPC endpoint routes

### NACL Rule Violations
- Web tier cannot reach database tier (blocked at NACL level)
- Verify rule numbers (lower = higher priority)
- Use VPC Flow Logs to debug blocked traffic

### Subnet Spanning AZs
- Verify 2 subnets per tier exist
- Check AZ assignment (us-east-1a, us-east-1b)
- Confirm route table associations for both subnets
