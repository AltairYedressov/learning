module "vpc" {
  source       = "../../../networking/vpc-module"
  vpc_cidr     = var.vpc_cidr
  project_name = var.project_name
  environment  = var.environment
}

module "subnets" {
  source      = "../../../networking/subnets"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  subnets     = var.subnets
}

module "igw" {
  source      = "../../../networking/igw"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
}

module "route-tables" {
  source      = "../../../networking/route-tables"
  vpc_id      = module.vpc.vpc_id
  igw_id      = module.igw.igw_id
  subnets     = var.subnets
  subnet_ids  = module.subnets.subnet_ids
  environment = var.environment
}