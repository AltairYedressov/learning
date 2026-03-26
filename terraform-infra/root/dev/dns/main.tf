module "acm" {
  source                    = "../../../dns/acm"
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  zone_id                   = data.aws_route53_zone.this.zone_id
  environment               = var.environment
}

resource "aws_route53_record" "istio_ingress" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.istio_ingress_lb_hostname
    zone_id                = "Z26RNL4JYFTOTI" # NLB hosted zone ID for us-east-1
    evaluate_target_health = true
  }
}