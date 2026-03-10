# connects to the EKS cluster we just created
provider "kubernetes" {
  host = aws_eks_cluster.projectx_cluster.endpoint
  cluster_ca_certificate = base64decode(
    aws_eks_cluster.projectx_cluster.certificate_authority[0].data
  )
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      aws_eks_cluster.projectx_cluster.name
    ]
  }
}

provider "flux" {
  kubernetes = {
    host = aws_eks_cluster.projectx_cluster.endpoint
    cluster_ca_certificate = base64decode(
      aws_eks_cluster.projectx_cluster.certificate_authority[0].data
    )
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        aws_eks_cluster.projectx_cluster.name
      ]
    }
  }
  git = {
    url = "https://github.com/${var.github_org}/${var.github_repo}"
    http = {
      username = "git"
      password = var.github_token
    }
  }
}

provider "github" {
  owner = var.github_org
  token = var.github_token
}

# bootstraps flux on the cluster
# creates clusters/<flux_path>/flux-system/ in your git repo
resource "flux_bootstrap_git" "this" {
  depends_on = [
    aws_eks_cluster.projectx_cluster,
    aws_autoscaling_group.workers_asg # nodes must be ready first
  ]

  embedded_manifests = true
  path               = var.flux_path
}