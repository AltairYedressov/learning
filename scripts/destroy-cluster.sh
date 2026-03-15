#!/bin/bash
set -e

echo ">>> Destroying temporary cluster "

eksctl delete cluster \
  --name "$CLUSTER_NAME" \
  --region "us-east-1"
  --wait  

echo ">>> Temporary cluster destroyed ✅"