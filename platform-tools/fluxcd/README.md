GitOps with Flux v2 — Setup Guide
This guide shows how to install Flux v2 (v2.8.1) into your Kubernetes cluster and configure it to sync your Git repository.
1️⃣ Prerequisites
Kubernetes cluster (EKS, k3s, GKE, etc.)
kubectl configured to access the cluster
flux CLI installed (Installation Guide)
GitHub repository for your manifests
2️⃣ Bootstrap Flux
Run the following command to install Flux controllers and configure your repo:
flux bootstrap github \
  --owner=AltairYedressov \
  --repo=learning \
  --branch=main \
  --path=./platform-tools \
  --personal
--path=./platform-tools → folder in your repo with Kustomizations
--personal → use your personal GitHub account
This creates:
gotk-components.yaml
gotk-sync.yaml
Flux system namespace and controllers
3️⃣ Explanation of YAMLs
1. gotk-components.yaml
Installs Flux controllers (engine) in the cluster:
Controller	Purpose
source-controller	Syncs Git/Helm sources
kustomize-controller	Applies Kustomizations
helm-controller	Applies Helm charts
notification-controller	Sends alerts for events
Lives in namespace: flux-system
2. gotk-sync.yaml
Tells Flux what repo and path to sync
Example snippet:
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  url: https://github.com/AltairYedressov/learning
  branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  path: ./platform-tools
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
GitRepository → points to your repo
Kustomization → tells Flux which folder to apply
3. kustomization.yaml
Defines actual Kubernetes manifests to apply
Typically inside ./platform-tools folder:
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
Flux reads this and applies the resources to the cluster
4️⃣ Verify Installation
# Check Flux controllers
kubectl get pods -n flux-system

# Check Kustomization status
flux get kustomizations -A

# Test DNS (optional, ensures networking is healthy)
kubectl run test-dns --rm -it --image=busybox --restart=Never -- nslookup source-controller.flux-system.svc.cluster.local
All pods should be Running, Kustomizations READY=True, and DNS resolving correctly.
5️⃣ Apply Changes Manually
If you ever want to force reconciliation:
flux reconcile kustomization flux-system -n flux-system
6️⃣ Diagram of Flux Flow
Git Repository
   │
   ▼
gotk-sync.yaml (GitRepository + Kustomization)
   │
   ▼
Flux Controllers (flux-system)
   ├─ source-controller
   ├─ kustomize-controller
   ├─ helm-controller
   └─ notification-controller
   │
   ▼
Cluster applies manifests
   └─ kustomization.yaml (namespace, deployments, services, etc.)
7️⃣ Notes
Make sure worker nodes SG allows self-referencing traffic:
Type: All traffic
Protocol: All
Source: worker-nodes SG itself
This ensures DNS, pod networking, and Flux controller communication work properly.
