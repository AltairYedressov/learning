#!/bin/bash
set -e

echo "================================================"
echo " Tools Installation"
echo "================================================"

echo ">>> Installing eksctl..."
curl --silent --location \
  "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" \
  | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
echo ">>> eksctl installed ✅"

echo ">>> Installing kubectl..."
curl -LO "https://dl.k8s.io/release/v1.34.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin
echo ">>> kubectl installed ✅"

echo ">>> Installing Flux CLI..."
curl -s https://fluxcd.io/install.sh | sudo bash
echo ">>> Flux CLI installed ✅"

echo ">>> Verifying installations..."
eksctl version
kubectl version --client
flux version --client

echo "================================================"
echo " All tools installed ✅"
echo "================================================"