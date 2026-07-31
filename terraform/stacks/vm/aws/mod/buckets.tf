resource "random_id" "bucket" {
  byte_length = 8
}

resource "aws_s3_bucket" "noxus" {
  bucket        = "${var.project_name}-noxus-${random_id.bucket.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "noxus" {
  bucket = aws_s3_bucket.noxus.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_iam_role" "logging" {
  name = "${local.name_prefix}-logging"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "noxus_access" {
  name = "${local.name_prefix}-noxus-access"
  role = aws_iam_role.logging.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          aws_s3_bucket.noxus.arn,
          "${aws_s3_bucket.noxus.arn}/*"
        ]
      }
    ]
  })
}
