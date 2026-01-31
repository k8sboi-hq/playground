#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "==> Installing ArgoCD..."

# Apply ArgoCD manifests using Kustomize
kubectl apply -k "$REPO_ROOT/manifests/platform/argocd"

echo "==> Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo "==> ArgoCD installed successfully!"
echo ""
echo "To get the initial admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
echo ""
echo "To access ArgoCD UI (port-forward):"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Then open: https://localhost:8080"
echo ""
echo "To login via CLI:"
echo "  argocd login localhost:8080 --username admin --password <password> --insecure"
