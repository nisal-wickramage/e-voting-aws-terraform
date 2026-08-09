# ============================================================
# Transit Gateway Attachment
# ============================================================

resource "aws_ec2_transit_gateway_attachment" "main" {
  subnet_ids             = var.subnet_ids
  transit_gateway_id     = var.transit_gateway_id
  vpc_id                 = var.vpc_id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-tgw-attachment-${var.environment}"
    }
  )
}

# ============================================================
# Routes to Transit Gateway
# ============================================================

resource "aws_route" "tgw" {
  for_each = toset(var.route_table_ids)

  route_table_id         = each.value
  destination_cidr_block = var.http_endpoint_cidr
  transit_gateway_id     = var.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_attachment.main]
}

# ============================================================
# NACL Rules for HTTP/HTTPS Traffic to Transit Gateway
# ============================================================

# Outbound HTTP Rule (ephemeral port range)
resource "aws_network_acl_rule" "tgw_http_out" {
  for_each = merge([
    for tier, nacl_ids in var.nacl_ids_by_tier : {
      for nacl_id in nacl_ids : "${tier}-http-out" => {
        nacl_id  = nacl_id
        protocol = "tcp"
        port     = 80
      }
    }
  ]...)

  network_acl_id = each.value.nacl_id
  rule_number    = 150 + index(keys(merge([for tier, nacl_ids in var.nacl_ids_by_tier : {for nacl_id in nacl_ids : "${tier}-http-out" => nacl_id}]...)), each.key)
  egress         = true
  protocol       = each.value.protocol
  rule_action    = "allow"
  cidr_block     = var.http_endpoint_cidr
  from_port      = each.value.port
  to_port        = each.value.port
}

# Outbound HTTPS Rule (ephemeral port range)
resource "aws_network_acl_rule" "tgw_https_out" {
  for_each = merge([
    for tier, nacl_ids in var.nacl_ids_by_tier : {
      for nacl_id in nacl_ids : "${tier}-https-out" => {
        nacl_id  = nacl_id
        protocol = "tcp"
        port     = 443
      }
    }
  ]...)

  network_acl_id = each.value.nacl_id
  rule_number    = 160 + index(keys(merge([for tier, nacl_ids in var.nacl_ids_by_tier : {for nacl_id in nacl_ids : "${tier}-https-out" => nacl_id}]...)), each.key)
  egress         = true
  protocol       = each.value.protocol
  rule_action    = "allow"
  cidr_block     = var.http_endpoint_cidr
  from_port      = each.value.port
  to_port        = each.value.port
}

# Inbound ephemeral port rule for responses
resource "aws_network_acl_rule" "tgw_ephemeral_in" {
  for_each = merge([
    for tier, nacl_ids in var.nacl_ids_by_tier : {
      for nacl_id in nacl_ids : "${tier}-ephemeral-in" => nacl_id
    }
  ]...)

  network_acl_id = each.value
  rule_number    = 170
  ingress        = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.http_endpoint_cidr
  from_port      = 1024
  to_port        = 65535
}

# ============================================================
# Security Group Rules for HTTP/HTTPS Traffic
# ============================================================

resource "aws_security_group_rule" "tgw_http_egress" {
  count             = var.enable_http_traffic ? 1 : 0
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [var.http_endpoint_cidr]
  security_group_id = var.security_group_id
  description       = "Allow HTTP traffic to HTTP endpoint via TGW"
}

resource "aws_security_group_rule" "tgw_https_egress" {
  count             = var.enable_https_traffic ? 1 : 0
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.http_endpoint_cidr]
  security_group_id = var.security_group_id
  description       = "Allow HTTPS traffic to HTTP endpoint via TGW"
}
