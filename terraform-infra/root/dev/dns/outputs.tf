output "zone_id" {
  value = data.aws_route53_zone.this.zone_id
}

output "certificate_arn" {
  value = module.acm.certificate_arn
}