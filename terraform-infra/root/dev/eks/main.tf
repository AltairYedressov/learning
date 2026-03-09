module "eks" {
  source       = "../../../eks-cluster"
  cluster_name = var.cluster_name
  k8s_version  = var.k8s_version
  environment  = var.environment
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
  github_org   = var.github_org
  github_repo  = var.github_repo
  github_token = var.github_token
  flux_path    = "clusters/${var.environment}-${var.cluster_name}"
}
