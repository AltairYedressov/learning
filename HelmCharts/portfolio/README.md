# Portfolio Helm Chart

This Helm chart deploys the **portfolio** application, which consists of two components:

- **Backend (API)** — a REST API that serves data
- **Frontend** — a web app that users interact with in their browser

---

## Why Helm Templates?

In Kubernetes, you write YAML files to describe your application (Deployments, Services, etc.). The problem is that **values like image tags, ports, and replica counts change between environments** (dev, staging, production).

Instead of maintaining separate YAML files for each environment, Helm lets you write **one template** with **variables** (placeholders). You then supply different values per environment. Think of it like a form letter where you fill in the blanks differently each time.

For example, instead of hardcoding:

```yaml
replicas: 2
```

We write:

```yaml
replicas: {{ .Values.replicas.api }}
```

Now we can set `replicas.api: 2` for dev and `replicas.api: 5` for production — same template, different behavior.

---

## Why ClusterIP Instead of LoadBalancer?

You might expect the frontend Service to be `type: LoadBalancer` so users on the internet can reach it. We intentionally set **both** Services to `ClusterIP` (internal-only). Here's why:

### The Problem with LoadBalancer per Service

Every `type: LoadBalancer` Service creates **its own AWS load balancer**. If you have 5 services, that's 5 load balancers. Each one costs ~$16–22/month just for existing, plus data transfer fees. This gets expensive fast.

### The Solution: Istio + ALB

Instead, we use a **single ALB (Application Load Balancer)** in front of the **Istio Ingress Gateway**:

```
Internet → ALB → Istio Ingress Gateway → Frontend Service → Frontend Pods
                                        → Backend Service  → Backend Pods
```

- **ALB** handles TLS termination and is the single entry point from the internet
- **Istio** handles routing, traffic splitting, retries, and observability inside the cluster
- **Services stay ClusterIP** because they only need to be reachable inside the cluster — Istio routes traffic to them

This means you pay for **one load balancer** instead of one per service.

### ALB vs NLB — Which is Cheaper?

| | ALB | NLB |
|---|---|---|
| **Best for** | HTTP/HTTPS traffic (websites, APIs) | Raw TCP/UDP (databases, gaming, IoT) |
| **Base cost** | ~$0.0225/hr | ~$0.0225/hr |
| **Usage cost** | $0.008 per LCU | $0.006 per NLCU |
| **Smart routing** | Yes (path-based, host-based) | No (just forwards packets) |

For a web application like this, **ALB is the better choice** — it understands HTTP, can route by URL path, and the usage units (LCUs) are optimized for web request patterns.

---

## Template Breakdown

### Chart.yaml

The chart's identity file. Tells Helm the chart name and version. Think of it as the `package.json` of a Helm chart.

---

### 01-backend.yaml

This file creates **two** Kubernetes resources for the backend:

#### 1. Deployment (lines 1–44)

A Deployment tells Kubernetes: "I want X copies of this container running at all times."

| Line(s) | What it does | Variable used |
|---|---|---|
| `namespace` | Which Kubernetes namespace to deploy into. Namespaces are like folders — they keep resources organized | `{{ .Values.namespace.name }}` |
| `replicas` | How many copies (pods) of the backend to run. More replicas = more availability | `{{ .Values.replicas.api }}` |
| `image` | The Docker image to run (e.g., `123456.dkr.ecr.us-east-1.amazonaws.com/api:v1.2.3`) | `{{ .Values.images.api }}` |
| `containerPort` | The port the app listens on inside the container | `{{ .Values.ports.api }}` |
| `resources.requests` | The **minimum** CPU and memory Kubernetes guarantees to this pod. The scheduler uses this to decide which node to place the pod on | `{{ .Values.resources.api.requests.cpu }}` and `.memory` |
| `resources.limits` | The **maximum** CPU and memory the pod can use. If it exceeds memory limits, Kubernetes kills it (OOMKilled) | `{{ .Values.resources.api.limits.cpu }}` and `.memory` |

**Health Probes:**

- **livenessProbe** — Kubernetes pings `/api/health` every 15 seconds. If the app stops responding, Kubernetes restarts the pod. It waits 10 seconds after startup before checking (to give the app time to boot)
- **readinessProbe** — Same idea, but this controls whether the pod receives traffic. A pod that isn't "ready" is temporarily removed from the Service so users don't hit a broken instance

Both probes use `{{ .Values.ports.api }}` so they always match the container port.

#### 2. Service (lines 46–62)

A Service gives your pods a **stable internal address**. Pods come and go (they get replaced on updates, crashes, scaling), but the Service name `portfolio-api` always resolves to whatever pods are currently healthy.

| Field | Meaning |
|---|---|
| `type: ClusterIP` | Only reachable inside the cluster. The frontend talks to the backend through this |
| `selector: app: portfolio-api` | "Route traffic to pods that have the label `app: portfolio-api`" — this is how the Service finds its pods |
| `port` | The port the Service listens on |
| `targetPort` | The port on the pod to forward to (matches `containerPort`) |

---

### 02-frontend.yaml

Same structure as the backend, with a few differences:

#### 1. Deployment (lines 1–49)

Everything works the same as the backend Deployment, plus:

| Line(s) | What it does | Variable used |
|---|---|---|
| `env: API_URL` | Tells the frontend where to find the backend API. This is set at deploy time so it can differ per environment | `{{ .Values.api.url }}` |
| `env: PORT` | Tells the frontend which port to listen on. Uses `quote` because Kubernetes env values must be strings | `{{ .Values.ports.frontend \| quote }}` |

**What does `| quote` mean?**

In Helm, `|` is a pipe (like in a terminal). `quote` wraps the value in double quotes. Kubernetes environment variable values must be strings, but a number like `3000` would be rendered without quotes by default. So `{{ .Values.ports.frontend | quote }}` turns `3000` into `"3000"`.

#### 2. Service (lines 51–67)

Also `ClusterIP` — Istio's ingress gateway routes external traffic to this service internally. No need for a LoadBalancer here.

---

## Values You Need to Provide

When deploying this chart (via Flux HelmRelease or `helm install`), supply these values:

```yaml
namespace:
  name: portfolio

replicas:
  api: 2
  frontend: 2

images:
  api: <your-ecr-repo>/portfolio-api:latest
  frontend: <your-ecr-repo>/portfolio-frontend:latest

ports:
  api: 8000
  frontend: 3000

api:
  url: "http://portfolio-api:8000"

resources:
  api:
    requests:
      cpu: 100m        # 0.1 CPU core
      memory: 128Mi    # 128 megabytes
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

> **Tip:** `100m` means 100 "millicores" = 0.1 of a CPU core. `128Mi` means 128 mebibytes (~134 MB). These are Kubernetes resource units.

---

## SMTP Sealed Secret (portfolio-smtp)

The chart ships a `SealedSecret` at `templates/sealed-secret.yaml` that the in-cluster
[sealed-secrets](https://github.com/bitnami-labs/sealed-secrets) controller decrypts to
a Kubernetes `Secret` named `portfolio-smtp` in the `portfolio` namespace. Phase 3 of
the deployment will wire this Secret into the backend Deployment via
`envFrom.secretRef: { name: portfolio-smtp }`.

Only the cluster controller holds the private key — the ciphertext committed in Git is
safe to publish. **Plaintext credentials MUST NEVER be committed.**

### Prerequisites

- `kubeseal` CLI installed locally — https://github.com/bitnami-labs/sealed-secrets/releases
- `kubectl` context pointed at the `dev-projectx` cluster
- Gmail account with 2-factor authentication enabled

### 1. Generate a Gmail App Password

1. Visit https://myaccount.google.com/apppasswords
2. App name: `portfolio-dev` (or similar descriptive label)
3. Copy the 16-character password. Treat it as a secret — it grants SMTP send access.

### 2. Fetch the sealed-secrets controller public cert

```bash
kubeseal --controller-namespace sealed-secrets \
         --controller-name sealed-secrets \
         --fetch-cert > /tmp/sealed-secrets-pub.pem
```

### 3. Create the plaintext Secret LOCALLY (never commit)

```bash
cat > /tmp/smtp-secret.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: portfolio-smtp
  namespace: portfolio
type: Opaque
stringData:
  SMTP_USER: "contact@yedressov.com"
  SMTP_PASS: "<paste 16-char app password>"
  RECIPIENT_EMAIL: "contact@yedressov.com"
EOF
```

### 4. Seal it

```bash
kubeseal --cert /tmp/sealed-secrets-pub.pem \
         --format yaml \
         < /tmp/smtp-secret.yaml \
         > HelmCharts/portfolio/templates/sealed-secret.yaml
```

This replaces the committed placeholder (`__REPLACE_VIA_KUBESEAL__`) with the real
ciphertext. Each value becomes a long base64 string (~350+ chars).

### 5. Verify no plaintext remains and shred scratch files

```bash
shred -u /tmp/smtp-secret.yaml /tmp/sealed-secrets-pub.pem
# placeholder gone:
! grep -q '__REPLACE_VIA_KUBESEAL__' HelmCharts/portfolio/templates/sealed-secret.yaml
# ciphertext present (base64 blobs >=100 chars):
grep -E 'SMTP_PASS:.*[A-Za-z0-9+/=]{100,}' HelmCharts/portfolio/templates/sealed-secret.yaml
```

### 6. Commit + push

Flux reconciles → controller decrypts → `Secret/portfolio-smtp` appears in the
`portfolio` namespace:

```bash
kubectl -n portfolio get secret portfolio-smtp
```

### Rotation (SMS-03)

To rotate the Gmail app password:

1. Revoke the old app password in the Google UI.
2. Generate a new one (step 1 above).
3. Repeat steps 2–6. The controller re-decrypts on reconcile. In Phase 3 the backend
   Deployment will pick up the new env values on its next rollout (roll pods manually
   with `kubectl -n portfolio rollout restart deploy/portfolio-api` if needed).

### Controller sealing-key rotation

The sealed-secrets controller rotates its sealing key every 30 days by default. Old
SealedSecrets remain decryptable for the retention window, but **new** SealedSecrets
should be sealed against the current public cert: re-run steps 2 and 4 whenever you
create a new SealedSecret or rotate credentials.

See [`platform-tools/sealed-secrets/README.md`](../../platform-tools/sealed-secrets/README.md)
for controller-level details.

