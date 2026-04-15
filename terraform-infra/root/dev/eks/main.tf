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

# -- Branch Protection (CI/CD Security Gate) -----------------------------------------

resource "github_branch_protection_v3" "main" {
  repository = var.github_repo
  branch     = "main"

  enforce_admins = false

  required_status_checks {
    strict   = false
    contexts = [
      "publish-images",
      "terraform (iam-roles)",
    ]
  }
}
