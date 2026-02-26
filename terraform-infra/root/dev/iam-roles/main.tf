module "eks_cluster" {
  source = "../../../iam-role-module"

  role_name   = var.eks_cluster_role
  environment = var.environment

  principal_type        = "Service"
  principal_identifiers = ["eks.amazonaws.com"]

  aws_managed_policy_arns = var.cluster_policy
}