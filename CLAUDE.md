# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **monorepo playground** for learning and experimenting with infrastructure, security, and networking concepts. Each subdirectory is an independent project/playground focused on a specific technology or concept.

**Current Branch Context**: `playground-libvirt-terraform` is for experimenting with Infrastructure as Code (IaC) using Terraform and the libvirt provider ([dmacvicar/libvirt](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs)) to provision virtual machines.

## Repository Structure

The repository contains multiple independent playground projects:

- **ca-server/** - Certificate Authority HTTP server built with Go and Gin framework for TLS/mTLS experimentation
- **rpc-playground/** - Go RPC implementation examples
- **image-policy-webhook/** - Kubernetes ImagePolicyWebhook admission controller implementation
- **terraform-vault-pki/** - Terraform configuration for HashiCorp Vault PKI secrets engine
- **openbao/** - OpenBao (Vault fork) experimentation
- **tls-playground/** - TLS and mTLS examples in Go
- **libvirt-terraform/** - Provisioning VMs using Terraform with the libvirt provider with Fedora42

Each project has its own README with specific setup instructions.

## Common Commands

### Go Projects (ca-server, rpc-playground, tls-playground, image-policy-webhook)

```bash
# Install dependencies
go mod tidy

# Run the application
go run main.go

# Run tests
go test ./...

# Run specific test
go test -run TestName ./path/to/package

# Build binary
go build -o app main.go
```

### Terraform Projects (terraform-vault-pki, libvirt-terraform)

```bash
# Install Terraform (script available in some branches)
./install-terraform.sh

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format Terraform files
terraform fmt

# Plan changes
terraform plan

# Apply configuration
terraform apply

# Destroy resources
terraform destroy

# Show current state
terraform show
```

### Kubernetes Projects (image-policy-webhook)

```bash
# Build Docker image
docker build -t image-policy-webhook:latest .

# Run integration tests
go test -tags=integration ./...

# Apply Kubernetes manifests
kubectl apply -f deployment/
```

## Git Workflow

This repository follows **Conventional Commits** format (see global CLAUDE.md). Each playground typically lives in its own feature branch:

- Feature branches: `feature-<project-name>` (e.g., `feature-image-policy-webhook`, `feature-terraform-vault-pki-playground`)
- Main branch: `main` (contains stable/merged playgrounds)

## Project-Specific Notes

### CA Server

- Uses Gin framework for HTTP server
- Implements custom PKI (Public Key Infrastructure)
- Supports both TLS and mTLS
- Has Taskfile.yml for task automation (use `task` command)
- Certificate management endpoints for CA, server, and client certificates

### RPC Playground

- Demonstrates Go's built-in RPC capabilities
- Client/server architecture in separate directories
- Start server first, then run client

### Image Policy Webhook

- Kubernetes admission controller
- Requires understanding of Kubernetes admission webhooks
- Uses Docker for containerization
- Integration tests included

### Terraform Vault PKI

- Demonstrates PKI management with HashiCorp Vault via Terraform
- Requires running Vault server (dev mode acceptable for testing)
- Uses `terraform.tfvars` for configuration (copy from `terraform.tfvars.example`)
- **Important**: Never commit `terraform.tfvars` (contains sensitive tokens)

## Development Workflow

1. Each playground is self-contained - navigate to the specific directory
2. Read the project-specific README.md first
3. Install prerequisites listed in README
4. Follow project-specific setup instructions
5. Experiment and learn!

## CI/CD

The repository uses GitHub Actions with Claude Code integration (`.github/workflows/claude.yaml`):

- Triggered by `@claude` mentions in PR comments, issues, and reviews
- Requires `CLAUDE_CODE_OAUTH_TOKEN` secret
- Automated code review and assistance

## Architecture Patterns

### Go Projects

- **MVC-like structure**: controllers/, models/, routes/, middleware/
- **Configuration management**: config/ directory for app configuration
- **Modular design**: internal/ for private packages, pkg/ for public APIs (where applicable)
- **Standard Go project layout**: cmd/ for binaries, pkg/ for libraries

### Terraform Projects

- **Standard module structure**:
  - `main.tf` - Primary resources and provider configuration
  - `variables.tf` - Input variables (implicit in some projects)
  - `outputs.tf` - Output values
  - `terraform.tfvars.example` - Example configuration (copy to terraform.tfvars)
- **State management**: Local state for playgrounds (no remote backend)
- **Provider version pinning**: Uses `~>` constraints

## Security Notes

- **Certificates and Keys**: Never commit private keys or sensitive certificates
- **Tokens**: Use `.gitignore` to exclude `terraform.tfvars`, `.env`, and credential files
- **TLS/mTLS**: Projects demonstrate proper certificate chain validation
- **Kubernetes Security**: ImagePolicyWebhook demonstrates admission control patterns

## Libvirt Terraform (Current Branch)

This branch is for provisioning VMs using Terraform with the libvirt provider. Expected workflow:

```bash
# Install dependencies
terraform init

# Plan VM provisioning
terraform plan

# Create VMs
terraform apply

# Destroy VMs
terraform destroy
```

The libvirt provider allows infrastructure-as-code for local VM management using KVM/QEMU.
