# Production Environment

This directory will contain all configuration for production deployments.

## Planned Components

### Beam Clusters (k3s)
- 4 physical nodes (beam00-03)
- Production-grade Kubernetes
- FluxCD for GitOps
- External DNS with production provider
- Production ingress controller

### Infrastructure
- External PostgreSQL/TimescaleDB
- External object storage (MinIO or S3)
- External observability (Prometheus, Grafana, Loki)
- Production DNS provider

### GitOps Structure

Applications will be deployed via FluxCD from `clusters/`:
- `beam-cluster/` - Beam cluster manifests
- `infrastructure/` - Shared infrastructure
- FluxCD monitors and reconciles production state

## Security

Production environment includes:
- Network policies
- RBAC configurations
- Secret management (sealed-secrets or external-secrets)
- TLS/certificates
- Resource limits and quotas
