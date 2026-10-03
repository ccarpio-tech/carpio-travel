# ------------------------------------------------------------------------------
# Route 53 hosted zone (created automatically by Route 53 domain registration)
# ------------------------------------------------------------------------------

# Adopt the existing zone into Terraform state instead of creating a new one.
# A new zone would get different name servers than the ones the registrar
# delegates to, so its records would never be seen on the internet.
# Safe to delete this block after the import has been applied.
import {
  to = aws_route53_zone.main
  id = "Z092586711YSA8MMC7VLG"
}

resource "aws_route53_zone" "main" {
  name = var.domain_name

  # Match the comment AWS set at registration so the import shows no drift.
  comment = "HostedZone created by Route53 Registrar"

  lifecycle {
    # Deleting this zone would break the domain's NS delegation.
    prevent_destroy = true
  }
}

# ------------------------------------------------------------------------------
# ACM certificate for the custom domain (validated via DNS in Route 53)
# ------------------------------------------------------------------------------

resource "aws_acm_certificate" "site" {
  # CloudFront only accepts certificates from us-east-1, regardless of the
  # provider's default region.
  region = "us-east-1"

  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]

  # Prove ownership with a CNAME record; ACM auto-renews while it stays in place.
  validation_method = "DNS"

  lifecycle {
    # A replacement cert must exist before the old one (attached to CloudFront)
    # can be deleted.
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# DNS validation: publish ACM's CNAMEs, then wait for the cert to be issued
# ------------------------------------------------------------------------------

# One CNAME per name on the cert, keyed by domain name. The keys come from
# config so they are known at plan time; the values come from ACM.
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60

  # Take over an identical record if one was already created outside Terraform.
  allow_overwrite = true
}

# Not an AWS object: blocks until ACM reports the cert as ISSUED. CloudFront
# references this resource so it never gets a pending cert.
resource "aws_acm_certificate_validation" "site" {
  region = "us-east-1"

  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
