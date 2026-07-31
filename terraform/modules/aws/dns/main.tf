data "aws_route53_zone" "this" {
  count = var.zone_id == "" ? 1 : 0

  name         = var.zone_name
  private_zone = false
}

locals {
  zone_id = var.zone_id != "" ? var.zone_id : data.aws_route53_zone.this[0].zone_id

  # The chart derives api.<domain> and relay.<domain> from ingress.domain, so the
  # certificate has to cover the apex plus one wildcard level.
  subject_alternative_names = distinct(concat(["*.${var.domain}"], var.extra_sans))
}

resource "aws_acm_certificate" "this" {
  domain_name               = var.domain
  subject_alternative_names = local.subject_alternative_names
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, { Name = var.domain })
}

resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = local.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]
}
