output "subnet_ids" {
  value = {
    for key, subnet in aws_subnet.subnets :
    key => subnet.id
  }
}