resource "aws_eks_access_entry" "nodes_entry" {
  cluster_name  = aws_eks_cluster.projectx_cluster.name
  principal_arn = data.aws_iam_role.eks_worker_nodes_role.arn
  type          = "EC2_LINUX"
}

resource "aws_eks_access_entry" "sso_admin" {
  cluster_name  = aws_eks_cluster.projectx_cluster.name
  principal_arn = "arn:aws:iam::372517046622:user/altoha"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "sso_admin_cluster_admin" {
  cluster_name  = aws_eks_cluster.projectx_cluster.name
  principal_arn = "arn:aws:iam::372517046622:user/altoha"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope { type = "cluster" }

  depends_on = [aws_eks_access_entry.sso_admin]
}

resource "aws_eks_access_entry" "github_terraform" {
  cluster_name  = aws_eks_cluster.projectx_cluster.name
  principal_arn = "arn:aws:iam::372517046622:role/GithubActionsTerraformDeploy"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_terraform_cluster_admin" {
  cluster_name  = aws_eks_cluster.projectx_cluster.name
  principal_arn = "arn:aws:iam::372517046622:role/GithubActionsTerraformDeploy"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope { type = "cluster" }

  depends_on = [aws_eks_access_entry.github_terraform]
}

