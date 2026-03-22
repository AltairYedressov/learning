# Velero - Backup and Disaster Recovery for Kubernetes

## What is Velero?

Velero (formerly Heptio Ark) is a tool that backs up your entire Kubernetes cluster -- namespaces, deployments, services, configmaps, secrets, persistent volumes, and everything else -- to an S3 bucket. If something goes wrong (accidental deletion, failed upgrade, cluster corruption), you can restore individual resources or entire namespaces from a backup. Velero also supports scheduled backups (like a daily cron job) and can snapshot EBS volumes for stateful workloads.

## Architecture - How It All Connects

```
  EKS Cluster (projectx)                                         AWS
  =======================                                        ===

  ┌───────────────────────────────────────┐
  │          velero namespace              │
  │                                        │
  │  ┌────────────────────────────────┐   │
  │  │  Velero Server                   │   │
  │  │  (Deployment)                    │   │
  │  │                                  │   │      ┌──────────────────────────┐
  │  │  1. Queries K8s API for         │   │      │  S3 Bucket                │
  │  │     all resources in target     │───┼──────▶│  372517046622-velero-     │
  │  │     namespaces                  │   │      │  backups-dev              │
  │  │  2. Serializes to JSON/tarball  │   │      │                           │
  │  │  3. Uploads to S3               │   │      │  Contains:                │
  │  │                                  │   │      │  - Resource manifests     │
  │  │  Uses IRSA for AWS auth         │   │      │  - Volume snapshots       │
  │  │  (no stored credentials)        │   │      │  - Backup metadata        │
  │  └──────────┬─────────────────────┘   │      │                           │
  │             │                          │      │  Lifecycle: 30-day expiry │
  │             │                          │      └──────────────────────────┘
  │             ▼                          │
  │  ┌────────────────────────────────┐   │      ┌──────────────────────────┐
  │  │  AWS Volume Snapshotter         │   │      │  EBS Snapshots            │
  │  │  (init container plugin)        │───┼──────▶│  (for PersistentVolumes) │
  │  │  velero-plugin-for-aws:v1.11.0 │   │      └──────────────────────────┘
  │  └────────────────────────────────┘   │
  │                                        │
  └───────────────────────────────────────┘

  Backup Schedule (dev):
  ┌──────────────────────────────────────────────────────────────────┐
  │  "daily-backup" -- runs at 22:00 UTC every day                   │
  │  TTL: 168h (7 days) -- old backups auto-deleted                  │
  │  Namespaces: monitoring, karpenter, flux-system                  │
  └──────────────────────────────────────────────────────────────────┘
```

### What Gets Backed Up

Velero backs up Kubernetes resources (YAML manifests) and optionally persistent volume data:

| What | How |
|------|-----|
| Deployments, Services, ConfigMaps, Secrets, CRDs, etc. | Serialized from the K8s API and stored as JSON in S3 |
| PersistentVolumes (EBS) | EBS snapshots via the AWS plugin |
| Backup metadata (timestamps, status, resource counts) | Stored alongside the backup in S3 |

## File Structure

```
platform-tools/velero/
├── base/                              # Shared configuration for all environments
│   ├── kustomization.yaml             # Lists base resources
│   ├── namespace.yaml                 # Creates the "velero" namespace
│   ├── helmrepository.yaml            # VMware Tanzu Helm chart repo
│   └── helmrelease.yaml               # Velero chart config with IRSA + S3 + plugin
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml         # Imports base + dev patch
    │   └── patch.yaml                 # Dev: daily backup schedule, dev bucket
    └── prod/
        ├── kustomization.yaml         # Imports base + prod patch
        └── patch.yaml                 # Prod overrides
```

### What Each File Does

**`base/namespace.yaml`** -- Creates the `velero` namespace.

**`base/helmrepository.yaml`** -- Registers the VMware Tanzu Helm chart repository at `https://vmware-tanzu.github.io/helm-charts`. Flux polls for new chart versions every hour.

**`base/helmrelease.yaml`** -- The main configuration for Velero:
- **Chart version**: `8.1.0` (pinned)
- **Credentials**: `useSecret: false` -- disables static AWS credentials, forces IRSA instead
- **IRSA**: Service account annotated with `arn:aws:iam::372517046622:role/velero-role`
- **Backup Storage Location (BSL)**: S3 bucket `372517046622-velero-backups-dev` in `us-east-1`
- **Volume Snapshot Location (VSL)**: EBS snapshots in `us-east-1`
- **AWS Plugin**: `velero-plugin-for-aws:v1.11.0` loaded as an init container that copies the plugin binary into the Velero server pod
- **CRD upgrades**: Disabled (`upgradeCRDs: false`) to avoid problematic upgrade jobs

**`overlays/dev/patch.yaml`** -- Dev-specific configuration:
- Adds a `daily-backup` schedule: runs at 22:00 UTC, TTL of 168h (7 days)
- Backs up namespaces: `monitoring`, `karpenter`, `flux-system`
- Confirms the dev S3 bucket and region
- Uses `bitnami/kubectl` image for kubectl operations

**`overlays/prod/patch.yaml`** -- Prod overrides (currently references the same base structure for production-grade settings).

## Dev vs Prod Differences

| Setting | Dev | Prod |
|---------|-----|------|
| S3 bucket | `372517046622-velero-backups-dev` | `372517046622-velero-backups-prod` (expected) |
| Backup schedule | Daily at 22:00 UTC | Likely more frequent |
| Backup TTL | 168h (7 days) | Longer retention |
| Backed-up namespaces | monitoring, karpenter, flux-system | All critical namespaces |
| S3 lifecycle | 30-day expiry (Terraform) | Longer retention |

## How Authentication Works (IRSA)

Velero needs S3 and EC2 permissions to store backups and take EBS snapshots. IRSA provides these without static credentials.

```
1. Terraform creates IAM role "velero-role"
   (terraform-infra/root/dev/iam-roles/main.tf)
          │
          ▼
2. Trust policy: only velero:velero-server service account can assume it
          │
          ▼
3. Attached policy grants (terraform-infra/iam-role-module/Policies/velero_policy.json):
   - S3: GetObject, PutObject, DeleteObject, ListBucket
     (scoped to arn:aws:s3:::372517046622-velero-backups-dev/*)
   - EC2: DescribeVolumes, DescribeSnapshots, CreateSnapshot,
     DeleteSnapshot, CreateVolume, CreateTags
          │
          ▼
4. HelmRelease annotates the velero-server service account with the role ARN
          │
          ▼
5. EKS injects temporary AWS credentials into the Velero pod
```

## Related Files in Other Directories

| File | Why it matters |
|------|---------------|
| `clusters/dev-projectx/velero.yaml` | Flux Kustomization that tells Flux to deploy `platform-tools/velero/overlays/dev` |
| `terraform-infra/root/dev/s3/main.tf` | Creates the `372517046622-velero-backups-dev` S3 bucket with versioning enabled and 30-day lifecycle expiry |
| `terraform-infra/root/dev/iam-roles/main.tf` | Creates the `velero-role` IRSA role trusted by the velero-server service account |
| `terraform-infra/iam-role-module/Policies/velero_policy.json` | IAM policy with S3 and EC2 snapshot permissions scoped to the Velero bucket |
| `terraform-infra/eks-cluster/flux.tf` | Bootstraps Flux on the cluster |

## How Flux Deploys This (GitOps Flow)

```
1. You push changes to the "main" branch on GitHub
          │
          ▼
2. Flux's GitRepository source detects the new commit
          │
          ▼
3. Flux's Kustomization "velero" (clusters/dev-projectx/velero.yaml):
   - Path: ./platform-tools/velero/overlays/dev
   - Runs Kustomize: merges base/ + dev/patch.yaml
          │
          ▼
4. Flux applies the rendered manifests:
   - Namespace (velero)
   - HelmRepository (VMware Tanzu chart source)
   - HelmRelease (Velero chart with IRSA, S3, plugin, schedule)
          │
          ▼
5. Flux's Helm controller:
   - Pulls the velero chart version 8.1.0
   - Renders templates with merged values
   - Installs/upgrades the release
          │
          ▼
6. Velero server starts:
   - Init container loads the AWS plugin
   - Creates BackupStorageLocation pointing to S3
   - Creates VolumeSnapshotLocation for EBS
   - Starts the daily-backup CronJob schedule
```

## The Base/Overlay Pattern (Kustomize)

```
                    base/
                    (Velero server + IRSA + S3 bucket + AWS plugin)
                   /              \
                  /                \
    overlays/dev/              overlays/prod/
    (daily backup at 22:00,    (more frequent backups,
     7-day TTL, 3 namespaces,   longer retention,
     dev S3 bucket)             prod S3 bucket)
```

## Common Operations

```bash
# Create a one-off backup of a namespace
velero backup create my-backup --include-namespaces monitoring

# List all backups
velero backup get

# Check backup details
velero backup describe my-backup --details

# Restore from a backup
velero restore create --from-backup my-backup

# Restore only specific resources
velero restore create --from-backup my-backup --include-resources deployments,services

# Check scheduled backups
velero schedule get

# Check backup storage location status
velero backup-location get
```

## Prerequisites Checklist

Before Velero can deploy successfully:

- [ ] **S3 bucket exists** -- Run `terraform apply` in `terraform-infra/root/dev/s3/`
- [ ] **IAM role exists** -- Run `terraform apply` in `terraform-infra/root/dev/iam-roles/`
- [ ] **EBS CSI driver is installed** -- Needed for volume snapshots (managed as EKS addon)

## Troubleshooting

```bash
# Check Flux Kustomization status
flux get kustomizations velero

# Check HelmRelease status
flux get helmreleases -n velero

# Check Velero pods (should see server + init container completed)
kubectl get pods -n velero

# Check Velero server logs
kubectl logs -n velero -l app.kubernetes.io/name=velero

# Check BackupStorageLocation status (should be "Available")
kubectl get backupstoragelocation -n velero
velero backup-location get

# Check if backups are running on schedule
velero schedule get
velero backup get --sort-by='.metadata.creationTimestamp'

# Check for failed backups
velero backup get | grep -v Completed

# Debug IRSA (check if AWS credentials are injected)
kubectl describe pod -n velero -l app.kubernetes.io/name=velero | grep -A5 "AWS_"

# Check events
kubectl get events -n velero --sort-by='.lastTimestamp'

# Force Flux to reconcile
flux reconcile kustomization velero
flux reconcile helmrelease velero -n velero

# Test S3 connectivity from the pod
kubectl exec -n velero deploy/velero -- aws s3 ls s3://372517046622-velero-backups-dev/
```
