# Thanos - Long-Term Metrics Storage for Prometheus

## What is Thanos?

Thanos extends Prometheus with long-term storage and high availability. Without Thanos, Prometheus stores metrics locally on disk — if the pod restarts or disk fills up, you lose your metrics. Thanos solves this by shipping metric blocks to S3 (cheap, durable storage) and providing a unified query layer across both real-time and historical data.

## Architecture - How It All Connects

```
                                    ┌─────────────────────────┐
                                    │        Grafana           │
                                    │  (queries Thanos Query)  │
                                    └───────────┬─────────────┘
                                                │
                                    ┌───────────▼─────────────┐
                                    │      Thanos Query        │
                                    │ (fans out to all stores) │
                                    └──────┬──────────┬───────┘
                                           │          │
                          ┌────────────────┘          └────────────────┐
                          │                                            │
              ┌───────────▼───────────┐                  ┌─────────────▼──────────┐
              │   Thanos Sidecar       │                  │  Thanos Store Gateway   │
              │ (runs next to          │                  │ (reads historical       │
              │  Prometheus pod)       │                  │  blocks from S3)        │
              └───────────┬───────────┘                  └─────────────┬──────────┘
                          │                                            │
              ┌───────────▼───────────┐                  ┌─────────────▼──────────┐
              │     Prometheus         │                  │      S3 Bucket          │
              │ (real-time metrics,    │─── uploads ────▶│ (372517046622-thanos-   │
              │  last 10 days)         │    blocks        │  dev)                   │
              └───────────────────────┘                  └─────────────┬──────────┘
                                                                       │
                                                         ┌─────────────▼──────────┐
                                                         │   Thanos Compactor      │
                                                         │ (downsamples old data,  │
                                                         │  deduplicates blocks)   │
                                                         └────────────────────────┘
```

### Component Breakdown

| Component | What it does | Where it runs |
|-----------|-------------|---------------|
| **Thanos Sidecar** | Sits next to Prometheus, uploads metric blocks to S3, serves real-time data to Query | Inside the Prometheus pod (added via kube-prometheus-stack config) |
| **Thanos Query** | Central query endpoint — Grafana talks to this. Fans out queries to Sidecar (real-time) and Store Gateway (historical) | Own deployment in `monitoring` namespace |
| **Thanos Store Gateway** | Reads old metric blocks from S3 and serves them to Query | Own StatefulSet in `monitoring` namespace |
| **Thanos Compactor** | Runs periodically to downsample old data (5m, 1h averages) and deduplicate blocks in S3 | Own StatefulSet in `monitoring` namespace |
| **Query Frontend** | Optional caching layer in front of Query — splits large queries into smaller ones | Own deployment (disabled in dev) |

## File Structure

```
platform-tools/thanos/
├── base/
│   ├── kustomization.yaml                    # Lists all base resources
│   ├── helmrepository.yaml                   # Points Flux to Bitnami OCI registry
│   ├── helmrelease.yaml                      # Thanos Helm chart configuration
│   └── thanos-objstore-sealed-secret.yaml    # Encrypted S3 config (SealedSecret)
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml                # Imports base + applies dev patch
    │   └── patch.yaml                        # Dev overrides (fewer replicas, less storage)
    └── prod/
        ├── kustomization.yaml                # Imports base + applies prod patch
        └── patch.yaml                        # Prod overrides (more replicas, more storage)
```

### Related files in other directories

| File | Why it matters |
|------|---------------|
| `clusters/dev-projectx/thanos.yaml` | Flux Kustomization — tells Flux to deploy `platform-tools/thanos/overlays/dev`. Has `dependsOn: [monitoring, sealed-secrets]` so it waits for Prometheus and SealedSecrets controller to be healthy first |
| `platform-tools/eks-monitoring/base/helmrelease.yaml` | Modified to enable the Thanos sidecar inside Prometheus. Added `thanosService`, `thanosServiceMonitor`, IRSA annotation, and `objectStorageConfig` pointing to the SealedSecret |
| `terraform-infra/root/dev/s3/main.tf` | Creates the `372517046622-thanos-dev` S3 bucket |
| `terraform-infra/root/dev/iam-roles/main.tf` | Creates the `thanos-role` IRSA role trusted by storegateway, compactor, and prometheus service accounts |
| `terraform-infra/iam-role-module/Policies/thanos_policy.json` | IAM policy granting S3 read/write/list to the Thanos bucket only |

## How Secrets Work (SealedSecrets Flow)

Thanos needs to know which S3 bucket to use. This config is stored as a Kubernetes Secret, but we **never commit plaintext secrets to Git**. Instead:

```
1. You write the plaintext S3 config (objstore.yml)
          │
          ▼
2. kubeseal encrypts it using the cluster's public key
          │
          ▼
3. The encrypted SealedSecret YAML is committed to Git
          │
          ▼
4. Flux applies the SealedSecret to the cluster
          │
          ▼
5. The sealed-secrets controller decrypts it into a regular Secret
          │
          ▼
6. Thanos pods mount the Secret and read the S3 config
```

### Generating the SealedSecret

The file `thanos-objstore-sealed-secret.yaml` has a `<SEALED_VALUE>` placeholder. Replace it by running:

```bash
# Step 1: Create the plaintext config file
cat <<EOF > /tmp/objstore.yml
type: S3
config:
  bucket: 372517046622-thanos-dev
  endpoint: s3.us-east-1.amazonaws.com
  region: us-east-1
EOF

# Step 2: Encrypt it with kubeseal
#   - Creates a dry-run Secret, pipes it to kubeseal
#   - kubeseal fetches the public key from the sealed-secrets controller
#   - Output is an encrypted SealedSecret YAML
kubectl create secret generic thanos-objstore-secret \
  --namespace monitoring \
  --from-file=objstore.yml=/tmp/objstore.yml \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=sealed-secrets \
           --controller-namespace=sealed-secrets \
           --format yaml

# Step 3: Replace the entire thanos-objstore-sealed-secret.yaml with the output

# Step 4: Clean up
rm /tmp/objstore.yml
```

**Note:** No `access_key` or `secret_key` in the config — authentication is handled by IRSA (the pod's service account assumes the IAM role automatically).

## How Authentication Works (IRSA)

IRSA (IAM Roles for Service Accounts) lets Kubernetes pods assume AWS IAM roles without storing credentials.

```
1. Terraform creates IAM role "thanos-role" with S3 permissions
          │
          ▼
2. The role's trust policy says: "only these K8s service accounts can assume me"
   - monitoring:thanos-storegateway
   - monitoring:thanos-compactor
   - monitoring:kube-prometheus-stack-prometheus  (for the sidecar)
          │
          ▼
3. The HelmRelease annotates each service account with:
   eks.amazonaws.com/role-arn: arn:aws:iam::372517046622:role/thanos-role
          │
          ▼
4. When a pod starts, EKS injects temporary AWS credentials via a projected token
          │
          ▼
5. The AWS SDK in Thanos automatically picks up these credentials
```

## How Flux Deploys This (GitOps Flow)

```
1. You push changes to the "main" branch on GitHub
          │
          ▼
2. Flux's GitRepository source detects the new commit (polls every 1m)
          │
          ▼
3. Flux's Kustomization "thanos" (clusters/dev-projectx/thanos.yaml):
   - Checks dependsOn: waits for "monitoring" and "sealed-secrets" to be Ready
   - Runs Kustomize on platform-tools/thanos/overlays/dev/
   - Kustomize merges base/ + dev/patch.yaml
          │
          ▼
4. Flux applies the rendered manifests:
   - HelmRepository (OCI source for Bitnami charts)
   - SealedSecret (encrypted S3 config)
   - HelmRelease (Thanos chart with all values)
          │
          ▼
5. Flux's Helm controller:
   - Pulls the thanos chart from oci://registry-1.docker.io/bitnamicharts
   - Renders the chart with base values merged with dev patch values
   - Installs/upgrades the Helm release
          │
          ▼
6. Health check: Flux watches Deployment/thanos-query in monitoring namespace
   - If it becomes Ready → Kustomization goes Ready
   - If it doesn't within 5m → timeout error
```

## Dev vs Prod Differences

| Setting | Dev (patch) | Prod (patch) | Base (default) |
|---------|-------------|--------------|----------------|
| Query replicas | 1 | 2 | 2 |
| Query Frontend | disabled | 2 replicas | 1 replica |
| Store Gateway replicas | 1 | 2 | 1 |
| Store Gateway disk | 5Gi | 20Gi | 10Gi |
| Compactor disk | 10Gi | 50Gi | 20Gi |
| Raw retention | 7d | 90d | 30d |
| 5m downsampled retention | 30d | 180d | 90d |
| 1h downsampled retention | 90d | 365d | 365d |
| Query resources | 50m/128Mi | base defaults | 100m/256Mi |

## Prerequisites Checklist

Before Thanos can deploy successfully, these must be in place:

- [ ] **S3 bucket exists** — Run `terraform apply` in `terraform-infra/root/dev/s3/`
- [ ] **IAM role exists** — Run `terraform apply` in `terraform-infra/root/dev/iam-roles/`
- [ ] **sealed-secrets controller is running** — Needed to decrypt the SealedSecret
- [ ] **SealedSecret is generated** — Replace `<SEALED_VALUE>` using kubeseal (see instructions above)
- [ ] **kube-prometheus-stack is running** — Thanos depends on it (the sidecar runs inside Prometheus)

## Troubleshooting

```bash
# Check if all Flux sources are ready
flux get sources helm -A

# Check HelmRelease status (shows install/upgrade errors)
flux get helmreleases -n monitoring

# Check if the SealedSecret was decrypted into a Secret
kubectl get secret thanos-objstore-secret -n monitoring

# Check Thanos pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=thanos

# Check Thanos Query logs
kubectl logs -n monitoring -l app.kubernetes.io/component=query

# Check if the sidecar is running inside Prometheus
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[*].spec.containers[*].name}'
# Should show: prometheus, thanos-sidecar

# Force Flux to retry
flux reconcile helmrelease thanos -n monitoring
```
