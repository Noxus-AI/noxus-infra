output "private_bucket" {
  description = "Private bucket name — set as env.SPOTFLOW_STORAGE_BUCKET."
  value       = aws_s3_bucket.private.bucket
}

output "private_bucket_arn" {
  description = "Private bucket ARN, for IAM policies."
  value       = aws_s3_bucket.private.arn
}

output "public_bucket" {
  description = "Public assets bucket name — set as env.SPOTFLOW_PUBLIC_STORAGE_BUCKET."
  value       = aws_s3_bucket.public.bucket
}

output "public_bucket_arn" {
  description = "Public assets bucket ARN, for IAM policies."
  value       = aws_s3_bucket.public.arn
}

output "bucket_arns" {
  description = "Both bucket ARNs, for granting pod access in one place."
  value       = [aws_s3_bucket.private.arn, aws_s3_bucket.public.arn]
}
