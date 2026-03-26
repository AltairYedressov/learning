resource "aws_ecr_repository" "default" {
  for_each             = toset(var.ecr_names)
  name                 = each.value
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = {
    Environment = var.environment
    Name        = each.value
  }
}