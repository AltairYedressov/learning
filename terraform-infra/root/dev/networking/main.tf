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
  security_group_id            = module.worker-nodes-sg.security_group_id
  referenced_security_group_id = module.worker-nodes-sg.security_group_id
  ip_protocol                  = "-1"
  from_port                    = 0
  to_port                      = 65535
  description                  = "Allow worker nodes to access EKS control plane"
}

resource "aws_security_group_rule" "internal_kubelet_access" {
  type              = "ingress"
  from_port         = 10250
  to_port           = 10250
  protocol          = "tcp"
  cidr_blocks       = mopule.vpc.vpc_cidr
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