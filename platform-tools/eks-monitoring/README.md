# EKS Monitoring - Prometheus + Grafana Monitoring Stack

## What is This?

This deploys the `kube-prometheus-stack`, an all-in-one monitoring solution for Kubernetes that bundles Prometheus (metrics collection and storage), Grafana (dashboards and visualization), Alertmanager (alert routing), and a set of pre-configured recording rules and dashboards for Kubernetes. It gives you full observability into your EKS cluster -- CPU, memory, network, pod health, node status, and application metrics -- out of the box.

## Architecture - How It All Connects

```
  EKS Cluster (projectx)
  ┌───────────────────────────────────────────────────────────────────────────┐
  │                                                                           │
  │                          monitoring namespace                             │
  │  ┌─────────────────────────────────────────────────────────────────────┐  │
  │  │                                                                     │  │
  │  │  ┌──────────────────┐     queries      ┌───────────────────────┐   │  │
  │  │  │     Grafana       │ ───────────────▶ │     Prometheus         │   │  │
  │  │  │  (Dashboards UI)  │                  │  (Time-series DB)      │   │  │
  │  │  │                   │                  │                         │   │  │
  │  │  │  Port: 3000       │                  │  Retention: 10d (base) │   │  │
  │  │  │  Service: ClusterIP│                 │  Storage: 20Gi (base)  │   │  │
  │  │  └──────────────────┘                  │                         │   │  │
  │  │                                         │  Scrapes metrics every  │   │  │
  │  │                                         │  15-30s from:           │   │  │
  │  │  ┌──────────────────┐                  │  - kubelet              │   │  │
  │  │  │   Alertmanager    │ ◀── alerts ──── │  - kube-state-metrics   │   │  │
  │  │  │  (Alert routing)  │                  │  - node-exporter        │   │  │
  │  │  └──────────────────┘                  │  - ServiceMonitors      │   │  │
  │  │                                         └──────────┬──────────────┘   │  │
  │  │                                                    │                   │  │
  │  │                                         ┌──────────▼──────────────┐   │  │
  │  │                                         │   Thanos Sidecar        │   │  │
  │  │                                         │  (uploads blocks to S3) │   │  │
  │  │                                         │  (see thanos/ README)   │   │  │
  │  │                                         └─────────────────────────┘   │  │
  │  └─────────────────────────────────────────────────────────────────────┘  │
  │                                                                           │
  │  Prometheus scrapes from all namespaces:                                  │
  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────────┐   │
  │  │ kube-system  │  │  karpenter  │  │   velero    │  │sealed-secrets │   │
  │  │ (kubelet,    │  │ (controller │  │ (server     │  │(controller    │   │
  │  │  coredns)    │  │  metrics)   │  │  metrics)   │  │ metrics:8081) │   │
  │  └─────────────┘  └─────────────┘  └─────────────┘  └───────────────┘   │
  └───────────────────────────────────────────────────────────────────────────┘
```

### How Prometheus Discovers What to Scrape

Prometheus uses **ServiceMonitors** (a CRD) to automatically discover scrape targets:

```
1. A tool (e.g., sealed-secrets) creates a ServiceMonitor in its namespace
          │
          ▼
2. The ServiceMonitor says: "scrape port 8081 every 30s, label: release=kube-prometheus-stack"
          │
          ▼
3. Prometheus watches for ServiceMonitors matching its selector (release=kube-prometheus-stack)
          │
          ▼
4. Prometheus adds the target to its scrape config automatically
          │
          ▼
5. Metrics appear in Grafana dashboards
```

### The Thanos Integration

This monitoring stack is configured to work with Thanos for long-term metric storage:
- The Prometheus service account has the IRSA annotation for `thanos-role` (S3 access)
- `thanosService` and `thanosServiceMonitor` are enabled
- `objectStorageConfig` references a SealedSecret with S3 bucket configuration
- A Thanos sidecar runs inside the Prometheus pod and uploads metric blocks to S3

See the `platform-tools/thanos/README.md` for the full Thanos architecture.

## File Structure

```
platform-tools/eks-monitoring/
├── base/                              # Shared monitoring configuration
│   ├── kustomization.yaml             # Lists base resources
│   ├── namespace.yaml                 # Creates "monitoring" namespace
│   ├── helmrepository.yaml            # prometheus-community Helm repo
│   └── helmrelease.yaml               # kube-prometheus-stack chart config
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml         # Imports base + dev patch
    │   └── patch.yaml                 # Dev: 3-day retention, 10Gi, 1 Grafana replica
    └── prod/
        ├── kustomization.yaml         # Imports base + prod patch
        └── patch.yaml                 # Prod: 30-day retention, 50Gi, 2 Grafana replicas
```

### What Each File Does

**`base/namespace.yaml`** -- Creates the `monitoring` namespace. This namespace is shared with Thanos (both deploy into `monitoring`).

**`base/helmrepository.yaml`** -- Registers the `prometheus-community` Helm chart repo at `https://prometheus-community.github.io/helm-charts`. Flux polls every 10 minutes.

**`base/helmrelease.yaml`** -- The main monitoring stack configuration:
- **Chart**: `kube-prometheus-stack` version `58.x.x`
- **Grafana**: Admin user `admin`, ClusterIP service (not exposed externally)
- **Prometheus**:
  - IRSA annotation for `thanos-role` (S3 access for Thanos sidecar)
  - Thanos sidecar enabled (`thanosService`, `thanosServiceMonitor`)
  - Object storage config from SealedSecret `thanos-objstore-secret`
  - Retention: 10 days (local), storage: 20Gi on gp2 EBS
- **Components included**: Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics, recording/alerting rules, pre-built dashboards

**`overlays/dev/patch.yaml`** -- Dev overrides:
- Prometheus retention: 3 days (saves disk)
- Storage: 10Gi (smaller PVC)
- Grafana: 1 replica, `dev-password`

**`overlays/prod/patch.yaml`** -- Production overrides:
- Prometheus retention: 30 days
- Storage: 50Gi
- Grafana: 2 replicas (HA), `prod-password`

## Dev vs Prod Differences

| Setting | Dev | Prod | Base (default) |
|---------|-----|------|----------------|
| Prometheus retention | 3d | 30d | 10d |
| Prometheus storage | 10Gi | 50Gi | 20Gi |
| Grafana replicas | 1 | 2 | 1 |
| Grafana admin password | dev-password | prod-password | admin123 |
| Thanos sidecar | enabled (base) | enabled (base) | enabled |
| IRSA for S3 | enabled (base) | enabled (base) | enabled |

**Note**: The Grafana admin passwords are currently stored in plaintext in the patch files. In a production environment, these should be managed via SealedSecrets instead.

## The Base/Overlay Pattern (Kustomize)

```
                    base/
                    (full kube-prometheus-stack with Thanos integration)
                   /              \
                  /                \
    overlays/dev/              overlays/prod/
    (3d retention, 10Gi,       (30d retention, 50Gi,
     1 Grafana replica,         2 Grafana replicas,
     dev password)              prod password)
```

## Related Files in Other Directories

| File | Why it matters |
|------|---------------|
| `clusters/dev-projectx/monitoring.yaml` | Flux Kustomization that deploys `platform-tools/eks-monitoring/overlays/dev` |
| `platform-tools/thanos/` | Deploys Thanos Query, Store Gateway, Compactor that extend Prometheus with long-term S3 storage |
| `platform-tools/thanos/base/thanos-objstore-sealed-secret.yaml` | SealedSecret with S3 config referenced by Prometheus's `objectStorageConfig` |
| `platform-tools/sealed-secrets/` | The Sealed Secrets controller that decrypts the Thanos SealedSecret |
| `terraform-infra/root/dev/iam-roles/main.tf` | Creates `thanos-role` IRSA (used by the Prometheus service account for S3 uploads) |
| `terraform-infra/root/dev/s3/main.tf` | Creates the `372517046622-thanos-dev` S3 bucket for long-term metric storage |

## How Flux Deploys This (GitOps Flow)

```
1. You push changes to the "main" branch on GitHub
          │
          ▼
2. Flux's GitRepository source detects the new commit
          │
          ▼
3. Flux's Kustomization "monitoring" (clusters/dev-projectx/monitoring.yaml):
   - Path: ./platform-tools/eks-monitoring/overlays/dev
   - Runs Kustomize: merges base/ + dev/patch.yaml
          │
          ▼
4. Flux applies the rendered manifests:
   - Namespace (monitoring)
   - HelmRepository (prometheus-community)
   - HelmRelease (kube-prometheus-stack with all values)
          │
          ▼
5. Flux's Helm controller:
   - Pulls the kube-prometheus-stack chart (~58.x.x)
   - Renders ALL sub-charts: Prometheus, Grafana, Alertmanager,
     node-exporter, kube-state-metrics
   - Installs/upgrades the Helm release
          │
          ▼
6. Components start up:
   - Prometheus begins scraping (kubelet, kube-state-metrics, node-exporter)
   - Thanos sidecar starts uploading metric blocks to S3
   - Grafana loads pre-built K8s dashboards
   - Alertmanager starts evaluating alert rules
```

## Accessing Grafana

Grafana is exposed as a ClusterIP service (not accessible from outside the cluster). To access it:

```bash
# Port-forward to your local machine
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Then open http://localhost:3000 in your browser
# Login: admin / dev-password (dev) or admin / prod-password (prod)
```

## Troubleshooting

```bash
# Check Flux Kustomization status
flux get kustomizations monitoring

# Check HelmRelease status (this is a large chart, may take a few minutes)
flux get helmreleases -n monitoring

# Check all pods in monitoring namespace
kubectl get pods -n monitoring

# Check Prometheus is scraping targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Then open http://localhost:9090/targets

# Check Prometheus storage (PVC)
kubectl get pvc -n monitoring

# Check Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# Check Prometheus logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -c prometheus

# Check Thanos sidecar logs (runs inside Prometheus pod)
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -c thanos-sidecar

# Check Alertmanager
kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager

# List all ServiceMonitors (what Prometheus is configured to scrape)
kubectl get servicemonitors -A

# Check if the Thanos objstore secret exists (needed for sidecar)
kubectl get secret thanos-objstore-secret -n monitoring

# Force Flux to reconcile
flux reconcile kustomization monitoring
flux reconcile helmrelease kube-prometheus-stack -n monitoring

# Check events for errors
kubectl get events -n monitoring --sort-by='.lastTimestamp'

# Check resource usage of monitoring stack
kubectl top pods -n monitoring
```
