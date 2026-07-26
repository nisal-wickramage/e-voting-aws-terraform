# Step 5 & 6: Create Single Route Table and Associate All Subnets
# Creates 1 route table for all tiers with local routes
# NACLs handle tier-specific traffic filtering
# Associates all 6 subnets to the single route table

# Step 5: Create Single Route Table for all subnets
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  # Local route for VPC CIDR (automatically created but explicit for clarity)
  route {
    cidr_block = aws_vpc.main.cidr_block
    gateway_id = "local"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-main-rt"
    }
  )
}

# Step 6: Associate all subnets to the single route table
resource "aws_route_table_association" "subnet_to_main_rt" {
  for_each = local.all_subnets

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.main.id
}
