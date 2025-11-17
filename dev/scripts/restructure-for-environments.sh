#!/usr/bin/env bash
# Restructure macula-gitops for dev/prod separation
# This creates a clear separation between local development and production environments

set -e

REPO_ROOT="/home/rl/work/github.com/macula-io/macula-gitops"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  Restructure GitOps for Dev/Prod Environments         ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

cd "${REPO_ROOT}"

# Create new directory structure
echo -e "${CYAN}▸${NC} Creating new directory structure..."

mkdir -p dev/infrastructure
mkdir -p dev/clusters/kind-dev
mkdir -p dev/scripts
mkdir -p prod/infrastructure
mkdir -p prod/clusters
mkdir -p prod/scripts
mkdir -p docs

echo -e "${GREEN}✓${NC} Directories created"
echo ""

# Move infrastructure (dev-specific)
echo -e "${CYAN}▸${NC} Moving infrastructure to dev/..."

mv infrastructure/* dev/infrastructure/ 2>/dev/null || true

echo -e "${GREEN}✓${NC} Infrastructure moved to dev/"
echo ""

# Move scripts
echo -e "${CYAN}▸${NC} Moving scripts to dev/..."

mv scripts/* dev/scripts/ 2>/dev/null || true

echo -e "${GREEN}✓${NC} Scripts moved to dev/"
echo ""

# Move apps to dev/clusters/kind-dev
echo -e "${CYAN}▸${NC} Moving apps to dev/clusters/kind-dev/..."

mkdir -p dev/clusters/kind-dev/apps
mv apps/* dev/clusters/kind-dev/apps/ 2>/dev/null || true

echo -e "${GREEN}✓${NC} Apps moved to dev/clusters/kind-dev/apps/"
echo ""

# Move documentation
echo -e "${CYAN}▸${NC} Organizing documentation..."

mv ARCHITECTURE_DECISIONS.md docs/ 2>/dev/null || true
mv BEAM_CLUSTER_DEPLOYMENT.md docs/ 2>/dev/null || true
mv IMPLEMENTATION_PLAN.md docs/ 2>/dev/null || true
mv INFRASTRUCTURE_SUMMARY.md docs/ 2>/dev/null || true
mv MIGRATION.md docs/ 2>/dev/null || true
mv NGINX_INGRESS.md docs/ 2>/dev/null || true
mv PHASE*.md docs/ 2>/dev/null || true
mv PORTAL_ADDED.md docs/ 2>/dev/null || true
mv QUICK_START.md docs/ 2>/dev/null || true
mv SHARED_INFRASTRUCTURE.md docs/ 2>/dev/null || true
mv SUMMARY.md docs/ 2>/dev/null || true

echo -e "${GREEN}✓${NC} Documentation organized in docs/"
echo ""

# Remove now-empty directories
echo -e "${CYAN}▸${NC} Cleaning up empty directories..."

rmdir infrastructure 2>/dev/null || true
rmdir scripts 2>/dev/null || true
rmdir apps 2>/dev/null || true

echo -e "${GREEN}✓${NC} Cleanup complete"
echo ""

# Create README files for each environment
echo -e "${CYAN}▸${NC} Creating environment README files..."

cat > dev/README.md <<'EOF'
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
EOF

cat > prod/README.md <<'EOF'
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
EOF

cat > docs/README.md <<'EOF'
# Documentation

This directory contains comprehensive documentation for the Macula GitOps repository.

## Architecture

- `ARCHITECTURE_DECISIONS.md` - Key architectural decisions and rationale
- `INFRASTRUCTURE_SUMMARY.md` - Overview of infrastructure components

## Deployment

- `BEAM_CLUSTER_DEPLOYMENT.md` - Production beam cluster deployment guide
- `QUICK_START.md` - Quick start guide for local development

## Planning

- `IMPLEMENTATION_PLAN.md` - Implementation roadmap
- `PHASE*.md` - Phase completion reports

## Migration

- `MIGRATION.md` - Migration guides and notes
- `SHARED_INFRASTRUCTURE.md` - Shared infrastructure design
EOF

echo -e "${GREEN}✓${NC} README files created"
echo ""

# Update main README
echo -e "${CYAN}▸${NC} Updating main README.md..."

cat > README.md <<'EOF'
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
EOF

echo -e "${GREEN}✓${NC} Main README updated"
echo ""

echo "╔════════════════════════════════════════════════════════╗"
echo "║  Restructuring Complete                                ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

echo -e "${GREEN}New Structure:${NC}"
echo ""
echo "macula-gitops/"
echo "├── dev/"
echo "│   ├── infrastructure/     (Docker Compose)"
echo "│   ├── clusters/kind-dev/  (KinD cluster manifests)"
echo "│   └── scripts/            (Dev scripts)"
echo "├── prod/"
echo "│   ├── infrastructure/     (Production infra - future)"
echo "│   ├── clusters/           (Prod cluster manifests - future)"
echo "│   └── scripts/            (Prod scripts - future)"
echo "└── docs/                   (Documentation)"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Review the new structure"
echo "2. Update any hardcoded paths in scripts"
echo "3. Test infrastructure:"
echo "   cd dev/infrastructure && ./start-infrastructure.sh"
echo ""
echo "4. Commit changes:"
echo "   git add -A"
echo "   git commit -m 'Restructure for dev/prod separation'"
echo ""
