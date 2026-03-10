output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.projectx_cluster.name
}

# terraform-infra/eks-cluster/outputs.tf (add to existing)

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.projectx_cluster.endpoint
}

output "cluster_ca" {
  description = "EKS cluster certificate authority"
  value       = aws_eks_cluster.projectx_cluster.certificate_authority[0].data
}