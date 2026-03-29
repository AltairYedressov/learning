module "eks_cluster" {
  source = "../../../iam-role-module"

  role_name   = var.eks_cluster_role
  environment = var.environment

  principal_type        = "Service"
  principal_identifiers = ["eks.amazonaws.com"]

  aws_managed_policy_arns = var.cluster_policy
}

module "eks_worker_nodes" {
  source = "../../../iam-role-module"

  role_name   = var.eks_worker_nodes_role
  environment = var.environment

  principal_type        = "Service"
  principal_identifiers = ["ec2.amazonaws.com"]

  aws_managed_policy_arns = var.eks_worker_nodes_policy
  custom_policy_json_path = "${path.module}/../../../iam-role-module/Policies/eks_worker_node_policy.json"
}

module "ebs_csi_irsa_role" {
  source = "../../../iam-role-module"

  role_name          = var.ebs_csi_irsa_role
  environment        = var.environment
  assume_role_action = "sts:AssumeRoleWithWebIdentity"

  principal_type = "Federated"

  principal_identifiers = [
    data.aws_iam_openid_connect_provider.eks_oidc_provider.arn
  ]

  assume_role_conditions = {
    ebs_csi_controller = {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.eks_oidc_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
  aws_managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  ]
}

module "karpenter_irsa_role" {
  source = "../../../iam-role-module"

  role_name          = var.karpenter_irsa_role
  environment        = var.environment
  assume_role_action = "sts:AssumeRoleWithWebIdentity"

  principal_type = "Federated"

  principal_identifiers = [
    data.aws_iam_openid_connect_provider.eks_oidc_provider.arn
  ]

  assume_role_conditions = {
    sub = {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.eks_oidc_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:karpenter:karpenter"]
    }
    aud = {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.eks_oidc_provider.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
  custom_policy_json_path = "${path.module}/../../../iam-role-module/Policies/karpenter_policy.json"
}

module "velero_irsa_role" {
  source = "../../../iam-role-module"

  role_name          = "velero-role"
  environment        = var.environment
  assume_role_action = "sts:AssumeRoleWithWebIdentity"
  principal_type     = "Federated"
  principal_identifiers = [
    data.aws_iam_openid_connect_provider.eks_oidc_provider.arn
  ]
  assume_role_conditions = {
    sub = {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.eks_oidc_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:velero:velero-server"]
    }
    aud = {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.eks_oidc_provider.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
  custom_policy_json_path = "${path.module}/../../../iam-role-module/Policies/velero_policy.json"
  aws_managed_policy_arns = []
}

module "aws_lb_controller_irsa_role" {
  source = "../../../iam-role-module"

  role_name          = "aws-lb-controller-role"
  environment        = var.environment
  assume_role_action = "sts:AssumeRoleWithWebIdentity"
  principal_type     = "Federated"
  principal_identifiers = [
    data.aws_iam_openid_connect_provider.eks_oidc_provider.arn
  ]
  assume_role_conditions = {
    sub = {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.eks_oidc_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
    aud = {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.eks_oidc_provider.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
  custom_policy_json_path = "${path.module}/../../../iam-role-module/Policies/aws_lb_controller_policy.json"
  aws_managed_policy_arns = []
}

module "thanos_irsa_role" {
  source = "../../../iam-role-module"

  role_name          = "thanos-role"
  environment        = var.environment
  assume_role_action = "sts:AssumeRoleWithWebIdentity"
  principal_type     = "Federated"
  principal_identifiers = [
    data.aws_iam_openid_connect_provider.eks_oidc_provider.arn
  ]
  assume_role_conditions = {
    sub = {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.eks_oidc_provider.url, "https://", "")}:sub"
      values = [
        "system:serviceaccount:monitoring:thanos-storegateway",
        "system:serviceaccount:monitoring:thanos-compactor",
        "system:serviceaccount:monitoring:kube-prometheus-stack-prometheus"
      ]
    }
    aud = {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.eks_oidc_provider.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
  custom_policy_json_path = "${path.module}/../../../iam-role-module/Policies/thanos_policy.json"
  aws_managed_policy_arns = []
}