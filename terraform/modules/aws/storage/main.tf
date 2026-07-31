resource "random_id" "suffix" {
  count = var.bucket_suffix == "" ? 1 : 0

  byte_length = 4
}

locals {
  # S3 bucket names are globally unique, so a deterministic name collides across
  # accounts. Callers who manage their own naming can pin it with bucket_suffix.
  suffix = var.bucket_suffix != "" ? var.bucket_suffix : random_id.suffix[0].hex

  private_bucket_name = "${var.name}-artifacts-${local.suffix}"
  public_bucket_name  = "${var.name}-artifacts-public-${local.suffix}"
}

# --------------------------------------------------------------------------
# Private bucket — run artifacts, uploaded files, knowledge-base source docs.
# --------------------------------------------------------------------------

resource "aws_s3_bucket" "private" {
  bucket        = local.private_bucket_name
  force_destroy = var.force_destroy
  tags          = merge(var.tags, { Name = local.private_bucket_name })
}

resource "aws_s3_bucket_ownership_controls" "private" {
  bucket = aws_s3_bucket.private.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "private" {
  bucket = aws_s3_bucket.private.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "private" {
  bucket = aws_s3_bucket.private.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null
  }
}

resource "aws_s3_bucket_versioning" "private" {
  bucket = aws_s3_bucket.private.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "private" {
  count = var.noncurrent_version_expiration_days > 0 ? 1 : 0

  bucket     = aws_s3_bucket.private.id
  depends_on = [aws_s3_bucket_versioning.private]

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "private" {
  count = length(var.cors_allowed_origins) > 0 ? 1 : 0

  bucket = aws_s3_bucket.private.id

  cors_rule {
    allowed_methods = ["GET", "PUT", "POST", "HEAD"]
    allowed_origins = var.cors_allowed_origins
    allowed_headers = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# --------------------------------------------------------------------------
# Public bucket — whitelabel and integration assets the platform expects to be
# fetchable without a platform session.
#
# Default is still fully private: the app can serve these through presigned URLs,
# which keeps the bucket closed. Flip public_read only if you front the bucket
# directly (CDN, static host) and accept anonymous GETs on every object in it.
# --------------------------------------------------------------------------

resource "aws_s3_bucket" "public" {
  bucket        = local.public_bucket_name
  force_destroy = var.force_destroy
  tags          = merge(var.tags, { Name = local.public_bucket_name })
}

resource "aws_s3_bucket_ownership_controls" "public" {
  bucket = aws_s3_bucket.public.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "public" {
  bucket = aws_s3_bucket.public.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = !var.public_read
  restrict_public_buckets = !var.public_read
}

resource "aws_s3_bucket_server_side_encryption_configuration" "public" {
  bucket = aws_s3_bucket.public.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "public_read" {
  count = var.public_read ? 1 : 0

  bucket     = aws_s3_bucket.public.id
  depends_on = [aws_s3_bucket_public_access_block.public]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AnonymousRead"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.public.arn}/*"
    }]
  })
}

resource "aws_s3_bucket_cors_configuration" "public" {
  count = length(var.cors_allowed_origins) > 0 ? 1 : 0

  bucket = aws_s3_bucket.public.id

  cors_rule {
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = var.cors_allowed_origins
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}
