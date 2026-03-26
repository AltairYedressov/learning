variable "domain_name" {
  type        = string
  description = "Domain name for hosted zone and certificate"
}

variable "environment" {
  type = string
}

variable "istio_ingress_lb_hostname" {
  type        = string
  description = "Hostname of the Istio ingress NLB"
}