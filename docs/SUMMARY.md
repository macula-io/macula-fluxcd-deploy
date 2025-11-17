# Macula GitOps - Infrastructure Consolidation Summary

## What Was Built

A unified infrastructure setup for Macula platform development that consolidates:
- Docker Registry (from macula-energy-mesh-poc)
- PowerDNS (from macula-energy-mesh-poc)
- KinD cluster management (from cortex-iq-deploy)

Into a single, cohesive repository with clear workflows and documentation.

## Repository Structure

```
macula-gitops/
├── infrastructure/               # Host-level infrastructure (Docker Compose)
│   ├── config/
│   │   ├── nginx/
│   │   │   └── nginx.conf       # Registry reverse proxy config
│   │   └── powerdns/
│   │       ├── pdns.conf        # PowerDNS configuration
│   │       └── init-schema.sql  # PostgreSQL schema for PowerDNS
│   ├── docker-compose.yml       # All infrastructure services
│   ├── .env.example             # Environment variables template
│   ├── .gitignore               # Ignore .env and data directories
│   ├── README.md                # Detailed infrastructure documentation
│   ├── start-infrastructure.sh  # Start all services
│   └── stop-infrastructure.sh   # Stop all services
│
├── scripts/                      # Cluster and deployment scripts
│   ├── setup-cluster.sh         # Create KinD cluster + connect to infrastructure
│   └── build-and-push.sh        # Build and push Macula images to registry
│
├── README.md                     # Main repository documentation
└── MIGRATION.md                  # Migration guide from old repos
```

## Services Provided

### Host Infrastructure (Docker Compose)

**Port 5001 - Docker Registry**
- Registry v2 API: `http://localhost:5001/v2/`
- Web UI: `http://localhost:5001/`
- Internal components:
  - `macula-registry` - Registry backend
  - `macula-registry-ui` - Web interface
  - `macula-registry-nginx` - Reverse proxy

**Port 8081 - PowerDNS API**
- HTTP API: `http://localhost:8081/` (for ExternalDNS)
- Internal components:
  - `macula-powerdns` - DNS server
  - `macula-dns-postgres` - PostgreSQL backend

**Port 9191 - PowerDNS Admin**
- Web UI: `http://localhost:9191/`
- Component:
  - `macula-powerdns-admin` - Admin interface

### Kubernetes (KinD)

**Cluster:** macula-dev
- Single control-plane node
- Configured to pull images from local registry
- Port mappings: 80, 443 (HTTP/HTTPS), 4433/UDP (QUIC)

## Workflow

### Complete Setup (First Time)

```bash
# 1. Start infrastructure
cd macula-gitops/infrastructure
./start-infrastructure.sh

# 2. Create KinD cluster
cd ../scripts
./setup-cluster.sh

# 3. Build and push application images
./build-and-push.sh

# 4. Deploy applications (when Kubernetes manifests are ready)
kubectl apply -k ../clusters/dev
```

### Daily Development

```bash
# Make code changes in macula/macula-console/macula-arcade

# Rebuild and deploy
cd macula-gitops/scripts
./build-and-push.sh

# Applications will pull new images
kubectl rollout restart deployment/macula-console -n macula
# Or let Flux handle it via GitOps
```

### Shutdown

```bash
# Stop infrastructure (keeps data)
cd macula-gitops/infrastructure
./stop-infrastructure.sh

# Delete cluster
kind delete cluster --name macula-dev

# Remove all data (optional)
cd macula-gitops/infrastructure
docker compose down -v
```

## Key Features

### 1. Unified Configuration

**Before:** Scattered across multiple repos
- macula-energy-mesh-poc/infrastructure/registry/
- macula-energy-mesh-poc/infrastructure/docker-compose.dns.yml
- cortex-iq-deploy/scripts/

**After:** Single docker-compose.yml with:
- All services in one file
- Unified network (172.23.0.0/16)
- Consistent naming (macula-* prefix)

### 2. Automated Setup

**Registry Connection:**
- Automatically connects to KinD network
- Creates alias "kind-registry" for cluster access
- Configures containerd to use local registry

**DNS Configuration:**
- PowerDNS ready for ExternalDNS integration
- Admin UI for manual DNS management
- PostgreSQL backend with initialized schema

### 3. Comprehensive Documentation

**Infrastructure README:**
- Service architecture diagram
- Usage examples for registry and DNS
- Troubleshooting guide
- Backup/restore procedures

**Migration Guide:**
- Step-by-step consolidation process
- Data migration instructions
- Rollback plan
- Cleanup recommendations

### 4. Production-Ready Structure

**Security Notes:**
- Clear warnings about development-only config
- .env.example with default values
- .gitignore to prevent secret commits

**Maintenance:**
- Log viewing commands
- Service restart procedures
- Update strategies
- Data backup examples

## Technical Improvements

### Registry Setup

**Enhanced:**
- Nginx reverse proxy with proper headers
- CORS configuration for browser access
- Large file upload support
- Health checks for all components
- Web UI for visual management

**Network:**
- Connected to both infrastructure network and KinD network
- Accessible as "kind-registry:5000" from pods
- Accessible as "localhost:5001" from host

### PowerDNS Setup

**Complete:**
- PostgreSQL backend with full schema
- HTTP API enabled and configured
- Admin UI for easy management
- DNSSEC support enabled
- Proper logging configuration

**Integration Ready:**
- API key authentication
- ExternalDNS compatible
- Query logging enabled
- Performance tuning applied

### KinD Cluster Setup

**Improved:**
- Prerequisites checking (kind, kubectl, infrastructure)
- Automatic registry connection with alias
- Port mappings for common services
- Registry configuration via ConfigMap
- Clear error messages and guidance

## Differences from Original Repos

### Port Changes

| Service | Old | New | Reason |
|---------|-----|-----|--------|
| Registry | 5000 | 5001 | Avoid conflicts with common services |

### Network Changes

| Service | Old Network | New Network | Reason |
|---------|-------------|-------------|--------|
| Registry | `registry` | `macula-infra` | Unified infrastructure network |
| PowerDNS | `dns-network` (172.22.0.0/16) | `macula-infra` (172.23.0.0/16) | Avoid subnet conflicts |

### Container Naming

All containers now use `macula-*` prefix for consistency:
- `macula-registry`, `macula-registry-ui`, `macula-registry-nginx`
- `macula-dns-postgres`, `macula-powerdns`, `macula-powerdns-admin`

## Data Persistence

### Volumes

Created automatically by Docker Compose:
- `registry-data` - Container images and blobs
- `dns-postgres-data` - DNS records and PowerDNS state

### Location

Default: Managed by Docker (`/var/lib/docker/volumes/`)

### Backup

Documented in infrastructure README:
- Registry backup/restore commands
- DNS backup/restore commands
- Volume export/import procedures

## Future Enhancements

### Planned

1. **Kubernetes Manifests**
   - apps/bootstrap/ - Bootstrap service deployment
   - apps/console/ - Console + PostgreSQL
   - apps/arcade/ - Game peers
   - clusters/dev/ - Kustomize overlay

2. **ExternalDNS Deployment**
   - Automatic DNS record creation
   - Integration with PowerDNS API
   - .macula.local domain management

3. **Flux GitOps**
   - Automated reconciliation
   - Git-based deployments
   - Secret management

4. **Multi-Cluster Support**
   - Hub + spoke architecture
   - Shared infrastructure
   - Per-cluster customization

### Possible

- TLS/SSL for registry (dev certs)
- Registry authentication
- DNS zone templates
- Automated backup scripts
- Monitoring with Prometheus
- Grafana dashboards

## Migration Path

For existing users of macula-energy-mesh-poc or cortex-iq-deploy:

1. **Review MIGRATION.md** - Complete migration guide
2. **Stop old infrastructure** - Clean shutdown of old services
3. **Start new infrastructure** - Single command setup
4. **Migrate data** - Registry images and DNS records (if needed)
5. **Test workflow** - Verify everything works
6. **Archive old repos** - Move old infrastructure to _archived/

## Success Criteria

✅ **Achieved:**
- Single command infrastructure startup
- Automated KinD cluster setup with registry connection
- Comprehensive documentation
- Migration guide for existing users
- Production-ready structure with security notes

✅ **Ready for:**
- Application deployment via GitOps
- ExternalDNS integration
- Multi-service Kubernetes manifests
- Team onboarding and collaboration

## Next Steps

1. **Create Kubernetes manifests:**
   - Bootstrap service (StatefulSet)
   - Console service (Deployment + Service + PostgreSQL)
   - Arcade peers (Deployment)

2. **Deploy ExternalDNS:**
   - Configure to use PowerDNS API
   - Create .macula.local zone
   - Test automatic record creation

3. **Set up GitOps:**
   - Install Flux (optional for dev)
   - Configure source repositories
   - Test automated deployments

4. **Team Adoption:**
   - Share macula-gitops repository
   - Conduct walkthrough of workflow
   - Gather feedback and iterate

## Resources

- **Main README:** Overview and quick start
- **Infrastructure README:** Detailed infrastructure documentation
- **Migration Guide:** Consolidation and data migration
- **Scripts:** Automated setup and deployment
- **Docker Compose:** Complete infrastructure definition
- **Configuration:** Registry and PowerDNS settings

## Contact

For questions or issues:
1. Check README.md and infrastructure/README.md
2. Review MIGRATION.md for migration-specific questions
3. Examine docker-compose.yml for service configuration
4. Run scripts with bash -x for debugging

---

**Repository:** macula-io/macula-gitops
**Purpose:** Unified infrastructure and GitOps for Macula platform development
**Status:** ✅ Infrastructure consolidated and ready for application deployment
