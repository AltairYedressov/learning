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
  type    = list(string)
  default = ["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly", "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy", "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser", "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess", "arn:aws:iam::aws:policy/AmazonEC2FullAccess"]
}

variable "ebs_csi_irsa_role" {
  type    = string
  default = "ebs-csi-irsa-role"
}