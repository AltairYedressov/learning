resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.projectx_cluster.name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.21.1-eksbuild.3"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.projectx_cluster.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = "v1.55.0-eksbuild.2"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = data.aws_iam_role.ebs_csi_irsa_role.arn
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.projectx_cluster.name
  addon_name                  = "coredns"
  addon_version               = "v1.13.2-eksbuild.1"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.projectx_cluster.name
  addon_name                  = "kube-proxy"
  addon_version               = "v1.34.3-eksbuild.2"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}