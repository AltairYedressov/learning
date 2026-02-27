resource "aws_eks_cluster" "projectx_cluster" {
  name                      = var.cluster_name
  version                   = var.k8s_version
  role_arn                  = aws_iam_role.cluster.arn
  enabled_cluster_log_types = ["api", "audit"]

  access_config {
    authentication_mode = var.authentication_mode
  }

  vpc_config {
    endpoint_public_access = true
    subnet_ids             = data.aws_subnets.public.ids
    security_group_ids     = [data.aws_security_group.cluster-sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_service_policy_attachment
  ]

  tags = {
    "Name"                                      = var.cluster_name
    "project"                                   = var.project_name
    "environment"                               = var.environment
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

locals {
  cluster_endpoint = aws_eks_cluster.projectx_cluster.endpoint
  cluster_ca_b64   = aws_eks_cluster.projectx_cluster.certificate_authority[0].data
  service_cidr     = aws_eks_cluster.projectx_cluster.kubernetes_network_config[0].service_ipv4_cidr
}