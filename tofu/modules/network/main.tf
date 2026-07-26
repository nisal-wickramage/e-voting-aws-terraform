# Step 1: Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-vpc"
    }
  )
}

# Local values for subnet configuration
locals {
  # Flatten subnet CIDR map for easier iteration
  subnets_by_tier = {
    for tier, cidrs in var.private_subnet_cidrs : tier => {
      for idx, cidr in cidrs : var.availability_zones[idx] => cidr
    }
  }
}
