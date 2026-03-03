module "eks_cluster" {
  source = "../../../iam-role-module"

  role_name   = var.eks_cluster_role
  environment = var.environment

  principal_type        = "Service"
  principal_identifiers = ["eks.amazonaws.com"]

  aws_managed_policy_arns = var.cluster_policy
}

module "eks_worker_nodes" {
  source = "../../../iam-role-module"

  role_name   = var.eks_worker_nodes_role
  environment = var.environment

  principal_type        = "Service"
  principal_identifiers = ["ec2.amazonaws.com"]

  aws_managed_policy_arns = var.eks_worker_nodes_policy
}

module "ebs_csi_irsa_role" {
  source = "../../../iam-role-module"

  role_name   = var.ebs_csi_irsa_role
  environment = var.environment

  principal_type = "Federated"

  principal_identifiers = [
    data.aws_iam_openid_connect_provider.eks_oidc_provider.arn
  ]

  assume_role_conditions = {
  ebs_csi_controller = {
    test     = "StringEquals"
    variable = "${replace(data.aws_iam_openid_connect_provider.eks_oidc_provider.url, "https://", "")}:sub"
    values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
  }
}
  aws_managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  ]
}