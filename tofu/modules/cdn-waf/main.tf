# AWS WAF WebACL for CloudFront Protection
resource "aws_wafv2_web_acl" "cdn" {
  count = var.enable_waf ? 1 : 0

  name  = "${var.project_name}-${var.environment}-cdn-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # Rule 1: Rate Limiting (Adaptive rate limiting per IP)
  rule {
    name     = "RateLimitRule"
    priority = 1

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    action {
      block {
        custom_response {
          response_code = 429
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed Rules (Common Rule Set - OWASP Top 10)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # Exclude rules that may cause false positives
        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            count {}
          }
        }
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetrics"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: Known Bad Inputs (SQLi, XSS, etc.)
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSetMetrics"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: Geographic Blocking (Optional)
  dynamic "rule" {
    for_each = var.waf_geo_blocking_enabled && length(var.waf_geo_blocked_countries) > 0 ? [1] : []

    content {
      name     = "GeoBlockingRule"
      priority = 4

      statement {
        geo_match_statement {
          country_codes = var.waf_geo_blocked_countries
        }
      }

      action {
        block {}
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "GeoBlockingRule"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-cdn-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-cdn-waf"
    Environment = var.environment
    Module      = "cdn-waf"
  })
}

# CloudFront Distribution for ALB (API)
resource "aws_cloudfront_distribution" "alb" {
  origin {
    domain_name = var.alb_domain_name
    origin_id   = "alb-origin"
    origin_path = var.alb_origin_path

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = ""
  comment             = "${var.project_name}-${var.environment}-api-cdn"

  # Cache behavior for API endpoints
  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]

    target_origin_id = "alb-origin"

    viewer_protocol_policy = var.viewer_protocol_policy
    compress               = var.compress

    forwarded_values {
      query_string = true

      cookies {
        forward = "all"
      }

      headers = [
        "Accept",
        "Accept-Charset",
        "Accept-Encoding",
        "Accept-Language",
        "Authorization",
        "Content-Type",
        "Host",
        "Referer",
        "User-Agent"
      ]
    }

    min_ttl     = 0
    default_ttl = var.default_ttl
    max_ttl     = var.max_ttl
  }

  price_class = var.environment == "prod" ? "PriceClass_100" : "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  web_acl_id = var.enable_waf ? aws_wafv2_web_acl.cdn[0].arn : null

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-api-cdn"
    Environment = var.environment
    Module      = "cdn-waf"
  })
}

# CloudFront Distribution for S3 (Frontend)
resource "aws_cloudfront_distribution" "s3" {
  origin {
    domain_name = var.s3_bucket_regional_domain_name
    origin_id   = "s3-origin"

    s3_origin_config {
      origin_access_identity = "origin-access-identity/cloudfront/${replace(var.cloudfront_oai_iam_arn, "/.*\\/(.*)/", "$1")}"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "${var.project_name}-${var.environment}-frontend-cdn"

  # Cache behavior for frontend
  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    target_origin_id = "s3-origin"

    viewer_protocol_policy = var.viewer_protocol_policy
    compress               = var.compress

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = var.default_ttl
    max_ttl     = var.max_ttl
  }

  # Cache behavior for index.html (no caching)
  ordered_cache_behavior {
    path_pattern    = "/index.html"
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    target_origin_id = "s3-origin"

    viewer_protocol_policy = var.viewer_protocol_policy
    compress               = var.compress

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  price_class = var.environment == "prod" ? "PriceClass_100" : "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  web_acl_id = var.enable_waf ? aws_wafv2_web_acl.cdn[0].arn : null

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-frontend-cdn"
    Environment = var.environment
    Module      = "cdn-waf"
  })
}

# CloudWatch Alarms for WAF
resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  count = var.enable_waf ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-waf-blocked-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alert when WAF blocks more than 10 requests in 5 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.cdn[0].name
    Region = data.aws_caller_identity.current.account_id
    Rule   = "ALL"
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-waf-blocked-requests"
    Environment = var.environment
  })
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
