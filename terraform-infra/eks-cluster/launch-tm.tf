terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.100.0"
    }
  }
}


resource "aws_iam_instance_profile" "workers_instance_profile" {
  name = "${var.cluster_name}-workers-instance-profile"
  role = data.aws_iam_role.eks_worker_nodes_role.name
}

resource "aws_launch_template" "workers_lt" {
  name                   = "${var.cluster_name}-workers-lt"
  image_id               = data.aws_ssm_parameter.eks_worker_ami.value
  vpc_security_group_ids = [data.aws_security_group.worker_nodes_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.workers_instance_profile.name
  }

  lifecycle {
    create_before_destroy = true
  }

  user_data = base64encode(<<-EOT
---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: ${var.cluster_name}
    apiServerEndpoint: ${aws_eks_cluster.projectx_cluster.endpoint}
    certificateAuthority: ${aws_eks_cluster.projectx_cluster.certificate_authority[0].data}
    cidr: ${aws_eks_cluster.projectx_cluster.kubernetes_network_config[0].service_ipv4_cidr}
  kubelet:
    config:
      clusterDNS:
        - 172.20.0.10
    flags:
      - --node-labels=node.kubernetes.io/lifecycle=normal
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                                        = "${var.cluster_name}-instance"
      project_name                                = var.project_name
      environment                                 = var.environment
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"


    }
  }

  tag_specifications {
    resource_type = "network-interface"
    tags = {
      project_name                                = var.project_name
      environment                                 = var.environment
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  }

}