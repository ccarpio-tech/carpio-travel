# Route 53 hosted zone (created automatically when the domain was registered)
resource "aws_route53_zone" "main" {
  name = var.domain_name

  # Same description AWS gave the zone (otherwise Terraform tries to change it)
  comment = "HostedZone created by Route53 Registrar"

  lifecycle {
    # Can't be destroyed (deleting it would break the domain's name servers)
    prevent_destroy = true
  }
}

# ACM certificate for the domain (validated with DNS records in Route 53)
resource "aws_acm_certificate" "site" {
  # Must be us-east-1 (CloudFront only accepts certs from there)
  region = "us-east-1"

  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]

  # Prove ownership with a CNAME record (ACM auto-renews as long as it stays)
  validation_method = "DNS"

  lifecycle {
    # Create the new cert before deleting the old one (CloudFront is using it)
    create_before_destroy = true
  }
}

# One validation record per domain on the cert (carpiotravel.com and www)
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

  # Overwrite the record if it already exists (e.g. created outside Terraform)
  allow_overwrite = true
}

# Waits until the cert is issued (creates nothing in AWS)
# CloudFront points here, not at the cert (so it never gets an unissued one)
resource "aws_acm_certificate_validation" "site" {
  region = "us-east-1"

  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_route53_record" "apex" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}