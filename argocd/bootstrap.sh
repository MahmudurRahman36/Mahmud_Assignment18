#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — One-time ArgoCD setup on the Kubernetes master node
#
# Run this ONCE on the k8s master after the cluster is ready.
# After this, all deployments are managed via git + ArgoCD.
#
# Usage: bash argocd/bootstrap.sh
# =============================================================================

set -euo pipefail

echo "================================================"
echo " Support Chat — ArgoCD Bootstrap"
echo "================================================"

# Step 1: Create namespaces
echo "[1/5] Creating namespaces..."
kubectl apply -f argocd/namespace.yaml
kubectl apply -f k8s/dev/namespace.yaml
kubectl apply -f k8s/stage/namespace.yaml
kubectl apply -f k8s/prod/namespace.yaml

# Step 2: Install ArgoCD
echo "[2/5] Installing ArgoCD..."
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "      Waiting for ArgoCD server to be ready..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=180s

# Step 3: Expose ArgoCD UI as NodePort 30081
echo "[3/5] Exposing ArgoCD UI on NodePort 30081..."
kubectl patch svc argocd-server -n argocd \
  -p '{"spec":{"type":"NodePort","ports":[{"port":80,"targetPort":8080,"nodePort":30081}]}}'

# Step 4: Register ArgoCD Applications
echo "[4/5] Registering ArgoCD Applications..."
kubectl apply -f argocd/dev-application.yaml
kubectl apply -f argocd/stage-application.yaml
kubectl apply -f argocd/prod-application.yaml

# Step 5: Force immediate sync for prod (automated)
echo "[5/5] Triggering initial prod sync..."
kubectl annotate application chat-prod -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite

# Summary
MASTER_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null || echo "<MASTER_IP>")
ARGOCD_PASS=$(kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "<run: kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d>")

echo ""
echo "================================================"
echo " Bootstrap complete!"
echo ""
echo "  ArgoCD UI : http://${MASTER_IP}:30081"
echo "  Username  : admin"
echo "  Password  : ${ARGOCD_PASS}"
echo ""
echo "  Applications registered:"
echo "    chat-dev   (manual sync)   — watches k8s/dev on branch dev"
echo "    chat-stage (manual sync)   — watches k8s/stage on branch stage"
echo "    chat-prod  (auto sync)     — watches k8s/prod on branch prod"
echo ""
echo "  Get kubeconfig for GitHub Secrets:"
echo "    cat ~/.kube/config | base64 -w 0"
echo "================================================"
