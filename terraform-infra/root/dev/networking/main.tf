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

module "cluster-sg" {
  source      = "../../../networking/security-group"
  name        = "cluster-sg"
  description = "Scurity Group for cluste"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  rules = [
    {
      cidr      = module.vpc.cidr_block
      from_port = 443
      to_port   = 443
    }
  ]
}

module "worker-nodes-sg" {
  source      = "../../../networking/security-group"
  name        = "worker-nodes-sg"
  description = "Scurity Group for cluste"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
}

resource "aws_vpc_security_group_ingress_rule" "cluster_from_workers" {
  security_group_id            = module.cluster-sg.security_group_id
  referenced_security_group_id = module.worker-nodes-sg.security_group_id

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443

  description = "Workers to EKS API"
}

resource "aws_security_group_rule" "internal_kubelet_access" {
  type              = "ingress"
  from_port         = 10250
  to_port           = 10250
  protocol          = "tcp"
  cidr_blocks       = [module.vpc.cidr_block]
  security_group_id = module.worker-nodes-sg.security_group_id
  description       = "Allow access to kubelet from within the VPC (for Prometheus, Metrics Server, etc.)"
}

resource "aws_security_group_rule" "allow_control_plane_to_kubelet" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = module.worker-nodes-sg.security_group_id
  source_security_group_id = module.cluster-sg.security_group_id
  description              = "Allow EKS control plane to communicate with kubelet on worker nodes (for exec/logs/health checks)"
}

resource "aws_security_group_rule" "worker_sg_self_reference_all" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1" # all protocols
  security_group_id        = module.worker-nodes-sg.security_group_id
  source_security_group_id = module.worker-nodes-sg.security_group_id
  description              = "Allow all traffic between worker nodes for pod networking and DNS"
}

module "database-sg" {
  source      = "../../../networking/security-group"
  name        = "database-sg"
  description = "Scurity Group for databasse"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  rules = [
    {
      cidr      = module.vpc.cidr_block
      from_port = 3306
      to_port   = 3306
    }
  ]
}

module "alb-sg" {
  source      = "../../../networking/security-group"
  name        = "alb-sg"
  description = "Security Group for ALB"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_to_alb" {
  security_group_id = module.alb-sg.security_group_id

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"

  description = "Allow HTTPS traffic to ALB"
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_to_alb" {
  security_group_id = module.alb-sg.security_group_id

  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
  cidr_ipv4   = "0.0.0.0/0"

  description = "Allow HTTP traffic to ALB"
}
