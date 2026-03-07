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
#!/bin/bash
set -e

# Create folder for EKS config
mkdir -p /etc/eks

# Write NodeConfig YAML for nodeadm
cat <<'EOF' > /etc/eks/node-config.yaml
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: ${var.cluster_name}
    apiServerEndpoint: ${aws_eks_cluster.projectx_cluster.endpoint}
    certificateAuthority: ${replace(aws_eks_cluster.projectx_cluster.certificate_authority[0].data, "\n", "")}
    cidr: ${aws_eks_cluster.projectx_cluster.kubernetes_network_config[0].service_ipv4_cidr}
  kubelet:
    config:
      clusterDNS:
        - ${cidrhost(aws_eks_cluster.projectx_cluster.kubernetes_network_config[0].service_ipv4_cidr, 10)}
    flags:
      - --node-labels=node.kubernetes.io/lifecycle=normal
EOF

# Initialize node with nodeadm
/usr/bin/nodeadm init --config-source file:///etc/eks/node-config.yaml
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