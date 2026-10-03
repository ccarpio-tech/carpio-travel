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