resource "aws_ecr_repository" "default" {
  for_each             = toset(var.ecr_names)
  name                 = each.value
  image_tag_mutability = contains(var.immutable_repos, each.value) ? "IMMUTABLE" : var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = {
    Environment = var.environment
    Name        = each.value
  }
}

resource "aws_ecr_lifecycle_policy" "default" {
  for_each   = toset(var.immutable_repos)
  repository = aws_ecr_repository.default[each.value].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 tagged images"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = 30
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
