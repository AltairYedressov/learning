variable "cluster_policy" {
  type    = list(string)
  default = ["arn:aws:iam::aws:policy/AmazonEKSClusterPolicy", "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"]
}

variable "eks_cluster_role" {
  type    = string
  default = "eks-cluster-role"
}

variable "environment" {
  type = string
}

variable "eks_worker_nodes_role" {
  type    = string
  default = "eks_worker_nodes_role"
}

variable "eks_worker_nodes_policy" {
  description = "AWS managed policies for EKS worker nodes - least privilege (Phase 7 hardened)"
  type        = list(string)
  default = [
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  ]
}

variable "ebs_csi_irsa_role" {
  type    = string
  default = "ebs-csi-irsa-role"
}

variable "karpenter_irsa_role" {
  type    = string
  default = "karpenter_irsa_role"
}

variable "image_reflector_irsa_role" {
  type    = string
  default = "image-reflector-role"
}