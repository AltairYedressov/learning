# EFK Logging - Elasticsearch + Fluent-bit + Kibana Logging Stack

## What is This?

The EFK stack (Elasticsearch, Fluent-bit, Kibana) is a centralized logging solution for Kubernetes. Instead of SSHing into individual pods to read logs, the EFK stack automatically collects logs from every container in the cluster, stores them in a searchable database (Elasticsearch), and provides a web UI (Kibana) to search, filter, and visualize them. Fluent-bit is a lightweight log forwarder that runs on every node and ships logs to Elasticsearch.

## Architecture - How It All Connects

```
  EKS Cluster (projectx)
  ┌────────────────────────────────────────────────────────────────────────────┐
  │                                                                            │
  │  Every Worker Node:                                                        │
  │  ┌──────────────────────────────────────────────────┐                      │
  │  │                                                    │                      │
  │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐          │                      │
  │  │  │ App Pod 1 │ │ App Pod 2 │ │ App Pod 3 │ ...    │                      │
  │  │  │ (stdout)  │ │ (stdout)  │ │ (stdout)  │          │                      │
  │  │  └─────┬─────┘ └─────┬─────┘ └─────┬─────┘          │                      │
  │  │        │              │              │                │                      │
  │  │        ▼              ▼              ▼                │                      │
  │  │  ┌─────────────────────────────────────────┐      │                      │
  │  │  │  /var/log/containers/*.log               │      │                      │
  │  │  │  (container logs on disk)                │      │                      │
  │  │  └─────────────────┬───────────────────────┘      │                      │
  │  │                    │                                │                      │
  │  │                    ▼                                │                      │
  │  │  ┌─────────────────────────────────────────┐      │                      │
  │  │  │         Fluent-bit (DaemonSet)           │      │                      │
  │  │  │  - Tails log files                       │      │                      │
  │  │  │  - Parses JSON/text logs                 │      │                      │
  │  │  │  - Adds K8s metadata (pod, namespace)    │      │                      │
  │  │  │  - Forwards to Elasticsearch              │      │                      │
  │  │  └─────────────────┬───────────────────────┘      │                      │
  │  │                    │                                │                      │
  │  └────────────────────┼────────────────────────────────┘                      │
  │                       │                                                        │
  │                       │  sends logs over HTTP                                  │
  │                       ▼                                                        │
  │  ┌──────────────────────────────────────────────────────┐                    │
  │  │                  monitoring namespace                  │                    │
  │  │                                                        │                    │
  │  │  ┌────────────────────────────────────────────────┐  │                    │
  │  │  │         Elasticsearch (StatefulSet)              │  │                    │
  │  │  │  - Stores and indexes all logs                   │  │                    │
  │  │  │  - Full-text search                              │  │                    │
  │  │  │  - Retention based on index lifecycle            │  │                    │
  │  │  │  - Storage: 20Gi PVC (base)                      │  │                    │
  │  │  └──────────────────┬─────────────────────────────┘  │                    │
  │  │                     │                                  │                    │
  │  │                     │ queries                          │                    │
  │  │                     ▼                                  │                    │
  │  │  ┌────────────────────────────────────────────────┐  │                    │
  │  │  │              Kibana (Deployment)                 │  │                    │
  │  │  │  - Web UI for searching logs                     │  │                    │
  │  │  │  - Create dashboards and visualizations          │  │                    │
  │  │  │  - Filter by namespace, pod, container, time     │  │                    │
  │  │  │  - Service: ClusterIP                            │  │                    │
  │  │  └────────────────────────────────────────────────┘  │                    │
  │  └──────────────────────────────────────────────────────┘                    │
  └────────────────────────────────────────────────────────────────────────────────┘
```

### How a Log Line Flows

```
1. Application writes to stdout/stderr
          │
          ▼
2. Container runtime (containerd) writes to /var/log/containers/<pod>_<ns>_<container>.log
          │
          ▼
3. Fluent-bit DaemonSet tails the log file
   - Parses JSON or plain text
   - Enriches with Kubernetes metadata (pod name, namespace, labels)
          │
          ▼
4. Fluent-bit forwards to Elasticsearch (HTTP)
          │
          ▼
5. Elasticsearch indexes the log entry
   - Creates daily indices (e.g., fluent-bit-2026.03.22)
          │
          ▼
6. You search in Kibana UI
   - Filter: namespace=velero AND level=error AND @timestamp > now-1h
```

## File Structure

```
platform-tools/efk-logging/
├── base/                              # Shared EFK configuration
│   ├── kustomization.yaml             # Lists base resources
│   ├── namespace.yaml                 # Creates "monitoring" namespace (shared with Prometheus)
│   ├── helmrepository.yaml            # prometheus-community Helm repo
│   └── helmrelease.yaml               # kube-prometheus-stack chart (includes EFK components)
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml         # Imports base + dev patch
    │   └── patch.yaml                 # Dev: 3d retention, 10Gi, 1 Grafana replica
    └── prod/
        ├── kustomization.yaml         # Imports base + prod patch
        └── patch.yaml                 # Prod: 30d retention, 50Gi, 2 Grafana replicas
```

### What Each File Does

**`base/namespace.yaml`** -- Creates the `monitoring` namespace. Note that this is the same namespace used by `eks-monitoring` (Prometheus/Grafana). Both monitoring and logging share this namespace since they are closely related observability tools.

**`base/helmrepository.yaml`** -- Registers the `prometheus-community` Helm chart repository. This is the same repository used by `eks-monitoring`, pointing to `https://prometheus-community.github.io/helm-charts`.

**`base/helmrelease.yaml`** -- Deploys the `kube-prometheus-stack` chart (version `58.x.x`) which includes logging components alongside monitoring:
- **Grafana**: Admin user `admin`, ClusterIP service
- **Prometheus**: 10-day retention, 20Gi gp2 storage
- This HelmRelease is configured as a variant of the monitoring stack that includes the logging pipeline

**`overlays/dev/patch.yaml`** -- Dev overrides:
- Prometheus retention: 3 days
- Storage: 10Gi
- Grafana: 1 replica, `dev-password`

**`overlays/prod/patch.yaml`** -- Production overrides:
- Prometheus retention: 30 days
- Storage: 50Gi
- Grafana: 2 replicas, `prod-password`

## Dev vs Prod Differences

| Setting | Dev | Prod | Base (default) |
|---------|-----|------|----------------|
| Prometheus retention | 3d | 30d | 10d |
| Storage | 10Gi | 50Gi | 20Gi |
| Grafana replicas | 1 | 2 | 1 |
| Grafana admin password | dev-password | prod-password | admin123 |

## The Base/Overlay Pattern (Kustomize)

```
                    base/
                    (full EFK stack configuration)
                   /              \
                  /                \
    overlays/dev/              overlays/prod/
    (less storage, shorter     (more storage, longer
     retention, fewer           retention, more
     replicas)                  replicas for HA)
```

## How the EFK Stack Relates to Other Tools

```
  ┌──────────────────────┐
  │  sealed-secrets       │ ─── Logs collected by Fluent-bit
  ├──────────────────────┤
  │  karpenter            │ ─── Logs collected by Fluent-bit
  ├──────────────────────┤
  │  velero               │ ─── Logs collected by Fluent-bit
  ├──────────────────────┤
  │  eks-monitoring       │ ─── Shares "monitoring" namespace
  │  (Prometheus/Grafana) │     Grafana can query both metrics AND logs
  ├──────────────────────┤
  │  thanos               │ ─── Shares "monitoring" namespace
  └──────────────────────┘

  All platform tools emit logs → Fluent-bit collects → Elasticsearch stores → Kibana searches
```

## Related Files in Other Directories

| File | Why it matters |
|------|---------------|
| `clusters/dev-projectx/monitoring.yaml` | Flux Kustomization that deploys the monitoring/logging stack from `platform-tools/eks-monitoring/overlays/dev` |
| `platform-tools/eks-monitoring/` | The monitoring stack (Prometheus/Grafana) that shares the `monitoring` namespace |
| `platform-tools/thanos/` | Long-term metric storage that also deploys into the `monitoring` namespace |
| `terraform-infra/eks-cluster/flux.tf` | Bootstraps Flux on the cluster |

## How Flux Deploys This (GitOps Flow)

```
1. You push changes to the "main" branch on GitHub
          │
          ▼
2. Flux's GitRepository source detects the new commit
          │
          ▼
3. Flux's Kustomization processes the EFK overlay:
   - Path: ./platform-tools/efk-logging/overlays/dev (or prod)
   - Runs Kustomize: merges base/ + overlay patch.yaml
          │
          ▼
4. Flux applies the rendered manifests:
   - Namespace (monitoring)
   - HelmRepository (prometheus-community)
   - HelmRelease (kube-prometheus-stack with EFK values)
          │
          ▼
5. Flux's Helm controller:
   - Pulls the chart version 58.x.x
   - Renders all sub-charts and templates
   - Installs/upgrades the release
          │
          ▼
6. Components start up:
   - Fluent-bit DaemonSet deploys to every node
   - Elasticsearch StatefulSet starts with persistent storage
   - Kibana Deployment provides the search UI
```

## Accessing Kibana

Kibana is exposed as a ClusterIP service. To access it:

```bash
# Port-forward to your local machine
kubectl port-forward -n monitoring svc/kibana 5601:5601

# Then open http://localhost:5601 in your browser
```

## Troubleshooting

```bash
# Check Flux Kustomization status
flux get kustomizations -A | grep -i log

# Check HelmRelease status
flux get helmreleases -n monitoring

# Check all logging-related pods
kubectl get pods -n monitoring

# Check Fluent-bit DaemonSet (should have one pod per node)
kubectl get daemonset -n monitoring
kubectl logs -n monitoring -l app=fluent-bit --tail=50

# Check Elasticsearch health
kubectl exec -n monitoring -it elasticsearch-0 -- curl -s http://localhost:9200/_cluster/health | python3 -m json.tool

# Check Elasticsearch indices
kubectl exec -n monitoring -it elasticsearch-0 -- curl -s http://localhost:9200/_cat/indices?v

# Check Kibana logs
kubectl logs -n monitoring -l app=kibana

# Check persistent volume claims
kubectl get pvc -n monitoring

# Check if Fluent-bit can reach Elasticsearch
kubectl logs -n monitoring -l app=fluent-bit | grep -i "connection\|error\|retry"

# Force Flux to reconcile
flux reconcile helmrelease kube-prometheus-stack -n monitoring

# Check events for errors
kubectl get events -n monitoring --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n monitoring
```
