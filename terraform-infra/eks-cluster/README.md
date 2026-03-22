# EKS Cluster Module

This module creates an Amazon Elastic Kubernetes Service (EKS) cluster with self-managed worker nodes, essential add-ons, OIDC-based identity federation, Flux CD for GitOps, and fine-grained access control. It is the heart of the infrastructure -- after networking and IAM roles are in place, this module brings up the Kubernetes cluster that runs all your applications.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         AWS Account (372517046622)                       │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                       VPC (looked up via data source)              │  │
│  │                                                                    │  │
│  │  ┌─────────────────────────────────────────────────────────────┐   │  │
│  │  │                EKS Control Plane (eks.tf)                    │   │  │
│  │  │                                                              │   │  │
│  │  │  Cluster: "projectx"    K8s Version: 1.34                   │   │  │
│  │  │  Auth Mode: API_AND_CONFIG_MAP                              │   │  │
│  │  │  Logs: API + Audit                                          │   │  │
│  │  │  Security Group: cluster-sg (port 443)                      │   │  │
│  │  │                                                              │   │  │
│  │  │  ┌──────────────────────────────────────────────────────┐   │   │  │
│  │  │  │              EKS Add-ons (addons.tf)                  │   │   │  │
│  │  │  │  - vpc-cni         (pod networking)                   │   │   │  │
│  │  │  │  - aws-ebs-csi     (persistent volumes via IRSA)     │   │   │  │
│  │  │  │  - coredns          (cluster DNS)                     │   │   │  │
│  │  │  │  - kube-proxy       (network proxy)                   │   │   │  │
│  │  │  └──────────────────────────────────────────────────────┘   │   │  │
│  │  └─────────────────────────────────────────────────────────────┘   │  │
│  │                              │                                     │  │
│  │                    ┌─────────┴──────────┐                          │  │
│  │                    │  OIDC Provider      │ (oidc-providers.tf)     │  │
│  │                    │  Enables IRSA       │                         │  │
│  │                    └─────────┬──────────┘                          │  │
│  │                              │                                     │  │
│  │  ┌──────────────────────────────────────────────────────────────┐  │  │
│  │  │           Auto Scaling Group (asg.tf + launch-tm.tf)         │  │  │
│  │  │                                                              │  │  │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │  │  │
│  │  │  │ Worker    │  │ Worker    │  │ Worker    │   min: 1        │  │  │
│  │  │  │ Node 1    │  │ Node 2    │  │ Node 3    │   max: 5        │  │  │
│  │  │  │ (t3.med)  │  │ (t3a.med) │  │ (t2.med)  │   desired: 3   │  │  │
│  │  │  └──────────┘  └──────────┘  └──────────┘                  │  │  │
│  │  │  80% Spot / 20% On-Demand  |  AL2023 EKS AMI              │  │  │
│  │  │  Security Group: worker-nodes-sg                            │  │  │
│  │  └──────────────────────────────────────────────────────────────┘  │  │
│  │                                                                    │  │
│  │  ┌──────────────────────┐  ┌──────────────────────────────────┐   │  │
│  │  │ Access Entries        │  │ Flux CD (flux.tf)                │   │  │
│  │  │ (access-entries.tf)   │  │                                  │   │  │
│  │  │                       │  │ Bootstraps GitOps from           │   │  │
│  │  │ - Worker nodes (EC2)  │  │ GitHub repo into cluster         │   │  │
│  │  │ - IAM user: altoha    │  │                                  │   │  │
│  │  │ - GitHub Actions role │  │ Path: clusters/<env>-<cluster>   │   │  │
│  │  └──────────────────────┘  └──────────────────────────────────┘   │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
```

## File Descriptions

| File | Purpose |
|------|---------|
| `eks.tf` | Creates the EKS cluster resource itself. Configures the Kubernetes version, cluster IAM role, API/audit logging, authentication mode, VPC placement (public subnets), and security groups. Also defines local values for the cluster endpoint, CA certificate, and service CIDR. |
| `flux.tf` | Configures the Flux CD, Kubernetes, and GitHub Terraform providers. Bootstraps Flux onto the cluster so it watches a GitHub repo for Kubernetes manifests. This is what enables GitOps -- push YAML to Git, and Flux automatically deploys it to the cluster. |
| `addons.tf` | Installs four essential EKS add-ons: **vpc-cni** (assigns VPC IPs to pods), **aws-ebs-csi-driver** (lets pods use EBS volumes, uses IRSA for permissions), **coredns** (cluster-internal DNS), and **kube-proxy** (network routing on each node). |
| `access-entries.tf` | Defines who can access the cluster. Grants access to: (1) worker nodes (EC2_LINUX type), (2) IAM user `altoha` with ClusterAdmin policy, and (3) the `GithubActionsTerraformDeploy` role with ClusterAdmin policy for CI/CD. |
| `oidc-providers.tf` | Creates an IAM OIDC identity provider for the EKS cluster. This is the foundation of IRSA (IAM Roles for Service Accounts) -- it allows Kubernetes service accounts to assume IAM roles without storing AWS credentials in the cluster. |
| `asg.tf` | Creates an Auto Scaling Group (ASG) for worker nodes. Uses a mixed instances policy with 80% Spot and 20% On-Demand instances to save costs. Supports multiple instance types for flexibility. |
| `launch-tm.tf` | Defines the EC2 launch template for worker nodes. Configures the EKS-optimized AMI (Amazon Linux 2023), security group, instance profile, and user data (a NodeConfig YAML that tells the node how to join the EKS cluster). |
| `data-blocks.tf` | Looks up existing resources via data sources: the VPC (by CIDR), public subnets (by tag), the EKS-optimized AMI (from SSM Parameter Store), security groups (cluster-sg and worker-nodes-sg), and IAM roles (cluster role, worker role, EBS CSI IRSA role). |
| `outputs.tf` | Exports the cluster name, endpoint URL, and CA certificate for use by other modules and CI/CD pipelines. |
| `variables.tf` | Declares all input variables for the module. |

## Inputs

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `vpc_cidr` | `string` | Yes | - | VPC CIDR block, used to look up the VPC via data source. |
| `project_name` | `string` | Yes | - | Project name for tagging. |
| `cluster_name` | `string` | Yes | - | Name of the EKS cluster (e.g., `projectx`). |
| `k8s_version` | `string` | Yes | - | Kubernetes version (e.g., `1.34`). |
| `authentication_mode` | `string` | No | `"API_AND_CONFIG_MAP"` | EKS authentication mode. |
| `environment` | `string` | Yes | - | Environment name (e.g., `dev`). |
| `min_size` | `number` | No | `1` | Minimum number of worker nodes in the ASG. |
| `max_size` | `number` | No | `5` | Maximum number of worker nodes in the ASG. |
| `desired_capacity` | `number` | No | `3` | Desired number of worker nodes. |
| `ec2_types` | `list(string)` | No | `["t3.medium", "t3a.medium", "t2.medium"]` | Instance types for worker nodes (used in mixed instances policy). |
| `github_org` | `string` | Yes | - | GitHub organization or username for Flux. |
| `github_repo` | `string` | Yes | - | GitHub repository name for Flux. |
| `github_token` | `string` | Yes | - | GitHub personal access token for Flux (sensitive -- never hardcode). |
| `flux_path` | `string` | Yes | - | Path in the Git repo that Flux watches (e.g., `clusters/dev-projectx`). |

## Outputs

| Output | Description |
|--------|-------------|
| `cluster_name` | The name of the EKS cluster. |
| `cluster_endpoint` | The HTTPS endpoint URL for the Kubernetes API server. |
| `cluster_ca` | The base64-encoded certificate authority data for the cluster. |

## Dependency Chain

```
Prerequisites (must exist before this module runs):
    │
    ├── Networking module
    │   ├── VPC + public subnets (looked up by data source)
    │   ├── cluster-sg           (looked up by name)
    │   └── worker-nodes-sg      (looked up by name)
    │
    └── IAM Roles module
        ├── eks-cluster-role        (assumed by EKS control plane)
        ├── eks_worker_nodes_role   (assumed by EC2 worker nodes)
        └── ebs-csi-irsa-role       (assumed by EBS CSI driver via IRSA)

This module creates (in order):
    │
    ├── 1. EKS Cluster (eks.tf)
    │       │
    │       ├── 2. OIDC Provider (oidc-providers.tf)
    │       ├── 3. Add-ons (addons.tf)
    │       └── 4. Access Entries (access-entries.tf)
    │
    ├── 5. Launch Template (launch-tm.tf)
    │       │
    │       └── 6. Auto Scaling Group (asg.tf)
    │
    └── 7. Flux Bootstrap (flux.tf) -- depends on cluster + ASG
```

## Usage Example

This module is called from `root/dev/eks/main.tf`:

```hcl
module "eks" {
  source       = "../../../eks-cluster"
  cluster_name = "projectx"
  k8s_version  = "1.34"
  environment  = "dev"
  project_name = "projectx"
  vpc_cidr     = "10.0.0.0/16"
  github_org   = "your-org"
  github_repo  = "your-repo"
  github_token = var.github_token    # passed from CI/CD, never hardcoded
  flux_path    = "clusters/dev-projectx"
}
```

## Key Concepts for Beginners

- **EKS (Elastic Kubernetes Service)**: AWS's managed Kubernetes. AWS runs the control plane (API server, etcd); you provide the worker nodes that actually run your containers.
- **Self-Managed Nodes**: Unlike managed node groups, this setup uses a custom launch template and ASG. You have full control over the AMI, user data, and instance types.
- **IRSA (IAM Roles for Service Accounts)**: A mechanism that lets Kubernetes pods assume IAM roles without storing AWS credentials. The OIDC provider (created in `oidc-providers.tf`) is the bridge -- it tells AWS "trust tokens issued by this EKS cluster." The EBS CSI driver uses this pattern.
- **Flux CD**: A GitOps tool that runs inside your cluster and continuously syncs Kubernetes manifests from a Git repository. Push a change to Git, and Flux applies it to the cluster automatically.
- **Spot Instances**: EC2 instances that use spare AWS capacity at up to 90% discount. The trade-off is AWS can reclaim them with 2 minutes notice. The mixed policy (80% Spot / 20% On-Demand) balances cost savings with availability.
- **Launch Template**: A blueprint for EC2 instances. It defines the AMI, instance profile, security group, and user data (a startup script that tells the node how to join the EKS cluster).
- **Access Entries**: EKS's native way (API mode) to grant IAM principals access to the Kubernetes cluster. Replaces the older `aws-auth` ConfigMap approach.
- **Add-ons**: Pre-packaged Kubernetes components managed by AWS. They handle networking (vpc-cni), storage (ebs-csi), DNS (coredns), and network proxying (kube-proxy).
