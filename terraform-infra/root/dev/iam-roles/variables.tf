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
