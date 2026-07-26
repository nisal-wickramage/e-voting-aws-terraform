# Step 4: Create Tier-based Subnets
# Creates 6 private subnets (2 per tier: web, app, db) across 2 availability zones
# Uses dynamic for_each to flatten tier/AZ mapping for resource creation

# Flatten the subnets_by_tier map for iteration
# Input structure: { "web": {"us-east-1a": "10.0.1.0/24", ...}, ... }
# Output structure: { "web-us-east-1a": {tier, az, cidr}, ... }
locals {
  flattened_subnets = {
    for tier, azs in local.subnets_by_tier : tier => azs
  }

  # Create a flat map for for_each
  all_subnets = merge([
    for tier, azs in local.flattened_subnets : {
      for az, cidr in azs : "${tier}-${az}" => {
        tier              = tier
        availability_zone = az
        cidr_block        = cidr
      }
    }
  ]...)
}

# Create private subnets for each tier and AZ
resource "aws_subnet" "private" {
  for_each = local.all_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${each.value.tier}-subnet-${each.value.availability_zone}"
      Tier = each.value.tier
    }
  )
}
