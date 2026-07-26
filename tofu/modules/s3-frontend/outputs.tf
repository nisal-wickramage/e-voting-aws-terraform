output "bucket_name" {
  value       = aws_s3_bucket.frontend.id
  description = "S3 bucket name for frontend assets"
}

output "bucket_arn" {
  value       = aws_s3_bucket.frontend.arn
  description = "S3 bucket ARN"
}

output "bucket_domain_name" {
  value       = aws_s3_bucket.frontend.bucket_regional_domain_name
  description = "Regional domain name of the S3 bucket"
}

output "bucket_regional_domain_name" {
  value       = aws_s3_bucket.frontend.bucket_regional_domain_name
  description = "Regional domain name (e.g., bucket-name.s3.us-east-1.amazonaws.com)"
}

output "cloudfront_oai_id" {
  value       = aws_cloudfront_origin_access_identity.s3_oai.id
  description = "CloudFront Origin Access Identity ID for S3 bucket"
}

output "cloudfront_oai_iam_arn" {
  value       = aws_cloudfront_origin_access_identity.s3_oai.iam_arn
  description = "CloudFront OAI IAM ARN (used in bucket policy)"
}
