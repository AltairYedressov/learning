Step 1 — Install Flux CLI
Mac:
brew install fluxcd/tap/flux
Linux:
curl -s https://fluxcd.io/install.sh | sudo bash
Verify:

Step 2 — Check Cluster Access
Make sure you can talk to cluster:
kubectl get nodes
If this works → good