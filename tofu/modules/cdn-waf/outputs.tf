output "api_cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.alb.domain_name
  description = "CloudFront domain name for API distribution (ALB origin)"
}

output "api_cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.alb.id
  description = "CloudFront distribution ID for API"
}

output "api_cloudfront_etag" {
  value       = aws_cloudfront_distribution.alb.etag
  description = "ETag of the API CloudFront distribution"
}

output "frontend_cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.s3.domain_name
  description = "CloudFront domain name for frontend distribution (S3 origin)"
}

output "frontend_cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.s3.id
  description = "CloudFront distribution ID for frontend"
}

output "frontend_cloudfront_etag" {
  value       = aws_cloudfront_distribution.s3.etag
  description = "ETag of the frontend CloudFront distribution"
}

output "waf_web_acl_id" {
  value       = var.enable_waf ? aws_wafv2_web_acl.cdn[0].id : null
  description = "WAF WebACL ID (if enabled)"
}

output "waf_web_acl_arn" {
  value       = var.enable_waf ? aws_wafv2_web_acl.cdn[0].arn : null
  description = "WAF WebACL ARN (if enabled)"
}

output "api_distribution_invoke_url" {
  value       = "https://${aws_cloudfront_distribution.alb.domain_name}${var.alb_origin_path}/"
  description = "CloudFront URL for API endpoints (via ALB)"
}

output "frontend_distribution_invoke_url" {
  value       = "https://${aws_cloudfront_distribution.s3.domain_name}/"
  description = "CloudFront URL for frontend assets (via S3)"
}
