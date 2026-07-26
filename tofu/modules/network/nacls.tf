# Step 7 & 8: Create Tier-specific Network ACLs and Define NACL Rules
# Creates 3 Network ACLs (one per tier: web, app, db)
# Defines tier-based traffic rules: web → app → db, with egress for DNS/HTTPS

# Step 7: Create Network ACLs for each tier
resource "aws_network_acl" "tier" {
  for_each = toset(["web", "app", "db"])

  vpc_id     = aws_vpc.main.id
  subnet_ids = [for subnet_key, subnet in aws_subnet.private : subnet.id if split("-", subnet_key)[0] == each.value]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${each.value}-nacl"
      Tier = each.value
    }
  )
}

# Step 8: Define NACL Rules for tier-based traffic control
# Rule numbering: 100-199 (inbound), 1000-1099 (outbound)
# Traffic flow: web → app (8080) → db (5432)

locals {
  # NACL rule definitions by tier
  nacl_rules = {
    # WEB TIER: Accepts traffic from app tier (ephemeral ports)
    web = {
      inbound = [
        {
          rule_no    = 100
          protocol   = "tcp"
          from_port  = 1024
          to_port    = 65535
          cidr_block = local.subnets_by_tier["app"]["us-east-1a"]
          egress     = false
        },
        {
          rule_no    = 101
          protocol   = "tcp"
          from_port  = 1024
          to_port    = 65535
          cidr_block = local.subnets_by_tier["app"]["us-east-1b"]
          egress     = false
        },
        # {
        #   rule_no    = 102
        #   protocol   = "tcp"
        #   from_port  = 443
        #   to_port    = 443
        #   cidr_block = "0.0.0.0/0"
        #   egress     = false
        # },
        # {
        #   rule_no    = 103
        #   protocol   = "udp"
        #   from_port  = 53
        #   to_port    = 53
        #   cidr_block = "0.0.0.0/0"
        #   egress     = false
        # }
      ]
      outbound = [
        {
          rule_no    = 1000
          protocol   = "tcp"
          from_port  = 8080
          to_port    = 8080
          cidr_block = local.subnets_by_tier["app"]["us-east-1a"]
          egress     = true
        },
        {
          rule_no    = 1001
          protocol   = "tcp"
          from_port  = 8080
          to_port    = 8080
          cidr_block = local.subnets_by_tier["app"]["us-east-1b"]
          egress     = true
        },
        # {
        #   rule_no    = 1002
        #   protocol   = "tcp"
        #   from_port  = 443
        #   to_port    = 443
        #   cidr_block = "0.0.0.0/0"
        #   egress     = true
        # },
        # {
        #   rule_no    = 1003
        #   protocol   = "udp"
        #   from_port  = 53
        #   to_port    = 53
        #   cidr_block = "0.0.0.0/0"
        #   egress     = true
        # }
      ]
    }

    # APP TIER: Accepts from web, forwards to db
    app = {
      inbound = [
        {
          rule_no    = 100
          protocol   = "tcp"
          from_port  = 1024
          to_port    = 65535
          cidr_block = local.subnets_by_tier["web"]["us-east-1a"]
          egress     = false
        },
        {
          rule_no    = 101
          protocol   = "tcp"
          from_port  = 1024
          to_port    = 65535
          cidr_block = local.subnets_by_tier["web"]["us-east-1b"]
          egress     = false
        },
        # {
        #   rule_no    = 102
        #   protocol   = "tcp"
        #   from_port  = 443
        #   to_port    = 443
        #   cidr_block = "0.0.0.0/0"
        #   egress     = false
        # },
        # {
        #   rule_no    = 103
        #   protocol   = "udp"
        #   from_port  = 53
        #   to_port    = 53
        #   cidr_block = "0.0.0.0/0"
        #   egress     = false
        # }
      ]
      outbound = [
        {
          rule_no    = 1000
          protocol   = "tcp"
          from_port  = 5432
          to_port    = 5432
          cidr_block = local.subnets_by_tier["db"]["us-east-1a"]
          egress     = true
        },
        {
          rule_no    = 1001
          protocol   = "tcp"
          from_port  = 5432
          to_port    = 5432
          cidr_block = local.subnets_by_tier["db"]["us-east-1b"]
          egress     = true
        },
        # {
        #   rule_no    = 1002
        #   protocol   = "tcp"
        #   from_port  = 443
        #   to_port    = 443
        #   cidr_block = "0.0.0.0/0"
        #   egress     = true
        # },
        # {
        #   rule_no    = 1003
        #   protocol   = "udp"
        #   from_port  = 53
        #   to_port    = 53
        #   cidr_block = "0.0.0.0/0"
        #   egress     = true
        # }
      ]
    }

    # DB TIER: Accepts only from app tier (port 5432)
    db = {
      inbound = [
        {
          rule_no    = 100
          protocol   = "tcp"
          from_port  = 5432
          to_port    = 5432
          cidr_block = local.subnets_by_tier["app"]["us-east-1a"]
          egress     = false
        },
        {
          rule_no    = 101
          protocol   = "tcp"
          from_port  = 5432
          to_port    = 5432
          cidr_block = local.subnets_by_tier["app"]["us-east-1b"]
          egress     = false
        },
        # {
        #   rule_no    = 102
        #   protocol   = "tcp"
        #   from_port  = 443
        #   to_port    = 443
        #   cidr_block = "0.0.0.0/0"
        #   egress     = false
        # },
        # {
        #   rule_no    = 103
        #   protocol   = "udp"
        #   from_port  = 53
        #   to_port    = 53
        #   cidr_block = "0.0.0.0/0"
        #   egress     = false
        # }
      ]
      outbound = [
        {
          rule_no    = 1000
          protocol   = "tcp"
          from_port  = 443
          to_port    = 443
          cidr_block = "0.0.0.0/0"
          egress     = true
        },
        {
          rule_no    = 1001
          protocol   = "udp"
          from_port  = 53
          to_port    = 53
          cidr_block = "0.0.0.0/0"
          egress     = true
        }
      ]
    }
  }

  # Flatten NACL rules for resource creation
  flattened_nacl_rules = merge([
    for tier, rules in local.nacl_rules : {
      for type, rule_list in rules : "${tier}-${type}" => [
        for idx, rule in rule_list : {
          tier       = tier
          type       = type
          rule_no    = rule.rule_no
          protocol   = rule.protocol
          from_port  = rule.from_port
          to_port    = rule.to_port
          cidr_block = rule.cidr_block
          egress     = rule.egress
          key        = "${tier}-${type}-${idx}"
        }
      ]
    }
  ]...)

  # Create a flat list for for_each
  all_nacl_rules = merge([
    for tier_type, rules in local.flattened_nacl_rules : {
      for rule in rules : rule.key => rule
    }
  ]...)
}

# Create NACL rules using flattened structure
resource "aws_network_acl_rule" "tier" {
  for_each = local.all_nacl_rules

  network_acl_id = aws_network_acl.tier[each.value.tier].id

  rule_number = each.value.rule_no
  protocol    = each.value.protocol
  rule_action = "allow"
  egress      = each.value.egress
  cidr_block  = each.value.cidr_block
  from_port   = each.value.from_port
  to_port     = each.value.to_port
}
