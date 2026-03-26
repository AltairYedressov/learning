module "acm" {
  source                    = "../../../dns/acm"
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  zone_id                   = data.aws_route53_zone.this.zone_id
  environment               = var.environment
}