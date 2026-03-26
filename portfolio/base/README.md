# Portfolio HelmRelease

This directory contains the Flux CD resources for deploying the portfolio application via GitOps.

## Files

| File | Purpose |
|------|---------|
| `helmrelease.yaml` | Flux CD HelmRelease — defines which chart to deploy and the values to pass |
| `helmrepository.yaml` | Flux CD HelmRepository — points to the OCI Helm chart in ECR |
| `namespace.yaml` | Creates the `portfolio` namespace |
| `kustomization.yaml` | Kustomize resource list that ties everything together |

## helmrelease.yaml — Line by Line

### Metadata

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
```
- Uses the Flux CD Helm controller API (v2) to manage Helm releases declaratively.

```yaml
metadata:
  name: portfolio
  namespace: portfolio
```
- The release is named `portfolio` and deployed into the `portfolio` namespace.

### Spec

```yaml
spec:
  interval: 10m
```
- Flux checks every 10 minutes for changes to the chart or values. If something changed, it reconciles (re-deploys).

### Chart Reference

```yaml
  chart:
    spec:
      chart: portfolio
      sourceRef:
        kind: HelmRepository
        name: ecr-charts
        namespace: flux-system
```
- Tells Flux which Helm chart to use (`portfolio`) and where to find it.
- `ecr-charts` is defined in `helmrepository.yaml` — it points to the OCI registry in ECR where the packaged chart is stored.
- The source lives in `flux-system` namespace because that's where Flux's source controller runs.

### Values

Everything under `values:` is passed directly to the Helm chart templates at `HelmCharts/portfolio/templates/`.

#### Namespace

```yaml
    namespace:
      name: portfolio
```
- Used in every template's `metadata.namespace` field via `{{ .Values.namespace.name }}`.

#### Replicas

```yaml
    replicas:
      api: 2
      frontend: 2
```
- Sets the number of pod replicas for each deployment.
- `api: 2` -> `{{ .Values.replicas.api }}` in `01-backend.yaml`
- `frontend: 2` -> `{{ .Values.replicas.frontend }}` in `02-frontend.yaml`

#### Images

```yaml
    images:
      api: 372517046622.dkr.ecr.us-east-1.amazonaws.com/images/portfolio-backend:latest
      frontend: 372517046622.dkr.ecr.us-east-1.amazonaws.com/images/portfolio-frontend:latest
```
- Full ECR image URIs for each container.
- Referenced as `{{ .Values.images.api }}` and `{{ .Values.images.frontend }}` in the templates.
- The CI/CD pipeline pushes images here; Flux picks up the chart that references them.

#### Ports

```yaml
    ports:
      api: 8000
      frontend: 3000
```
- Defines the container ports for each service.
- Used in `containerPort`, service `port`/`targetPort`, and health probe endpoints.
- Backend (FastAPI/Uvicorn) listens on 8000, frontend on 3000.

#### API URL

```yaml
    api:
      url: "http://portfolio-api.portfolio.svc.cluster.local:8000"
```
- The internal Kubernetes DNS address of the backend service.
- Injected into the frontend pod as the `API_URL` environment variable.
- Format: `http://<service-name>.<namespace>.svc.cluster.local:<port>`

#### Resources

```yaml
    resources:
      api:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 250m
          memory: 256Mi
      frontend:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 250m
          memory: 256Mi
```
- **requests** — the minimum CPU/memory Kubernetes guarantees to the pod. The scheduler uses these to place pods on nodes.
- **limits** — the maximum the pod can use. Exceeding memory limits causes an OOMKill; exceeding CPU causes throttling.
- `100m` CPU = 0.1 vCPU core. `128Mi` = 128 mebibytes of RAM.

## How It All Connects

```
Flux CD reconciliation loop (every 10m)
  |
  v
helmrepository.yaml        --> where is the chart? (ECR OCI registry)
  |
  v
helmrelease.yaml           --> which chart + what values?
  |
  v
HelmCharts/portfolio/      --> Chart.yaml + templates/
  |
  v
templates/01-backend.yaml  --> Backend Deployment + ClusterIP Service
templates/02-frontend.yaml --> Frontend Deployment + ClusterIP Service
```

## Customizing Per Environment

To override values per environment (dev/staging/prod), create overlay kustomizations that patch the HelmRelease values. For example:

```yaml
# portfolio/overlays/dev/kustomization.yaml
patches:
  - target:
      kind: HelmRelease
      name: portfolio
    patch: |
      - op: replace
        path: /spec/values/replicas/api
        value: 1
```
