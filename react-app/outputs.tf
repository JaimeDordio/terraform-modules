# frontend_module/outputs.tf

output "s3_bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.frontend_bucket.bucket
}

output "s3_bucket_website_endpoint" {
  description = "The website endpoint of the S3 bucket"
  value       = aws_s3_bucket_website_configuration.frontend_s3_bucket_website_configuration.website_endpoint
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.frontend_cf_distribution.id
}

output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.frontend_cf_distribution.domain_name
}

output "cloudfront_aliases" {
  description = "The domain aliases configured for the CloudFront distribution"
  value       = aws_cloudfront_distribution.frontend_cf_distribution.aliases
}
