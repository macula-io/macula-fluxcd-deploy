# Macula GitOps

Infrastructure as Code and GitOps configuration for the Macula platform.

## Repository Structure

```
macula-gitops/
├── dev/                      # Development environment
│   ├── infrastructure/       # Docker Compose services
│   ├── clusters/kind-dev/    # KinD cluster manifests
│   └── scripts/              # Dev automation scripts
├── prod/                     # Production environment
│   ├── infrastructure/       # Production infrastructure
│   ├── clusters/             # Production cluster manifests
│   └── scripts/              # Prod automation scripts
└── docs/                     # Documentation
```

## Environments

### Development (`dev/`)

Local development environment using:
- Docker Compose for infrastructure services
- KinD (Kubernetes in Docker) for cluster
- FluxCD for GitOps
- PowerDNS for `.macula.local` domain

**Quick Start:**
```bash
cd dev/infrastructure
./start-infrastructure.sh

cd ../scripts
./setup-kind-with-gitops.sh
```

See `dev/README.md` for details.

### Production (`prod/`)

Production deployment targeting:
- Beam clusters (4-node k3s)
- External infrastructure services
- FluxCD for GitOps
- Production DNS provider

See `prod/README.md` for details.

## Documentation

Comprehensive documentation is in `docs/`:
- Architecture decisions
- Implementation plans
- Deployment guides
- Migration notes

See `docs/README.md` for index.

## GitOps Workflow

Both environments use FluxCD for declarative deployments:

1. **Development:**
   - Edit manifests in `dev/clusters/kind-dev/apps/`
   - Commit and push
   - FluxCD reconciles KinD cluster

2. **Production:**
   - Edit manifests in `prod/clusters/`
   - Commit and push
   - FluxCD reconciles production clusters

## License

See LICENSE file.
