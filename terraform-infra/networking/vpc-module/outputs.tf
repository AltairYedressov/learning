output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.projectx_vpc.id
}

output "cidr_block" {
  description = "cidr block of vpc"
  value = aws_vpc.projectx_vpc.cidr_block
}

output "ipv6_cidr_block" {
  description = "ipv6 cidr block of vpc"
  value = aws_vpc.projectx_vpc.ipv6_cidr_block
}