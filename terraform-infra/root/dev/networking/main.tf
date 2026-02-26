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

module "sg-cluster" {
  source              = "../../../networking/security-group"
  vpc_id              = module.vpc.vpc_id
  security_group_name = "cluster-sg"
  description_for_sg  = "Security groups for cluster"
  resource_name       = "EKS-cluster"
  environment         = "dev"
  vpc_cidr_ipv4       = module.vpc.cidr_block
  vpc_cidr_ipv6       = module.vpc.ipv6_cidr_block
  from_port_ipv4      = "443"
  to_port_ipv4        = "443"
  to_port_ipv6        = "443"
  from_port_ipv6      = "443"
}

module "sg-worker-nodes" {
  source              = "../../../networking/security-group"
  vpc_id              = module.vpc.vpc_id
  security_group_name = "sg-worker-nodes"
  description_for_sg  = "Security groups for worker nodes"
  resource_name       = "EKS-worker-nodes"
  environment         = "dev"
  vpc_cidr_ipv4       = module.vpc.cidr_block
  vpc_cidr_ipv6       = module.vpc.ipv6_cidr_block
  from_port_ipv4      = "443"
  to_port_ipv4        = "443"
  to_port_ipv6        = "443"
  from_port_ipv6      = "443"
}