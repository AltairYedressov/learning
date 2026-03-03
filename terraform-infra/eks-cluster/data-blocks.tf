data "aws_vpc" "projectx" {
  cidr_block = var.vpc_cidr
}

data "aws_subnets" "public" {
  filter {
    name   = "tag:Type"
    values = ["public"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.projectx.id]
  }
}

data "aws_ssm_parameter" "eks_worker_ami" {
  name = "/aws/service/eks/optimized-ami/${var.k8s_version}/amazon-linux-2023/x86_64/standard/recommended/image_id"
}

data "aws_security_group" "worker_nodes_sg" {
  filter {
    name   = "group-name"
    values = ["worker-nodes-sg"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.projectx.id]
  }
}

data "aws_security_group" "cluster_sg" {
  filter {
    name   = "group-name"
    values = ["cluster-sg"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.projectx.id]
  }
}

data "aws_iam_role" "eks_worker_nodes_role" {
  name = "eks_worker_nodes_role"
}

data "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"
}

data "aws_iam_role" "ebs_csi_irsa_role" {
  name = "ebs-csi-irsa-role"
}