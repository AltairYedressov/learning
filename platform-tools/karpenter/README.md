# Karpenter - Intelligent Cluster Autoscaling for EKS

## What is Karpenter?

Karpenter is a Kubernetes-native autoscaler built by AWS that automatically provisions new nodes when pods cannot be scheduled due to insufficient resources, and removes nodes when they are no longer needed. Unlike the older Cluster Autoscaler (which scales pre-defined Auto Scaling Groups), Karpenter directly calls EC2 APIs to launch exactly the right instance type for pending pods. It is faster (nodes in ~60 seconds vs ~3-5 minutes), smarter (picks optimal instance types based on pod requirements), and cheaper (supports Spot instances with automatic fallback to On-Demand).

## Architecture - How It All Connects

```
                         EKS Cluster (projectx)
  ┌─────────────────────────────────────────────────────────────────────────┐
  │                                                                         │
  │  ┌─────────────────────────────────────┐                                │
  │  │       karpenter namespace            │                                │
  │  │                                      │                                │
  │  │  ┌──────────────────────────────┐   │                                │
  │  │  │  Karpenter Controller         │   │                                │
  │  │  │  (Deployment, 2 replicas)     │   │                                │
  │  │  │                               │   │                                │
  │  │  │  Watches: Pending Pods ◀──────┼───┼── Scheduler can't place pod   │
  │  │  │  Watches: NodePool CRs        │   │                                │
  │  │  │  Watches: EC2NodeClass CRs    │   │                                │
  │  │  └──────────┬───────────────────┘   │                                │
  │  │             │                        │                                │
  │  └─────────────┼────────────────────────┘                                │
  │                │                                                         │
  │                │ 1. Decides instance type                                │
  │                │ 2. Calls EC2 API (via IRSA)                             │
  │                ▼                                                         │
  │  ┌──────────────────────────────────────────┐                            │
  │  │         AWS EC2                            │                            │
  │  │                                            │                            │
  │  │  Launches:  t3.medium, t3a.large, etc.    │                            │
  │  │  Uses:      Spot or On-Demand             │                            │
  │  │  AMI:       AL2023 (Amazon Linux 2023)    │                            │
  │  └──────────────────┬───────────────────────┘                            │
  │                     │                                                     │
  │                     │ 3. New node joins cluster                           │
  │                     ▼                                                     │
  │  ┌──────────────────────────────────────────┐                            │
  │  │  New Worker Node                           │                            │
  │  │  - Registers with EKS API server          │                            │
  │  │  - Pending pods get scheduled here        │                            │
  │  └──────────────────────────────────────────┘                            │
  │                                                                         │
  │  ┌──────────────────────────────────────────┐                            │
  │  │         SQS Queue                          │                            │
  │  │    (projectx-karpenter)                    │                            │
  │  │                                            │                            │
  │  │  Receives EC2 interruption notices:       │                            │
  │  │  - Spot 2-min warnings                    │◀─── AWS EventBridge        │
  │  │  - Instance rebalance recommendations     │                            │
  │  │  Karpenter reads these and gracefully     │                            │
  │  │  drains nodes before termination          │                            │
  │  └──────────────────────────────────────────┘                            │
  └─────────────────────────────────────────────────────────────────────────┘
```

### How Karpenter Decides What to Launch

```
Pending Pod needs:        NodePool says:              EC2NodeClass says:
- 500m CPU                - Spot or On-Demand         - AMI: AL2023
- 1Gi Memory              - amd64 architecture        - Role: eks_worker_nodes_role
                          - t3.medium, t3a.medium,    - Subnets: tagged "Type: public"
                          │ t3.large, t3a.large,      - Security Group: "worker-nodes-sg"
                          │ m5.large, m5a.large
                          ▼
                    Karpenter picks the cheapest
                    instance that fits the pod
                    (prefers Spot in dev)
```

## File Structure

```
platform-tools/karpenter/
├── base/                              # Karpenter controller Helm chart
│   ├── kustomization.yaml             # Lists base resources
│   ├── namespace.yaml                 # Creates "karpenter" namespace
│   ├── helmrepository.yaml            # OCI registry for Karpenter chart
│   └── helmrelease.yaml               # Controller config with IRSA
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml         # Imports base + dev patch
│   │   └── patch.yaml                 # Dev: 2 replicas
│   └── prod/
│       ├── kustomization.yaml         # Imports base + prod patch + nodepool patch
│       └── patch.yaml                 # Prod: 1 replica
├── nodepool/                          # NodePool + EC2NodeClass definitions
│   ├── base/
│   │   ├── kustomization.yaml         # Lists nodepool resources
│   │   └── nodepool.yaml              # Default NodePool + EC2NodeClass
│   └── overlays/
│       ├── dev/
│       │   ├── kustomization.yaml     # Imports nodepool base + dev patch
│       │   └── patch.yaml             # Dev: Spot-only, smaller limits
│       └── prod/
│           ├── kustomization.yaml     # Imports nodepool base + prod patch
│           └── patch.yaml             # Prod overrides
```

### Why Two Subdirectories?

Karpenter has two separate concerns deployed independently:

1. **`base/`** -- The Karpenter controller itself (a Helm chart). This is the software that watches for pending pods and launches nodes.
2. **`nodepool/`** -- The NodePool and EC2NodeClass custom resources. These tell the controller what kind of nodes it is allowed to create (instance types, capacity types, limits, AMI, networking).

They are separated because:
- The controller needs to be running before NodePools can be applied (Flux uses `dependsOn`)
- NodePool changes (e.g., adding instance types) do not require redeploying the controller
- Different teams might manage controller upgrades vs. node configuration

### What Each File Does

**`base/helmrepository.yaml`** -- Points to the Karpenter OCI Helm registry at `oci://public.ecr.aws/karpenter`. Unlike traditional Helm repos, this uses OCI (container registry) format.

**`base/helmrelease.yaml`** -- Deploys the Karpenter controller with:
- **IRSA annotation**: `eks.amazonaws.com/role-arn: arn:aws:iam::372517046622:role/karpenter_irsa_role` -- allows the controller to call EC2/IAM/EKS/SQS/SSM APIs
- **Cluster settings**: Cluster name (`projectx`), API endpoint, and SQS interruption queue name
- **Chart version**: `1.x.x` (latest v1 release)

**`nodepool/base/nodepool.yaml`** -- Defines two custom resources:

1. **NodePool** (`default`) -- The provisioning rules:
   - Capacity types: Spot and On-Demand
   - Architecture: amd64
   - Instance types: t3.medium, t3a.medium, t3.large, t3a.large, m5.large, m5a.large
   - Limits: max 100 CPUs and 400Gi memory across all Karpenter-managed nodes
   - Disruption: consolidates underutilized nodes after 30 seconds

2. **EC2NodeClass** (`default`) -- The AWS-specific node configuration:
   - AMI: Amazon Linux 2023 (latest)
   - IAM Role: `eks_worker_nodes_role` (for the launched EC2 instances, not the controller)
   - Subnets: tagged `Type: public`
   - Security Group: tagged `name: worker-nodes-sg`
   - Tags: `Name: karpenter-node`, `environment: dev`

## Dev vs Prod Differences

### Controller (HelmRelease)

| Setting | Dev | Prod |
|---------|-----|------|
| Controller replicas | 2 | 1 |

### NodePool

| Setting | Dev | Prod (base defaults) |
|---------|-----|---------------------|
| Capacity types | Spot only | Spot + On-Demand |
| Instance types | t3.medium, t3a.medium, t3.large, t3a.large | All 6 types including m5.large, m5a.large |
| CPU limit | 20 | 100 |
| Memory limit | 80Gi | 400Gi |
| Environment tag | dev | dev (base default) |

The dev overlay aggressively uses Spot instances and limits cluster size to control costs. Production allows On-Demand instances for reliability and has much higher scaling limits.

## How Authentication Works (IRSA)

Karpenter needs AWS permissions to launch and terminate EC2 instances. IRSA (IAM Roles for Service Accounts) provides these without storing credentials.

```
1. Terraform creates IAM role "karpenter_irsa_role"
   (terraform-infra/root/dev/iam-roles/main.tf)
          │
          ▼
2. Trust policy: only karpenter:karpenter service account can assume it
   (StringEquals condition on OIDC provider)
          │
          ▼
3. Attached policy grants (terraform-infra/iam-role-module/Policies/karpenter_policy.json):
   - EC2: CreateFleet, RunInstances, TerminateInstances, Describe*
   - IAM: Manage instance profiles (for worker nodes)
   - IAM: PassRole for eks_worker_nodes_role
   - EKS: DescribeCluster
   - SSM: GetParameter (for AMI lookup)
   - SQS: Read interruption queue
   - Pricing: GetProducts (for cost-aware scheduling)
          │
          ▼
4. HelmRelease annotates the service account with the role ARN
          │
          ▼
5. EKS injects temporary AWS credentials into Karpenter pods
```

## Related Files in Other Directories

| File | Why it matters |
|------|---------------|
| `clusters/dev-projectx/karpenter.yaml` | Contains TWO Flux Kustomizations: one for the controller (`karpenter`) and one for nodepools (`karpenter-nodepool`). The nodepool Kustomization has `dependsOn: [karpenter]` so the controller is running before NodePool CRs are applied |
| `terraform-infra/root/dev/iam-roles/main.tf` | Creates `karpenter_irsa_role` with OIDC trust for the karpenter service account |
| `terraform-infra/iam-role-module/Policies/karpenter_policy.json` | IAM policy with EC2, IAM, EKS, SSM, SQS, and Pricing permissions |
| `terraform-infra/eks-cluster/flux.tf` | Bootstraps Flux on the cluster, enabling the GitOps pipeline |

## How Flux Deploys This (GitOps Flow)

```
1. You push changes to the "main" branch on GitHub
          │
          ▼
2. Flux's GitRepository source detects the new commit
          │
          ▼
3. Flux processes TWO Kustomizations (from clusters/dev-projectx/karpenter.yaml):

   Kustomization "karpenter" (runs first):
   - Path: ./platform-tools/karpenter/overlays/dev
   - Kustomize merges base/ + dev/patch.yaml
   - Applies: Namespace, HelmRepository, HelmRelease
          │
          ▼
4. Flux Helm controller installs the karpenter chart
   - Controller pods start in karpenter namespace
   - IRSA provides AWS credentials
          │
          ▼
5. Kustomization "karpenter-nodepool" (runs after karpenter is Ready):
   - dependsOn: [karpenter]
   - Path: ./platform-tools/karpenter/nodepool/overlays/dev
   - Kustomize merges nodepool/base/ + nodepool/dev/patch.yaml
   - Applies: NodePool + EC2NodeClass custom resources
          │
          ▼
6. Karpenter controller picks up the NodePool and starts watching for pending pods
```

## How Consolidation Works

Karpenter does not just add nodes -- it also removes them to save money:

```
1. Karpenter notices a node is underutilized or empty
          │
          ▼
2. consolidationPolicy: WhenEmptyOrUnderutilized
   consolidateAfter: 30s
          │
          ▼
3. If pods can be moved to other nodes, Karpenter:
   - Cordons the node (no new pods)
   - Drains the node (evicts pods gracefully)
   - Terminates the EC2 instance
```

## Troubleshooting

```bash
# Check if Flux Kustomizations are healthy
flux get kustomizations | grep karpenter

# Check HelmRelease status
flux get helmreleases -n karpenter

# Check controller pods
kubectl get pods -n karpenter

# Check controller logs (shows provisioning decisions)
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter

# Check NodePool and EC2NodeClass
kubectl get nodepools
kubectl get ec2nodeclasses
kubectl describe nodepool default

# See what nodes Karpenter has provisioned
kubectl get nodes -l karpenter.sh/registered=true

# Check for pending pods (these trigger Karpenter)
kubectl get pods --all-namespaces --field-selector=status.phase=Pending

# Check Karpenter events
kubectl get events -n karpenter --sort-by='.lastTimestamp'

# Check the SQS interruption queue
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/372517046622/projectx-karpenter \
  --attribute-names ApproximateNumberOfMessages

# Force Flux to reconcile
flux reconcile kustomization karpenter
flux reconcile kustomization karpenter-nodepool
flux reconcile helmrelease karpenter -n karpenter

# Check IRSA is working (should show AWS credentials)
kubectl exec -n karpenter deploy/karpenter -c controller -- env | grep AWS
```
