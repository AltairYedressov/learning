data "aws_iam_openid_connect_provider" "eks_oidc_provider" {
  # URL of the existing OIDC provider from your EKS cluster
  url = "https://oidc.eks.us-east-1.amazonaws.com/id/D61E52E76FBF3DDE20ED109C2F383FF4"
}