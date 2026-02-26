resource "aws_security_group" "allow_tls" {
  name        = var.security_group_name
  description = var.description_for_sg
  vpc_id      = var.vpc_id

  tags = {
    Name = "sg-${var.resource_name}-${var.environment}"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = var.vpc_cidr_ipv4
  from_port         = var.from_port_ipv4
  ip_protocol       = var.ip_protocol_ipv4
  to_port           = var.to_port_ipv4
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv6" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv6         = var.vpc_cidr_ipv6
  from_port         = var.from_port_ipv6
  ip_protocol       = var.ip_protocol_ipv6
  to_port           = var.to_port_ipv6
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}