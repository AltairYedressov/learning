module "ecr" {
  source = "./ecr"

  environment           = var.environment
  ecr_name             = var.ecr_name
  image_tag_mutability = var.image_tag_mutability
  scan_on_push         = var.scan_on_push
}   