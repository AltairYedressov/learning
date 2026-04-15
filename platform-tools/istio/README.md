# Istio Service Mesh + AWS Load Balancer Controller Setup

Complete guide to setting up Istio service mesh with AWS NLB on EKS, managed via Flux CD GitOps.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Traffic Flow](#traffic-flow)
3. [Component Breakdown](#component-breakdown)
   - [Istio System (CRDs + Control Plane)](#1-istio-system-crds--control-plane)
   - [Istio Ingress Gateway](#2-istio-ingress-gateway)
   - [AWS Load Balancer Controller](#3-aws-load-balancer-controller)
   - [Gateway Resource](#4-gateway-resource)
   - [VirtualService](#5-virtualservice)
   - [DNS (Route53)](#6-dns-route53)
   - [IAM (IRSA)](#7-iam-irsa)
4. [HelmRelease Explained Line by Line](#helmrelease-explained-line-by-line)
5. [How Everything Connects](#how-everything-connects)
6. [Deployment Order and Dependencies](#deployment-order-and-dependencies)
7. [Issues We Encountered and How We Solved Them](#issues-we-encountered-and-how-we-solved-them)
8. [Directory Structure](#directory-structure)

---

## Architecture Overview

```
User (browser)
    │
    ▼
Route53 (yedressov.com → NLB)
    │
    ▼
AWS NLB (TLS termination via ACM cert)
    │
    ├── Port 80  → targetPort 8080 (Envoy: HTTP→HTTPS redirect)
    └── Port 443 → targetPort 8443 (Envoy: serves traffic)
            │
            ▼
    Istio Gateway (main-gateway)
            │
            ▼
    VirtualService (routing rules)
            │
            ├── /api/* → portfolio-api:8000
            └── /*     → portfolio-frontend:3000
```

## Traffic Flow

1. **User** types `http://yedressov.com` or `https://yedressov.com` in the browser
2. **Route53** resolves the domain to the NLB's IP address via an A/ALIAS record
3. **NLB** receives the request:
   - Port 80 (HTTP): forwards as plain TCP to Envoy on port 8080
   - Port 443 (HTTPS): terminates TLS using the ACM certificate, then forwards decrypted traffic to Envoy on port 8443
4. **Istio Gateway** (Envoy proxy):
   - Port 8080: returns a 301 redirect to `https://`
   - Port 8443: accepts the request and passes it to the VirtualService
5. **VirtualService** matches the request:
   - If path starts with `/api` → routes to `portfolio-api` service on port 8000
   - Everything else → routes to `portfolio-frontend` service on port 3000
6. **Istio sidecar** (injected into the pod) handles mTLS between pods automatically

---

## Component Breakdown

### 1. Istio System (CRDs + Control Plane)

**Location:** `platform-tools/istio/istio-system/`

This deploys two HelmReleases in a single file:

#### istio-base (CRDs)

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: istio-base
  namespace: istio-system
spec:
  chart:
    spec:
      chart: base                    # Istio "base" chart — installs only CRDs
```

- Installs Custom Resource Definitions (Gateway, VirtualService, DestinationRule, etc.)
- Must be installed FIRST before anything else Istio-related
- `install.crds: Create` — creates CRDs on first install
- `upgrade.crds: CreateReplace` — updates CRDs on upgrades

#### istiod (Control Plane)

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: istiod
  namespace: istio-system
spec:
  dependsOn:
    - name: istio-base              # Waits for CRDs to be ready
  chart:
    spec:
      chart: istiod                  # Istio control plane (Pilot)
```

Key values explained:

| Value | Purpose |
|-------|---------|
| `pilot.autoscaleEnabled: false` | Disables HPA — uses fixed replica count instead |
| `pilot.replicaCount: 2` | Runs 2 istiod pods for high availability |
| `meshConfig.accessLogFile: /dev/stdout` | Envoy access logs go to stdout (collected by logging stack) |
| `meshConfig.enableAutoMtls: true` | Automatically encrypts pod-to-pod traffic with mutual TLS |
| `meshConfig.defaultConfig.holdApplicationUntilProxyStarts: true` | Prevents app containers from starting before the Envoy sidecar is ready — avoids race conditions |
| `global.proxy.resources` | Default CPU/memory for all Envoy sidecar containers injected into pods |
| `global.proxy.logLevel: warning` | Sidecar log verbosity (debug in dev, warning in prod) |

**Dev overlay** reduces resources (1 replica, debug logging).
**Prod overlay** keeps full resources (2 replicas, warning logging).

---

### 2. Istio Ingress Gateway

**Location:** `platform-tools/istio/istio-ingress/`

Deploys the Envoy-based ingress gateway that sits at the edge of the mesh.

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: istio-ingress
  namespace: istio-ingress
spec:
  dependsOn:
    - name: istiod
      namespace: istio-system       # Must wait for istiod to be running
  chart:
    spec:
      chart: gateway                 # Istio "gateway" chart — deploys Envoy pods
```

Key values explained:

| Value | Purpose |
|-------|---------|
| `service.type: LoadBalancer` | Creates a Kubernetes LoadBalancer Service → triggers the AWS LB Controller to provision an NLB |
| `aws-load-balancer-type: external` | Uses the AWS Load Balancer Controller (not the in-tree cloud provider) |
| `aws-load-balancer-nlb-target-type: ip` | Routes directly to pod IPs (not node ports) — more efficient |
| `aws-load-balancer-scheme: internet-facing` | Makes the NLB publicly accessible from the internet |
| `aws-load-balancer-ssl-cert` | ARN of the ACM certificate for TLS termination at the NLB |
| `aws-load-balancer-ssl-ports: "443"` | Only port 443 gets TLS termination; port 80 passes through as plain TCP |
| `aws-load-balancer-backend-protocol: tcp` | NLB forwards decrypted traffic as TCP to the target pods |
| Port 80 → targetPort 8080 | HTTP traffic goes to Envoy port 8080 (redirect server) |
| Port 443 → targetPort 8443 | HTTPS traffic (decrypted by NLB) goes to Envoy port 8443 (app server) |
| `podDisruptionBudget.minAvailable: 1` | Always keep at least 1 pod running during rolling updates |
| `affinity.podAntiAffinity` | Spread gateway pods across availability zones for HA |

---

### 3. AWS Load Balancer Controller

**Location:** `platform-tools/aws-lb-controller/`

This controller watches for Kubernetes Services of type `LoadBalancer` with AWS annotations and provisions actual AWS NLBs/ALBs.

**Without this controller, the `EXTERNAL-IP` stays `<pending>` forever.**

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
```

Key values explained:

| Value | Purpose |
|-------|---------|
| `clusterName: projectx` | Tells the controller which EKS cluster it manages |
| `region: us-east-1` | AWS region for API calls |
| `vpcId` | VPC where the NLB and target groups are created |
| `serviceAccount.annotations.eks.amazonaws.com/role-arn` | IRSA — links the K8s service account to an IAM role so the controller can make AWS API calls |

---

### 4. Gateway Resource

**Location:** `platform-tools/istio/istio-ingress/base/gateway.yaml`

The Gateway CRD tells Envoy which ports to listen on and which hosts to accept.

```yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: main-gateway
  namespace: istio-ingress
spec:
  selector:
    istio: ingress              # Selects pods with this label (the ingress gateway pods)
  servers:
    - port:
        number: 8080            # Envoy listens on 8080
        name: http
        protocol: HTTP
      tls:
        httpsRedirect: true     # Returns 301 redirect to https://
      hosts:
        - "*.yedressov.com"
        - "yedressov.com"
    - port:
        number: 8443            # Envoy listens on 8443
        name: https
        protocol: HTTP          # HTTP (not HTTPS) because NLB already decrypted TLS
      hosts:
        - "*.yedressov.com"
        - "yedressov.com"
```

- Port 8443 uses `protocol: HTTP` (not HTTPS) because the NLB already terminated TLS — traffic arrives decrypted
- Port 8080 exists only to redirect HTTP → HTTPS
- The `selector: istio: ingress` binds this Gateway to the ingress gateway pods deployed by the Helm chart
- Envoy dynamically binds to these ports based on the Gateway CRD — they don't need to be defined in the pod spec

---

### 5. VirtualService

**Location:** `portfolio/base/virtualservice.yaml`

Routes traffic from the Gateway to the actual application services.

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: portfolio
  namespace: portfolio
spec:
  hosts:
    - "yedressov.com"           # Match requests for this hostname
  gateways:
    - istio-ingress/main-gateway # Use the shared gateway (namespace/name)
  http:
    - match:
        - uri:
            prefix: /api        # Requests starting with /api
      route:
        - destination:
            host: portfolio-api  # K8s Service name (resolved within the namespace)
            port:
              number: 8000
    - route:                     # Default route (everything else)
        - destination:
            host: portfolio-frontend
            port:
              number: 3000
```

- `gateways: istio-ingress/main-gateway` — references the Gateway by namespace/name
- `host: portfolio-api` — short name resolved to `portfolio-api.portfolio.svc.cluster.local`
- Route order matters: more specific matches (`/api`) must come before the default catch-all

---

### 6. DNS (Route53)

**Location:** `terraform-infra/root/dev/dns/main.tf`

```hcl
resource "aws_route53_record" "istio_ingress" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.domain_name         # "yedressov.com"
  type    = "A"

  alias {
    name                   = var.istio_ingress_lb_hostname   # NLB hostname from kubectl get svc
    zone_id                = "Z26RNL4JYFTOTI"                # Fixed AWS hosted zone ID for NLBs in us-east-1
    evaluate_target_health = true
  }
}
```

- Uses an A/ALIAS record (not CNAME) — required for zone apex (`yedressov.com` without subdomain)
- The NLB hostname is passed as a variable from the GitHub Actions workflow
- `Z26RNL4JYFTOTI` is the AWS-owned hosted zone ID for NLBs in us-east-1 (every region has its own)

---

### 7. IAM (IRSA)

**Location:** `terraform-infra/root/dev/iam-roles/main.tf`

The AWS Load Balancer Controller needs AWS API permissions to create NLBs, target groups, security groups, etc.

```hcl
module "aws_lb_controller_irsa_role" {
  source             = "../../../iam-role-module"
  role_name          = "aws-lb-controller-role"
  assume_role_action = "sts:AssumeRoleWithWebIdentity"     # IRSA uses OIDC web identity
  principal_type     = "Federated"                          # Federated via EKS OIDC provider

  assume_role_conditions = {
    sub = {
      test     = "StringEquals"
      variable = "...:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]  # Only this SA can assume the role
    }
    aud = {
      test     = "StringEquals"
      variable = "...:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
  custom_policy_json_path = ".../Policies/aws_lb_controller_policy.json"
}
```

**How IRSA works:**
1. EKS has an OIDC identity provider
2. The IAM role trusts tokens from this provider
3. The `sub` condition restricts to only the `aws-load-balancer-controller` service account in `kube-system`
4. When the controller pod starts, it gets a projected token that it exchanges for temporary AWS credentials
5. No long-lived access keys needed

---

## HelmRelease Explained Line by Line

Using `istio-ingress` as the example:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2    # Flux HelmRelease API version
kind: HelmRelease
metadata:
  name: istio-ingress                     # Name of the release (used by Flux tracking)
  namespace: istio-ingress                # Namespace where the Helm release is installed
spec:
  interval: 1h                            # How often Flux checks for drift and reconciles
  timeout: 5m                             # Max time for install/upgrade before marking as failed

  dependsOn:
    - name: istiod                        # Won't install until this HelmRelease is Ready
      namespace: istio-system             # Cross-namespace dependency

  chart:
    spec:
      chart: gateway                      # Chart name in the HelmRepository
      version: ">=1.24.0 <2.0.0"         # Semver constraint — auto-upgrades within range
      sourceRef:
        kind: HelmRepository              # Where to pull the chart from
        name: istio-release               # References the HelmRepository resource
        namespace: flux-system            # HelmRepos live in flux-system
      interval: 24h                       # How often to check for new chart versions

  install:
    remediation:
      retries: 3                          # Retry up to 3 times if install fails

  upgrade:
    cleanupOnFail: true                   # Delete new resources if upgrade fails
    remediation:
      retries: 3
      strategy: rollback                  # On failure, roll back to previous release

  rollback:
    cleanupOnFail: true                   # Clean up if rollback itself fails
    recreate: false                       # Don't delete+recreate pods during rollback
    timeout: 5m

  values:                                 # Helm values — equivalent to values.yaml
    replicaCount: 2                       # Number of Envoy gateway pods
    service:
      type: LoadBalancer                  # Creates a K8s LoadBalancer Service → triggers NLB creation
      annotations:                        # AWS-specific annotations read by the LB controller
        ...
```

**How Flux uses this:**
1. Flux watches the GitRepository for changes
2. When it detects a change to the HelmRelease, it runs `helm upgrade --install`
3. If the values change, Flux re-renders the templates and applies the diff
4. If someone manually changes the cluster state (e.g., `kubectl edit`), Flux reverts it on the next reconciliation cycle (every `interval`)

---

## How Everything Connects

```
┌─────────────────────────────────────────────────────────────────┐
│  Git Repository (flux-system)                                    │
│                                                                  │
│  clusters/dev-projectx/                                          │
│  ├── aws-lb-controller.yaml ──→ platform-tools/aws-lb-controller │
│  └── istio.yaml                                                  │
│      ├── istio-system ──────→ platform-tools/istio/istio-system  │
│      └── istio-ingress ─────→ platform-tools/istio/istio-ingress │
│                                                                  │
│  Dependency chain:                                               │
│  aws-lb-controller (no deps)                                     │
│  istio-system (no deps)                                          │
│  istio-ingress (depends on: istio-system + aws-lb-controller)    │
└─────────────────────────────────────────────────────────────────┘
          │
          ▼ Flux reconciles
┌─────────────────────────────────────────────────────────────────┐
│  Kubernetes Cluster                                              │
│                                                                  │
│  kube-system namespace:                                          │
│  └── aws-load-balancer-controller (Deployment)                   │
│      └── Watches for LoadBalancer Services with AWS annotations  │
│                                                                  │
│  istio-system namespace:                                         │
│  ├── istio-base (CRDs: Gateway, VirtualService, etc.)           │
│  └── istiod (control plane — configures all Envoy proxies)      │
│                                                                  │
│  istio-ingress namespace:                                        │
│  ├── istio-ingress (Deployment — Envoy pods)                    │
│  ├── istio-ingress (Service type: LoadBalancer)                  │
│  │   └── AWS LB Controller sees this → creates NLB              │
│  └── main-gateway (Gateway CRD)                                 │
│      └── istiod reads this → configures Envoy to listen on      │
│          ports 8080 and 8443                                     │
│                                                                  │
│  portfolio namespace (istio-injection: enabled):                 │
│  ├── portfolio-frontend (Deployment + Service + sidecar)        │
│  ├── portfolio-api (Deployment + Service + sidecar)             │
│  └── portfolio (VirtualService)                                 │
│      └── istiod reads this → configures Envoy routing           │
└─────────────────────────────────────────────────────────────────┘
          │
          ▼ AWS resources
┌─────────────────────────────────────────────────────────────────┐
│  AWS                                                             │
│  ├── NLB (k8s-istioing-istioing-*.elb.us-east-1.amazonaws.com) │
│  │   ├── Listener :80  → Target Group → Envoy pods :8080       │
│  │   └── Listener :443 (TLS/ACM cert) → Target Group → :8443   │
│  ├── ACM Certificate (*.yedressov.com)                          │
│  ├── Route53 A record (yedressov.com → NLB alias)              │
│  └── IAM Role (aws-lb-controller-role) via IRSA                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Deployment Order and Dependencies

Flux resolves this automatically via `dependsOn`:

```
Step 1 (parallel):
  ├── aws-lb-controller   (no dependencies)
  └── istio-system         (no dependencies)
       ├── istio-base      (CRDs)
       └── istiod          (depends on istio-base, within the HelmRelease)

Step 2 (after Step 1 completes):
  └── istio-ingress        (depends on istio-system + aws-lb-controller)
       ├── Envoy pods start
       ├── LoadBalancer Service created
       └── AWS LB Controller provisions NLB

Step 3 (independent, can happen anytime after istio-system):
  └── portfolio            (application)
       ├── VirtualService created
       └── Pods get Istio sidecar (namespace has istio-injection: enabled)
```

---

## Issues We Encountered and How We Solved Them

### Issue 1: VirtualService CRD Not Found

```
dry-run failed: no matches for kind "VirtualService" in version "networking.istio.io/v1"
```

**Cause:** The portfolio VirtualService was being applied before `istio-base` installed the CRDs.

**Fix:** Ensure `istio-system` (which includes `istio-base`) is deployed before any resources that use Istio CRDs. The Flux Kustomization dependency chain handles this.

---

### Issue 2: istio-ingress Stuck Waiting on Karpenter

```
dependency 'flux-system/karpenter' revision is not up to date
```

**Cause:** In `clusters/dev-projectx/istio.yaml`, the `istio-ingress` Kustomization had `dependsOn: karpenter` instead of `dependsOn: istio-system`.

**Fix:** Changed the dependency:
```yaml
# Before (wrong)
dependsOn:
  - name: karpenter

# After (correct)
dependsOn:
  - name: istio-system
  - name: aws-lb-controller
```

---

### Issue 3: NLB EXTERNAL-IP Stuck at `<pending>`

```
NAME            TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)
istio-ingress   LoadBalancer   172.20.161.7   <pending>     80:31945/TCP,443:31487/TCP
```

**Cause:** The AWS Load Balancer Controller was not installed. Without it, Kubernetes has no way to provision an AWS NLB from the service annotations.

**Fix:** Created the entire `aws-lb-controller` platform tool:
- IAM policy with required EC2 and ELB permissions
- IRSA role linked to the controller's service account
- HelmRelease deploying the controller into `kube-system`
- Added `aws-lb-controller` as a dependency of `istio-ingress`

---

### Issue 4: IAM Missing `ec2:DescribeRouteTables`

```
ec2:DescribeRouteTables: UnauthorizedOperation
```

**Cause:** The initial IAM policy didn't include `ec2:DescribeRouteTables`, which the controller needs to determine subnet reachability (public vs private subnets).

**Fix:** Added `ec2:DescribeRouteTables` to the policy JSON, ran `terraform apply`, restarted the controller.

---

### Issue 5: IAM Missing `elasticloadbalancing:DescribeListenerAttributes`

```
elasticloadbalancing:DescribeListenerAttributes: AccessDenied
```

**Cause:** The newer version of the AWS LB Controller (v1.17.x) uses `DescribeListenerAttributes` which wasn't in the original policy.

**Fix:** Added `elasticloadbalancing:DescribeListenerAttributes` to the policy JSON, ran `terraform apply`, restarted the controller.

**Lesson:** AWS LB Controller versions add new API calls. Always check the controller logs after deployment for permission errors.

---

### Issue 6: NLB Created as Internal (Not Publicly Accessible)

```json
"scheme": "internal"
```

**Cause:** The dev overlay had `aws-load-balancer-scheme: internal`, making the NLB only reachable from within the VPC.

**Fix:** Changed dev overlay to `internet-facing`:
```yaml
service:
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
```

---

### Issue 7: DNS Not Resolving (`DNS_PROBE_FINISHED_NXDOMAIN`)

**Cause:** No Route53 DNS record pointing `yedressov.com` to the NLB.

**Fix:** Created a Terraform `aws_route53_record` with an A/ALIAS record pointing to the NLB hostname. The NLB hostname was passed as a Terraform variable in the GitHub Actions workflow.

---

### Issue 8: Route53 Record Creation Failed (Unsupported Characters)

```
InvalidChangeBatch: UnsupportedCharacter (Value contains unsupported characters) encountered with ' '
```

**Cause:** The GitHub Actions variable `ISTIO_INGRESS_LB_HOSTNAME` had a space in the middle: `us-east -1` instead of `us-east-1`.

**Fix:** Corrected the variable value in GitHub Settings → Variables to remove the space.

---

### Issue 9: ERR_TOO_MANY_REDIRECTS (First Attempt)

**Cause:** We tried using `X-Forwarded-Proto` header to detect HTTP vs HTTPS in the VirtualService. But NLBs operate at Layer 4 (TCP) and do NOT set HTTP headers like `X-Forwarded-Proto` — only ALBs (Layer 7) do that.

Since both port 80 and 443 traffic arrived as identical plain HTTP on the same target port (8080), the gateway couldn't distinguish them, causing infinite redirects.

**Fix:** Used two different target ports:
- NLB port 80 → Envoy port 8080 (configured with `httpsRedirect: true`)
- NLB port 443 → Envoy port 8443 (serves application traffic)

The Gateway resource defines both ports, and Envoy dynamically binds to them.

---

### Issue 10: ERR_TOO_MANY_REDIRECTS (Second Attempt)

**Cause:** Even with two target ports, the redirect loop persisted. The issue was that Envoy needed to dynamically bind to the ports defined in the Gateway CRD, but the configuration wasn't being picked up correctly on the first reconciliation.

**Fix:** After Flux fully reconciled the updated Gateway and HelmRelease with the two-port configuration, clearing the browser cache resolved the issue. The browser had cached the redirect responses from previous attempts.

---

## Directory Structure

```
platform-tools/
├── aws-lb-controller/
│   ├── base/
│   │   ├── helmrelease.yaml        # AWS LB Controller deployment
│   │   ├── helmrepository.yaml     # eks-charts repo
│   │   └── kustomization.yaml
│   └── overlays/
│       ├── dev/
│       │   ├── kustomization.yaml
│       │   └── patch.yaml          # 1 replica, lower resources
│       └── prod/
│           ├── kustomization.yaml
│           └── patch.yaml          # 2 replicas, higher resources
│
├── istio/
│   ├── istio-system/
│   │   ├── base/
│   │   │   ├── helmrelease.yaml    # istio-base (CRDs) + istiod (control plane)
│   │   │   ├── helmrepository.yaml # istio-release repo
│   │   │   ├── namespace.yaml      # istio-system namespace
│   │   │   └── kustomization.yaml
│   │   └── overlays/
│   │       ├── dev/
│   │       │   └── patch.yaml      # 1 replica, debug logging
│   │       └── prod/
│   │           └── patch.yaml      # 2 replicas, warning logging
│   │
│   └── istio-ingress/
│       ├── base/
│       │   ├── helmrelease.yaml    # Envoy gateway pods + NLB Service
│       │   ├── helmrepository.yaml # istio-release repo
│       │   ├── gateway.yaml        # Gateway CRD (port 8080 redirect + port 8443 serve)
│       │   ├── namespace.yaml      # istio-ingress namespace
│       │   └── kustomization.yaml
│       └── overlays/
│           ├── dev/
│           │   └── patch.yaml      # ACM cert ARN, 1 replica
│           └── prod/
│               └── patch.yaml      # ACM cert ARN, 2 replicas

clusters/dev-projectx/
├── aws-lb-controller.yaml          # Flux Kustomization → aws-lb-controller overlay
└── istio.yaml                      # Flux Kustomization → istio-system + istio-ingress overlays

portfolio/base/
├── virtualservice.yaml             # Routes yedressov.com traffic to app services
└── namespace.yaml                  # Has istio-injection: enabled label

terraform-infra/
├── iam-role-module/
│   └── Policies/
│       └── aws_lb_controller_policy.json  # IAM policy for LB controller
├── root/dev/
│   ├── iam-roles/main.tf          # IRSA role for LB controller
│   └── dns/main.tf                # Route53 A record → NLB
```

---

## Key Concepts

### Why NLB instead of ALB?
- NLB operates at Layer 4 (TCP) — doesn't conflict with Istio's Layer 7 routing
- ALB would duplicate routing logic (ALB routes + Istio VirtualService routes)
- NLB is generally cheaper and has lower latency

### Why TLS termination at NLB?
- ACM certificates are free and auto-renew
- No need to manage TLS secrets inside the cluster
- Istio mTLS (`enableAutoMtls: true`) encrypts pod-to-pod traffic separately

### Why two target ports (8080/8443)?
- NLB is Layer 4 — it doesn't add HTTP headers like `X-Forwarded-Proto`
- The only way to distinguish HTTP from HTTPS traffic is by using different target ports
- Port 8080 handles HTTP→HTTPS redirects, port 8443 serves the actual application

### What is IRSA?
- IAM Roles for Service Accounts — maps a K8s ServiceAccount to an IAM Role
- Uses the EKS OIDC provider for authentication
- No long-lived credentials — pods get short-lived tokens automatically
- Scoped to a specific service account in a specific namespace

### What does `istio-injection: enabled` do?
- When this label is on a namespace, Istio's admission webhook automatically injects an Envoy sidecar container into every pod created in that namespace
- The sidecar intercepts all inbound/outbound traffic for the pod
- This enables mTLS, traffic routing, observability, and policy enforcement
