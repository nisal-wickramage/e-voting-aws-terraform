# Step 2: Create VPC Endpoints Security Group
# Allows inbound HTTPS (443) from VPC CIDR for interface endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-vpc-endpoints-sg"
    }
  )
}

# Step 9: Create VPC Endpoints
# Services are dynamically configured via var.vpc_endpoint_services
# Gateway endpoints (s3, dynamodb) are associated with all route tables
# Interface endpoints (others) are placed in app tier subnets

locals {
  # Map service names to AWS endpoint service names
  service_name_map = {
    s3                = "com.amazonaws.${var.aws_region}.s3"
    dynamodb          = "com.amazonaws.${var.aws_region}.dynamodb"
    ec2               = "com.amazonaws.${var.aws_region}.ec2"
    elasticloadbalancing = "com.amazonaws.${var.aws_region}.elasticloadbalancing"
    cloudwatch        = "com.amazonaws.${var.aws_region}.monitoring"
    secretsmanager    = "com.amazonaws.${var.aws_region}.secretsmanager"
    "ecr.api"         = "com.amazonaws.${var.aws_region}.ecr.api"
    "ecr.dkr"         = "com.amazonaws.${var.aws_region}.ecr.dkr"
    logs              = "com.amazonaws.${var.aws_region}.logs"
  }

  # Gateway endpoints (have route table association instead of subnet placement)
  gateway_services = toset(["s3", "dynamodb"])

  # Interface endpoints (placed in subnets)
  interface_services = [for service in var.vpc_endpoint_services : service if !contains(local.gateway_services, service)]
  gateway_endpoint_services = [for service in var.vpc_endpoint_services : service if contains(local.gateway_services, service)]
}

# Gateway VPC Endpoints (S3, DynamoDB)
resource "aws_vpc_endpoint" "gateway" {
  for_each = toset(local.gateway_endpoint_services)

  vpc_id              = aws_vpc.main.id
  service_name        = local.service_name_map[each.value]
  vpc_endpoint_type   = "Gateway"
  route_table_ids     = [for rt in aws_route_table.tier : rt.id]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${each.value}-vpc-endpoint"
    }
  )
}

# Interface VPC Endpoints (ECR, CloudWatch Logs, Secrets Manager, etc.)
resource "aws_vpc_endpoint" "interface" {
  for_each = toset(local.interface_services)

  vpc_id              = aws_vpc.main.id
  service_name        = local.service_name_map[each.value]
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  # Place in app tier subnets for centralized access
  subnet_ids = [
    aws_subnet.private["app-us-east-1a"].id,
    aws_subnet.private["app-us-east-1b"].id
  ]

  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${each.value}-vpc-endpoint"
    }
  )
}
