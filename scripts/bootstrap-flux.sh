#!/bin/bash
set -e

BRANCH=$1
CLUSTER_PATH=$2

if [ -z "$BRANCH" ] || [ -z "$CLUSTER_PATH" ]; then
  echo "ERROR: BRANCH and CLUSTER_PATH are required"
  echo "Usage: $0 <branch> <cluster-path>"
  exit 1
fi

# verify required env vars are set
if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_ORG" ] || [ -z "$GITHUB_REPO" ]; then
  echo "ERROR: GITHUB_TOKEN, GITHUB_ORG and GITHUB_REPO must be set"
  exit 1
fi

echo "================================================"
echo " Flux Bootstrap"
echo "================================================"

echo ">>> Bootstrapping Flux..."
echo "    Branch:  $BRANCH"
echo "    Path:    $CLUSTER_PATH"
echo "    Org:     $GITHUB_ORG"
echo "    Repo:    $GITHUB_REPO"

export GITHUB_TOKEN=$GITHUB_TOKEN    # ← flux reads this automatically

flux bootstrap github \
  --owner="$GITHUB_ORG" \
  --repository="$GITHUB_REPO" \
  --branch="$BRANCH" \
  --path="$CLUSTER_PATH" \
  --personal \
  --token-auth

echo ">>> Waiting for Flux pods to be ready..."
kubectl wait --for=condition=Ready pods \
  -n flux-system \
  --all \
  --timeout=120s

echo ">>> Reconciling source..."
flux reconcile source git flux-system

echo ">>> Reconciling kustomization..."
flux reconcile kustomization flux-system

echo ">>> Flux status..."
flux get sources git
flux get kustomizations

echo "================================================"
echo " Flux bootstrapped ✅"
echo "================================================"