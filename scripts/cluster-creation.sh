#!/bin/bash
set -e

echo "================================================"
echo " Cluster creation"
echo "================================================"

echo " Creating temporary cluster"
eksctl create cluster \
  --name "$CLUSTER_NAME" \
  --region "us-east-1" \
  --nodegroup-name workers \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3 \
  --managed \
  --kubeconfig ~/.kube/config

echo ">>> Verifying cluster creation "
eksctl get cluster --name $CLUSTER_NAME --region us-east-1

echo ">>> Temporary cluster created created ✅"