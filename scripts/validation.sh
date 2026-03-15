#!/bin/bash
set -e

echo "================================================"
echo " K8s Deployment Validation"
echo "================================================"

echo ""
echo ">>> Checking nodes..."
kubectl get nodes
kubectl wait --for=condition=Ready nodes \
  --all \
  --timeout=120s
echo ">>> Nodes Ready ✅"

echo ""
echo ">>> Checking for failed pods..."
FAILED=$(kubectl get pods -A \
  --field-selector=status.phase!=Running,status.phase!=Succeeded \
  --no-headers 2>/dev/null \
  | grep -v Completed \
  | grep -v Terminating \
  || true)

if [ -n "$FAILED" ]; then
  echo ">>> Failed pods found ❌"
  echo "$FAILED"
  exit 1
fi
echo ">>> No failed pods ✅"

echo ""
echo ">>> Checking Flux controllers..."
kubectl rollout status deployment \
  -n flux-system \
  --timeout=60s
flux get kustomizations
echo ">>> Flux healthy ✅"

echo ""
echo ">>> Checking Flux kustomizations..."
NOT_READY=$(flux get kustomizations --no-header \
  | grep -v "True" || true)

if [ -n "$NOT_READY" ]; then
  echo ">>> Some kustomizations not ready ❌"
  echo "$NOT_READY"
  exit 1
fi
echo ">>> All kustomizations ready ✅"

echo ""
echo ">>> Checking monitoring..."
kubectl rollout status deployment \
  kube-prometheus-stack-grafana \
  -n monitoring \
  --timeout=60s
kubectl rollout status statefulset \
  prometheus-kube-prometheus-stack-prometheus \
  -n monitoring \
  --timeout=60s
echo ">>> Monitoring healthy ✅"

echo ""
echo ">>> Checking Karpenter..."
if kubectl get deployment karpenter -n karpenter &>/dev/null; then
  kubectl rollout status deployment karpenter \
    -n karpenter \
    --timeout=60s

  kubectl get nodepools
  kubectl get ec2nodeclasses

  NODEPOOL_READY=$(kubectl get nodepool default \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' \
    2>/dev/null || echo "False")

  if [ "$NODEPOOL_READY" != "True" ]; then
    echo ">>> NodePool not ready ❌"
    exit 1
  fi
  echo ">>> Karpenter healthy ✅"
else
  echo ">>> Karpenter not installed, skipping..."
fi

echo ""
echo ">>> Checking EBS CSI..."
kubectl rollout status deployment \
  ebs-csi-controller \
  -n kube-system \
  --timeout=60s
echo ">>> EBS CSI healthy ✅"

echo ""
echo "================================================"
echo " All checks passed ✅"
echo "================================================"