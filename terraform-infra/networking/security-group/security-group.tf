resource "aws_security_group" "sg" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id

  tags = {
    name        = var.name
    environment = var.environment
  }
}

# Dynamically create ingress rules for both IPv4 and IPv6
resource "aws_vpc_security_group_ingress_rule" "sg" {
  for_each          = { for idx, rule in var.rules : idx => rule }
  security_group_id = aws_security_group.sg.id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.protocol

  cidr_ipv4 = each.value.ip_version == "ipv4" ? each.value.cidr : null
  cidr_ipv6 = each.value.ip_version == "ipv6" ? each.value.cidr : null
}

# Egress rules: allow all traffic (IPv4 + IPv6)
resource "aws_vpc_security_group_egress_rule" "all_ipv4" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "all_ipv6" {
  security_group_id = aws_security_group.this.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1"
}