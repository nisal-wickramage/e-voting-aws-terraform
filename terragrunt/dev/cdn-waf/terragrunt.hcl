# CDN + WAF Module - Development Environment Configuration (AWS)

include "root" {
  path = "../../terragrunt.hcl"
}

terraform {
  source = "../../../tofu/modules/cdn-waf"
}

dependency "platform" {
  config_path = "../platform"
  
  mock_outputs = {
    alb_dns_name = "alb-12345.us-east-1.elb.amazonaws.com"
  }
}

dependency "s3_frontend" {
  config_path = "../s3-frontend"

  mock_outputs = {
    bucket_regional_domain_name = "bucket.s3.us-east-1.amazonaws.com"
    cloudfront_oai_iam_arn      = "arn:aws:iam::123456789012:root"
  }
}

inputs = {
  project_name                      = "e-voting"
  environment                       = "dev"
  alb_domain_name                   = dependency.platform.outputs.alb_dns_name
  alb_origin_path                   = "/api"
  s3_bucket_regional_domain_name    = dependency.s3_frontend.outputs.bucket_regional_domain_name
  cloudfront_oai_iam_arn           = dependency.s3_frontend.outputs.cloudfront_oai_iam_arn

  # WAF Configuration
  enable_waf                = true
  waf_rate_limit           = 2000
  waf_geo_blocking_enabled = false
  waf_geo_blocked_countries = []

  # CloudFront Configuration
  viewer_protocol_policy = "redirect-to-https"
  compress              = true
  default_ttl           = 3600
  max_ttl              = 86400

  tags = {
    Environment = "dev"
    Project     = "e-voting"
    ManagedBy   = "terragrunt"
    Module      = "cdn-waf"
  }
}
