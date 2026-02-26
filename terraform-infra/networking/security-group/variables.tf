variable "security_group_name" {
  type = string
}

variable "description_for_sg" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "resource_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr_ipv4" {
  type = string
}

variable "vpc_cidr_ipv6" {
  type = string
}

variable "from_port_ipv4" {
  type = string
}

variable "to_port_ipv4" {
  type = string
}

variable "to_port_ipv6" {
  type = string
}

variable "from_port_ipv6" {
  type = string
}

variable "ip_protocol_ipv4" {
  type    = string
  default = "tcp"
}

variable "ip_protocol_ipv6" {
  type    = string
  default = "tcp"
}