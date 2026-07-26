output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

# Step 1: VPC Complete
# Step 2: VPC Endpoints Security Group Complete
# Step 4: Subnets Complete
# Step 5-6: Route Tables & Associations Complete
# Step 7-8: Network ACLs & Rules Complete
# Step 9: VPC Endpoints Complete
# All steps implemented!

output "private_subnet_ids_by_tier" {
  description = "Private subnet IDs organized by tier (web, app, db)"
  value = {
    for tier in keys(local.flattened_subnets) :
    tier => [
      for az, subnet_id in {
        for key, subnet in aws_subnet.private :
        subnet.availability_zone => subnet.id if split("-", key)[0] == tier
      } : subnet_id
    ]
  }
}

output "private_subnet_cidrs_by_tier" {
  description = "Private subnet CIDR blocks organized by tier"
  value = {
    for tier, azs in local.flattened_subnets :
    tier => {
      for az, cidr in azs : az => cidr
    }
  }
}

output "availability_zones" {
  description = "Availability zones used"
  value       = var.availability_zones
}

output "vpc_endpoint_ids" {
  description = "VPC endpoint IDs by service"
  value = merge(
    { for service, endpoint in aws_vpc_endpoint.gateway : service => endpoint.id },
    { for service, endpoint in aws_vpc_endpoint.interface : service => endpoint.id }
  )
}

output "vpc_endpoint_arns" {
  description = "VPC endpoint ARNs by service"
  value = merge(
    { for service, endpoint in aws_vpc_endpoint.gateway : service => endpoint.arn },
    { for service, endpoint in aws_vpc_endpoint.interface : service => endpoint.arn }
  )
}

output "vpc_endpoint_sg_id" {
  description = "Security group ID for VPC endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

output "nacl_ids_by_tier" {
  description = "Network ACL IDs by tier (web, app, db)"
  value = {
    for tier, nacl in aws_network_acl.tier :
    tier => nacl.id
  }
}

output "private_route_table_ids_by_tier" {
  description = "Route table IDs by tier (web, app, db)"
  value = {
    for tier, rt in aws_route_table.tier :
    tier => rt.id
  }
}

output "subnets_by_tier_with_azs" {
  description = "Detailed subnet info by tier and AZ"
  value = {
    for tier, azs in local.flattened_subnets :
    tier => {
      for az, cidr in azs : az => {
        subnet_id          = aws_subnet.private["${tier}-${az}"].id
        cidr_block         = aws_subnet.private["${tier}-${az}"].cidr_block
        availability_zone  = az
        availability_zone_id = aws_subnet.private["${tier}-${az}"].availability_zone_id
      }
    }
  }
}
