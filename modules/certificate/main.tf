provider "aws" {
  region = var.aws_region
}

provider "tls" {}
## Create a self-signed certificate for a development environment.
resource "tls_private_key" "example" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "example" {
  key_algorithm         = tls_private_key.example.algorithm
  private_key_pem       = tls_private_key.example.private_key_pem
  validity_period_hours = 168
  early_renewal_hours   = 3
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
  # NEXT COULD USE A VAR (friendly_name_prefix)
  dns_names = [var.friendly_name_prefix]
  subject {
    common_name  = var.cname
    organization = var.organization
  }
}

resource "aws_acm_certificate" "example" {
  certificate_body = tls_self_signed_cert.example.cert_pem
  private_key      = tls_private_key.example.private_key_pem
}

# data "aws_iam_server_certificate" "sscert" {
#   depends_on 
#   name_prefix = "example_self_signed_cert"
#   latest      = true
# }

output "certificate_arn" {
  value = aws_acm_certificate.example.arn
}
