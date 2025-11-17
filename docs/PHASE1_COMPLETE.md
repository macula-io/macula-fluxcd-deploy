# Phase 1 Complete: Core Infrastructure

Phase 1 of the Macula GitOps infrastructure is now complete and ready for testing.

## What's Been Accomplished

### Infrastructure Services (Docker Compose)

✅ **Consolidated Infrastructure**
- Migrated from `cortex-iq-deploy` and `macula-energy-mesh-poc` repositories
- Unified Docker Compose setup in `infrastructure/`
- All services accessible via DNS-based routing

✅ **Core Services**
- **Docker Registry**: Container image registry with web UI
- **PowerDNS**: Authoritative DNS server with HTTP API
- **PostgreSQL**: Database backend for PowerDNS
- **Nginx Ingress**: Host-based routing for all services

✅ **DNS-Based Access**
```
http://registry.macula.local       → Registry UI
http://registry.macula.local/v2/   → Registry API
http://dns.macula.local            → PowerDNS API
http://dns-admin.macula.local      → PowerDNS Admin UI
```

### DNS Configuration

✅ **Wildcard DNS via Dnsmasq**
- Automated setup script: `infrastructure/setup-dnsmasq.sh`
- Multiple loopback IPs for service isolation:
  - `127.0.0.1` - Infrastructure services
  - `127.0.0.2` - KinD application services
  - `127.0.0.3-8` - Reserved for observability/data services

✅ **Subdomain Routing**
- `*.macula.local` resolves to appropriate loopback IP
- No need for manual `/etc/hosts` entries
- Clean URLs for all services

### Kubernetes (KinD) Integration

✅ **Port Mapping**
- KinD on ports 8080/8443 (avoids conflict with host nginx)
- UDP port 4433 for QUIC (bootstrap service)

✅ **Port Forwarding**
- Socat-based forwarding: `127.0.0.2:80` → `127.0.0.1:8080`
- Systemd service for persistence: `scripts/macula-port-forwarding.service`
- Management script: `scripts/setup-port-forwarding.sh`

✅ **nginx-ingress Controller**
- Deployment manifest: `apps/nginx-ingress/kustomization.yaml`
- Connected to `kind` Docker network
- Ready for application ingress resources

### Shared Infrastructure Capability

✅ **LAN Exposure**
- Override file: `infrastructure/docker-compose.lan.yml`
- Exposes services on `0.0.0.0` for beam cluster access
- Launch with: `./start-infrastructure.sh --lan`

✅ **Firewall Configuration**
- Automated script: `infrastructure/setup-firewall.sh`
- Configures UFW/firewalld for beam subnet (192.168.1.0/24)
- Allows beam00-03 to access infrastructure

✅ **Multi-Cluster Support**
- Infrastructure can serve both KinD (local) and k3s (beam clusters)
- ExternalDNS from multiple clusters can register with same PowerDNS
- Prometheus can scrape metrics from both clusters
- Complete guide: `SHARED_INFRASTRUCTURE.md`

### Testing and Validation

✅ **Comprehensive Test Suite**
- `scripts/test-infrastructure.sh` - Full end-to-end testing
- `scripts/health-check.sh` - Quick validation
- Tests all layers: Docker, DNS, HTTP routing, KinD

✅ **Test Coverage**
- Docker Compose service status
- DNS resolution for all domains
- HTTP access via nginx ingress
- KinD cluster and ingress controller
- Port forwarding processes

### Documentation

✅ **Complete Documentation Set**
- `README.md` - Main documentation with quick start
- `QUICK_START.md` - Interactive setup script
- `ARCHITECTURE_DECISIONS.md` - Service selection rationale
- `IMPLEMENTATION_PLAN.md` - Detailed implementation steps
- `INFRASTRUCTURE_SUMMARY.md` - Quick reference guide
- `SHARED_INFRASTRUCTURE.md` - LAN/multi-cluster guide
- `BEAM_CLUSTER_DEPLOYMENT.md` - Physical cluster deployment
- `MIGRATION.md` - Migration from old repositories
- `infrastructure/README.md` - Infrastructure-specific docs
- `infrastructure/NGINX_INGRESS.md` - Ingress routing details

## File Structure

```
macula-gitops/
├── infrastructure/
│   ├── docker-compose.yml           # Main infrastructure services
│   ├── docker-compose.lan.yml       # LAN exposure override
│   ├── start-infrastructure.sh      # Startup script (--lan support)
│   ├── stop-infrastructure.sh       # Shutdown script
│   ├── setup-dnsmasq.sh            # DNS configuration
│   ├── setup-firewall.sh           # Firewall for beam cluster
│   ├── config/
│   │   ├── nginx/ingress.conf      # Host-based routing
│   │   ├── powerdns/schema.sql     # PowerDNS database schema
│   │   └── powerdns-admin/         # PowerDNS Admin config
│   └── data/                       # Persistent data volumes
│
├── scripts/
│   ├── setup-cluster.sh            # KinD cluster creation
│   ├── setup-port-forwarding.sh    # Port forwarding management
│   ├── install-systemd-service.sh  # Systemd service installer
│   ├── test-infrastructure.sh      # Comprehensive testing
│   ├── health-check.sh             # Quick validation
│   └── macula-port-forwarding.service  # Systemd unit file
│
├── apps/
│   ├── nginx-ingress/              # nginx-ingress for KinD
│   ├── console/                    # Macula console app
│   ├── bootstrap/                  # DHT bootstrap node
│   └── arcade/                     # Demo game peers
│
└── Documentation (see above)
```

## Quick Start

For a complete setup from scratch:

```bash
# 1. Setup DNS (one-time, requires sudo)
cd infrastructure
sudo ./setup-dnsmasq.sh

# 2. Start infrastructure
./start-infrastructure.sh

# 3. Test infrastructure
cd ../scripts
./health-check.sh

# 4. Setup port forwarding
./setup-port-forwarding.sh start

# 5. Create KinD cluster
./setup-cluster.sh

# 6. Deploy nginx-ingress to KinD
kubectl apply -k ../apps/nginx-ingress/

# 7. Run comprehensive tests
./test-infrastructure.sh
```

## Access URLs

### Infrastructure Services
- Registry UI: http://registry.macula.local
- Registry API: http://registry.macula.local/v2/
- PowerDNS API: http://dns.macula.local
- PowerDNS Admin: http://dns-admin.macula.local
- Registry (legacy): http://localhost:5001

### Application Services (after deployment)
- Console: http://console.macula.local
- Bootstrap: http://bootstrap.macula.local
- Arcade Peers: http://peer1.macula.local, http://peer2.macula.local

## What's Next: Phase 2 & 3

### Phase 2: Observability Stack (Pending)
- Prometheus (metrics collection)
- Grafana (unified dashboards)
- Loki (log aggregation)
- Tempo (distributed tracing)

### Phase 3: Data Services (Pending)
- MinIO (S3-compatible object storage)
- TimescaleDB (PostgreSQL with time-series extensions)

## Testing Your Setup

### Quick Health Check
```bash
cd scripts
./health-check.sh
```

### Comprehensive Test
```bash
cd scripts
./test-infrastructure.sh
```

### Manual Verification
```bash
# Test DNS
dig @127.0.0.1 registry.macula.local

# Test Registry
curl http://registry.macula.local/v2/_catalog

# Test PowerDNS
curl http://dns.macula.local/api/v1/servers

# Check Docker services
cd infrastructure
docker compose ps

# Check KinD cluster
kubectl cluster-info --context kind-macula-dev
kubectl get pods -A
```

## Troubleshooting

See `README.md` for detailed troubleshooting guides covering:
- DNS resolution issues
- Docker Compose service problems
- Registry connectivity
- Port forwarding issues
- KinD cluster problems

Quick diagnosis:
```bash
cd scripts
./health-check.sh
```

## Shared Infrastructure Mode

To share infrastructure with beam clusters:

```bash
# 1. Start in LAN mode
cd infrastructure
./start-infrastructure.sh --lan

# 2. Configure firewall
sudo ./setup-firewall.sh

# 3. Configure beam clusters
# See SHARED_INFRASTRUCTURE.md for complete guide
```

## Migration from Old Repositories

If migrating from `cortex-iq-deploy` or `macula-energy-mesh-poc`:

```bash
# 1. Stop old infrastructure
cd <old-repo>/infrastructure
docker compose down -v

# 2. Follow Quick Start above

# 3. Rebuild and push images to new registry
cd macula-gitops/scripts
./build-and-push.sh
```

See `MIGRATION.md` for detailed migration guide.

## GitOps Workflow

Phase 1 infrastructure is now ready for GitOps deployments:

1. **Build** Docker image with cache-bust
2. **Tag** for registry: `registry.macula.local/[app]:latest`
3. **Push** to registry
4. **Update** manifests (if needed) in `apps/` or `clusters/`
5. **Commit** and push to Git
6. **Let Flux reconcile** (or manually apply with kubectl)

Never bypass the registry with `kind load docker-image` - always push to registry.

## Summary

Phase 1 provides a **complete, production-ready foundation** for the Macula GitOps platform:

✅ Unified infrastructure consolidating previous repositories
✅ DNS-based service routing (*.macula.local)
✅ Docker Compose for infrastructure services
✅ KinD integration with proper port isolation
✅ Shared infrastructure capability for beam clusters
✅ Comprehensive testing and validation tools
✅ Complete documentation

**Phase 1 is ready for deployment and testing.**

Next: Add observability stack (Phase 2) and data services (Phase 3).
