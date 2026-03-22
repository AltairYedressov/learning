# IAM Role Module

This is a reusable module that creates a single IAM role with its trust policy (who can assume it), optional custom policies (loaded from JSON files), and optional AWS managed policy attachments. It is called multiple times from `root/dev/iam-roles/` to create all the roles needed by the project: the EKS cluster role, worker node role, and several IRSA roles for in-cluster services like EBS CSI, Karpenter, Velero, and Thanos.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                        IAM Role Module                               │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │                      Trust Policy                              │  │
│  │          (who can assume this role?)                            │  │
│  │                                                                │  │
│  │  Principal Type:  Service | Federated | AWS                    │  │
│  │  Action:          sts:AssumeRole | sts:AssumeRoleWithWebIdentity│  │
│  │  Conditions:      Optional (used for IRSA to restrict to       │  │
│  │                   specific service accounts)                   │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                              │                                       │
│                     ┌────────┴────────┐                              │
│                     │   IAM Role      │                              │
│                     │   (aws_iam_role)│                              │
│                     └────────┬────────┘                              │
│                              │                                       │
│              ┌───────────────┼───────────────┐                       │
│              │                               │                       │
│  ┌───────────┴────────────┐   ┌──────────────┴──────────────┐       │
│  │  Custom Policy          │   │  AWS Managed Policies       │       │
│  │  (from JSON file)       │   │  (by ARN)                   │       │
│  │                         │   │                              │       │
│  │  Policies/ directory:   │   │  e.g.:                      │       │
│  │  - karpenter_policy.json│   │  - AmazonEKSClusterPolicy   │       │
│  │  - velero_policy.json   │   │  - AmazonEKS_CNI_Policy     │       │
│  │  - thanos_policy.json   │   │  - AmazonEBSCSIDriverPolicy │       │
│  └─────────────────────────┘   └──────────────────────────────┘       │
└──────────────────────────────────────────────────────────────────────┘

Roles created by root/dev/iam-roles/:

┌─────────────────────┐  ┌──────────────────────┐  ┌────────────────────┐
│ eks-cluster-role     │  │ eks_worker_nodes_role │  │ ebs-csi-irsa-role  │
│                      │  │                       │  │                    │
│ Assumed by:          │  │ Assumed by:           │  │ Assumed by:        │
│  eks.amazonaws.com   │  │  ec2.amazonaws.com    │  │  OIDC (Federated)  │
│                      │  │                       │  │  SA: ebs-csi-      │
│ Policies:            │  │ Policies:             │  │  controller-sa     │
│  EKSClusterPolicy    │  │  EC2ContainerRegistry │  │                    │
│  EKSServicePolicy    │  │  EKS_CNI_Policy       │  │ Policy:            │
│                      │  │  EC2FullAccess         │  │  EBSCSIDriverPolicy│
│                      │  │  ELBFullAccess         │  │                    │
└─────────────────────┘  └──────────────────────┘  └────────────────────┘

┌─────────────────────┐  ┌──────────────────────┐  ┌────────────────────┐
│ karpenter_irsa_role  │  │ velero-role           │  │ thanos-role        │
│                      │  │                       │  │                    │
│ Assumed by:          │  │ Assumed by:           │  │ Assumed by:        │
│  OIDC (Federated)    │  │  OIDC (Federated)     │  │  OIDC (Federated)  │
│  SA: karpenter/      │  │  SA: velero/           │  │  SA: monitoring/   │
│      karpenter       │  │      velero-server     │  │  thanos-*,         │
│                      │  │                       │  │  prometheus         │
│ Policy:              │  │ Policy:               │  │                    │
│  karpenter_policy.json│  │  velero_policy.json    │  │ Policy:            │
│  (EC2, IAM, EKS,     │  │  (S3, EC2 snapshots)   │  │  thanos_policy.json│
│   SSM, SQS)          │  │                       │  │  (S3 access)       │
└─────────────────────┘  └──────────────────────┘  └────────────────────┘
```

## File Descriptions

| File | Purpose |
|------|---------|
| `main.tf` | The core module logic. Creates the trust policy (using `aws_iam_policy_document`), the IAM role, an optional custom policy (loaded from a JSON file path), and attaches both custom and AWS managed policies to the role. |
| `variables.tf` | Declares all input variables: role name, principal type/identifiers, assume role conditions, custom policy path, managed policy ARNs, etc. |

### `Policies/` Directory

Contains JSON policy documents for custom IAM policies. These files are referenced by the `custom_policy_json_path` variable and loaded using Terraform's `file()` function.

| File | Purpose |
|------|---------|
| `Policies/karpenter_policy.json` | Grants Karpenter permissions to manage EC2 instances (create, terminate, describe), IAM instance profiles, pass the worker node role, describe the EKS cluster, read SSM parameters for AMIs, get pricing data, and interact with an SQS queue for interruption handling. |
| `Policies/velero_policy.json` | Grants Velero permissions to manage EC2 snapshots (create, delete, describe) and read/write objects in the `372517046622-velero-backups-dev` S3 bucket for Kubernetes backup storage. |
| `Policies/thanos_policy.json` | Grants Thanos permissions to read/write objects in the `372517046622-thanos-dev` S3 bucket and list/locate the bucket. Used for long-term Prometheus metrics storage. |

## Inputs

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `role_name` | `string` | Yes | - | The name of the IAM role to create. |
| `environment` | `string` | Yes | - | Environment name for tagging. |
| `principal_type` | `string` | Yes | - | The type of principal: `"Service"` (for AWS services like EKS), `"Federated"` (for OIDC/IRSA), or `"AWS"` (for IAM users/roles). |
| `principal_identifiers` | `list(string)` | Yes | - | List of ARNs or service names that can assume the role (e.g., `["eks.amazonaws.com"]` or an OIDC provider ARN). |
| `assume_role_action` | `string` | No | `"sts:AssumeRole"` | The STS action. Set to `"sts:AssumeRoleWithWebIdentity"` for IRSA roles. |
| `assume_role_conditions` | `map(object)` | No | `{}` | Conditions on the trust policy. For IRSA, this restricts which Kubernetes service accounts can assume the role. Each condition has `test`, `variable`, and `values`. |
| `custom_policy_json_path` | `string` | No | `null` | Path to a JSON file containing a custom IAM policy. If provided, the policy is created and attached to the role. |
| `aws_managed_policy_arns` | `list(string)` | No | `[]` | List of AWS managed policy ARNs to attach (e.g., `"arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"`). |

## Dependency Chain

```
This module has no infrastructure dependencies (it only creates IAM resources).

However, for IRSA roles, the OIDC provider must exist first:

EKS Cluster (creates OIDC provider)
    │
    └── root/dev/iam-roles/data-blocks.tf
            │ (looks up the OIDC provider URL)
            │
            └── Calls this module with:
                ├── eks-cluster-role       (Service principal: eks.amazonaws.com)
                ├── eks_worker_nodes_role  (Service principal: ec2.amazonaws.com)
                ├── ebs-csi-irsa-role      (Federated principal: OIDC provider)
                ├── karpenter_irsa_role    (Federated principal: OIDC provider)
                ├── velero-role            (Federated principal: OIDC provider)
                └── thanos-role            (Federated principal: OIDC provider)
```

## Usage Examples

### Creating a simple service role (e.g., for EKS):

```hcl
module "eks_cluster_role" {
  source = "../../../iam-role-module"

  role_name              = "eks-cluster-role"
  environment            = "dev"
  principal_type         = "Service"
  principal_identifiers  = ["eks.amazonaws.com"]
  aws_managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  ]
}
```

### Creating an IRSA role (e.g., for Velero):

```hcl
module "velero_irsa_role" {
  source = "../../../iam-role-module"

  role_name          = "velero-role"
  environment        = "dev"
  assume_role_action = "sts:AssumeRoleWithWebIdentity"  # IRSA uses WebIdentity
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
}
```

## Key Concepts for Beginners

- **IAM Role**: An AWS identity with permissions that can be "assumed" by services, users, or federated identities. Unlike a user, a role has no permanent credentials -- it issues temporary credentials each time it is assumed.
- **Trust Policy (Assume Role Policy)**: A JSON document that says "who is allowed to assume this role." For example, `eks.amazonaws.com` means the EKS service can use this role.
- **IRSA (IAM Roles for Service Accounts)**: A pattern where a Kubernetes service account (inside the cluster) can assume an IAM role (in AWS). The trust policy uses the OIDC provider as a "Federated" principal and conditions to restrict which specific service account can assume the role.
- **`sts:AssumeRoleWithWebIdentity`**: The STS action used for OIDC/IRSA authentication. Standard service roles use `sts:AssumeRole` instead.
- **Managed Policy**: A pre-built IAM policy maintained by AWS (e.g., `AmazonEKSClusterPolicy`). You attach it by ARN.
- **Custom Policy**: A policy you write yourself as a JSON file. This module loads it from the `Policies/` directory using `file()`.
- **`for_each`**: Used in this module to dynamically create and attach multiple managed policies from a list.
