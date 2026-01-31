# ArgoCD Playground

A GitOps playground for learning ArgoCD with multi-tenancy, HashiCorp Vault integration, and full CI/CD cycle.

## Architecture

```
root-app (bootstrap)
├── platform-apps
│   ├── vault
│   └── external-secrets-operator
├── team-alpha-apps
│   ├── api-service
│   └── web-frontend
└── team-beta-apps
    └── worker-service
```

## Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| `kubectl` | v1.28+ | Kubernetes CLI |
| `kustomize` | v5.0+ | Manifest management (bundled with kubectl) |
| `argocd` | v2.13+ | ArgoCD CLI (optional but recommended) |

### Kubernetes Cluster

You need a running Kubernetes cluster. Options:

```bash
# Option 1: k3d (recommended for local development)
k3d cluster create argocd-playground --agents 2

# Option 2: kind
kind create cluster --name argocd-playground

# Option 3: minikube
minikube start --cpus 4 --memory 8192

# Option 4: Use existing cluster
# Ensure kubectl context is set correctly
kubectl config current-context
```

### Verify Cluster Access

```bash
kubectl cluster-info
kubectl get nodes
```

## Quick Start

### 1. Install ArgoCD

```bash
# Run the installation script
./scripts/install-argocd.sh

# Or manually with kustomize
kubectl apply -k manifests/platform/argocd
```

### 2. Access ArgoCD UI

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo

# Port-forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open in browser: https://localhost:8080
# Username: admin
# Password: <from above command>
```

### 3. Install ArgoCD CLI (Optional)

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Login
argocd login localhost:8080 --username admin --password <password> --insecure
```

### 4. Configure Repository

Before deploying applications, update the repository URL in the Application manifests:

```bash
# Update YOUR_ORG with your GitHub organization/username
sed -i 's|YOUR_ORG|your-github-org|g' apps/*.yaml
```

### 5. Bootstrap App of Apps

```bash
# Apply the root application
kubectl apply -f apps/root-app.yaml

# ArgoCD will automatically sync all child applications
```

## Directory Structure

```
argocd-playground/
├── apps/                          # ArgoCD Application manifests
│   ├── root-app.yaml              # Bootstrap application
│   ├── platform-apps.yaml         # Platform services
│   ├── team-alpha-apps.yaml       # Team Alpha applications
│   ├── team-beta-apps.yaml        # Team Beta applications
│   └── projects/                  # AppProject definitions
├── manifests/                     # Kubernetes manifests
│   ├── platform/                  # Platform services
│   │   ├── argocd/               # ArgoCD installation
│   │   ├── vault/                # HashiCorp Vault
│   │   └── external-secrets/     # External Secrets Operator
│   ├── team-alpha/               # Team Alpha workloads
│   │   ├── api-service/
│   │   └── web-frontend/
│   └── team-beta/                # Team Beta workloads
│       └── worker-service/
├── src/                          # Application source code
│   ├── api-service/
│   └── web-frontend/
├── docs/                         # Documentation
├── exercises/                    # Hands-on break-fix scenarios
└── scripts/                      # Helper scripts
```

## Multi-Tenancy Model

| Team | Namespace | AppProject | Permissions |
|------|-----------|------------|-------------|
| Platform | `argocd`, `vault`, `external-secrets` | `platform` | Cluster-wide |
| Team Alpha | `team-alpha` | `team-alpha` | Namespace-scoped |
| Team Beta | `team-beta` | `team-beta` | Namespace-scoped |

## CI/CD Flow

```
Developer pushes code
        │
        ▼
GitHub Actions (CI)
├── Build container image
├── Run tests
├── Push to ghcr.io
└── Update image tag in manifests/
        │
        ▼
ArgoCD (CD)
├── Detect Git changes
├── Sync to cluster
└── Health checks
```

## Exercises

After setup, work through these hands-on scenarios:

1. **Drift Detection** - `exercises/01-drift-detection.md`
2. **Sync Failures** - `exercises/02-sync-failure.md`
3. **Rollback** - `exercises/03-rollback.md`
4. **Secret Rotation** - `exercises/04-secret-rotation.md`

## Troubleshooting

### ArgoCD not syncing

```bash
# Check application status
argocd app get root-app

# Force sync
argocd app sync root-app --prune

# Check logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Permission denied errors

```bash
# Verify AppProject allows the destination namespace
kubectl get appproject -n argocd team-alpha -o yaml
```

### Image pull errors

```bash
# Check if image exists
kubectl describe pod -n team-alpha <pod-name>

# Verify image pull secrets if using private registry
kubectl get secrets -n team-alpha
```

## Cleanup

```bash
# Delete all applications (cascading delete)
kubectl delete -f apps/root-app.yaml

# Delete ArgoCD
kubectl delete -k manifests/platform/argocd

# Delete namespaces
kubectl delete ns argocd team-alpha team-beta
```

## Next Steps

- [ ] Phase 2: Add Vault + External Secrets integration
- [ ] Phase 3: Deploy sample applications
- [ ] Phase 4: Set up CI pipelines
- [ ] Phase 5: Configure RBAC and AppProjects
- [ ] Phase 6: Complete break-fix exercises

## Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [External Secrets Operator](https://external-secrets.io/)
- [HashiCorp Vault](https://developer.hashicorp.com/vault/docs)
