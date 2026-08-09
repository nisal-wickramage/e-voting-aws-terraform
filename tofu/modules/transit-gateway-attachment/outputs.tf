output "tgw_attachment_id" {
  value       = aws_ec2_transit_gateway_attachment.main.id
  description = "Transit gateway attachment ID"
}

output "tgw_attachment_arn" {
  value       = aws_ec2_transit_gateway_attachment.main.arn
  description = "Transit gateway attachment ARN"
}

output "routes_created" {
  value       = length(aws_route.tgw)
  description = "Number of routes created to transit gateway"
}

output "nacl_rules_created" {
  value = {
    http_out      = length(aws_network_acl_rule.tgw_http_out)
    https_out     = length(aws_network_acl_rule.tgw_https_out)
    ephemeral_in  = length(aws_network_acl_rule.tgw_ephemeral_in)
  }
  description = "Number of NACL rules created by type"
}

output "sg_rules_created" {
  value = {
    http  = try(aws_security_group_rule.tgw_http_egress[0].id, null)
    https = try(aws_security_group_rule.tgw_https_egress[0].id, null)
  }
  description = "Security group rule IDs"
}
