terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "5.22.0"
      configuration_aliases = [aws.primary_region]
    }
  }
}

locals {
  s3_origin_id = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
}

data "aws_iam_policy_document" "frontend_s3_policy" {
  statement {
    actions = [
      "s3:PutBucketPolicy",
      "s3:GetBucketPolicy",
      "s3:PutObject",
      "s3:GetObject"
    ]
    resources = [
      "${aws_s3_bucket.frontend_bucket.arn}/*",
      aws_s3_bucket.frontend_bucket.arn
    ]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

data "aws_cloudfront_cache_policy" "cdn_managed_caching_disabled_cache_policy" {
  name = "Managed-CachingOptimized"
}

resource "aws_s3_bucket" "frontend_bucket" {
  bucket = var.bucket_name

  tags = {
    Name = var.bucket_name
  }
}

resource "aws_s3_bucket_policy" "frontend_s3_bucket_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = data.aws_iam_policy_document.frontend_s3_policy.json
}

resource "aws_s3_bucket_public_access_block" "frontend_s3_bucket_block_public_access" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "frontend_s3_bucket_website_configuration" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_cloudfront_origin_access_identity" "frontend_oai" {
  comment = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
}

resource "aws_cloudfront_distribution" "frontend_cf_distribution" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.frontend_s3_bucket_website_configuration.website_endpoint
    origin_id   = local.s3_origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  comment = "CloudFront distribution for bucket ${var.bucket_name}"

  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2"
  price_class         = "PriceClass_100"
  retain_on_delete    = true
  default_root_object = "index.html"

  aliases = [var.domain_alias]

  viewer_certificate {
    acm_certificate_arn = var.certificate_arn
    ssl_support_method  = "sni-only"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    cache_policy_id = data.aws_cloudfront_cache_policy.cdn_managed_caching_disabled_cache_policy.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  custom_error_response {
    error_caching_min_ttl = 0
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}
