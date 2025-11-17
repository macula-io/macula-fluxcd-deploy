# Development Environment

This directory contains all configuration for the local development environment.

## Components

### Infrastructure (Docker Compose)
- Local Docker registry
- PowerDNS (authoritative DNS server)
- Observability stack (Prometheus, Grafana, Loki, Tempo)
- Development tools (Portal, Excalidraw)
- Data services (TimescaleDB, MinIO)

### KinD Cluster
- Local Kubernetes cluster for development
- FluxCD for GitOps
- ExternalDNS integration with PowerDNS
- nginx-ingress-controller

### Scripts
- Infrastructure setup and management
- KinD cluster creation
- Port forwarding and DNS configuration

## Quick Start

1. Start infrastructure:
   ```bash
   cd infrastructure
   ./start-infrastructure.sh
   ```

2. Create KinD cluster with GitOps:
   ```bash
   cd scripts
   ./setup-kind-with-gitops.sh
   ```

3. Access portal:
   ```bash
   http://home.macula.local
   ```

## DNS Configuration

All services use `.macula.local` domain:
- Infrastructure services resolve to `127.0.0.1` (Docker host)
- KinD cluster services resolve to `127.0.0.2` (via ExternalDNS + PowerDNS)

## GitOps Structure

Applications are deployed via FluxCD from `clusters/kind-dev/`:
- `apps/` - Application manifests
- FluxCD monitors this path and reconciles cluster state
