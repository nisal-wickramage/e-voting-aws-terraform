# Step 5 & 6: Create Tier-specific Route Tables and Associate Subnets
# Creates 3 route tables (one per tier: web, app, db) with local routes
# Associates all 6 subnets to their respective tier route table

# Step 5: Create Route Tables for each tier
resource "aws_route_table" "tier" {
  for_each = toset(["web", "app", "db"])

  vpc_id = aws_vpc.main.id

  # Local route for VPC CIDR (automatically created but explicit for clarity)
  route {
    cidr_block = aws_vpc.main.cidr_block
    gateway_id = "local"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${each.value}-rt"
      Tier = each.value
    }
  )
}

# Step 6: Associate subnets to their tier-specific route tables
resource "aws_route_table_association" "subnet_to_tier_rt" {
  for_each = local.all_subnets

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.tier[each.value.tier].id
}
