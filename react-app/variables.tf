variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
}

variable "certificate_arn" {
  description = "The ACM certificate ARN for the CloudFront distribution"
  type        = string
}

variable "domain_alias" {
  description = "The domain alias for the CloudFront distribution"
  type        = string
}
