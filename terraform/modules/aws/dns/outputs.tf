output "certificate_arn" {
  description = "Validated ACM certificate ARN. Set as the ALB ingress annotation alb.ingress.kubernetes.io/certificate-arn."
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "zone_id" {
  description = "Hosted zone ID the records were written to."
  value       = local.zone_id
}
