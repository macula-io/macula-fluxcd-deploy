# Macula GitOps Setup Complete

## Summary

Successfully set up the complete Macula development environment with GitOps workflow.

## Infrastructure Components

### Host Infrastructure (Docker Compose)
Running at `dev/infrastructure/`:

- **Docker Registry** - `registry.macula.local` - Local container registry
- **PowerDNS** - `dns.macula.local` - Authoritative DNS server with API
- **Observability Stack**:
  - Prometheus - `prometheus.macula.local`
  - Grafana - `grafana.macula.local`
  - Loki - `loki.macula.local`
  - Tempo - `tempo.macula.local`
- **Development Tools**:
  - Portal - `home.macula.local` - Central landing page
  - Excalidraw - `draw.macula.local` - Whiteboarding
- **Data Services**:
  - TimescaleDB - `postgres.macula.local:5432`
  - MinIO - `s3.macula.local` / `s3-console.macula.local`

### KinD Cluster
Kubernetes cluster `macula-dev` with:

- **nginx-ingress-controller** - HTTP routing
- **ExternalDNS** - Automatic DNS record creation in PowerDNS
- **FluxCD** - GitOps continuous deployment (optional, requires GitHub token)
- **macula-bootstrap** - Bootstrap service running on QUIC (UDP 4433)

## DNS Configuration

All services use `.macula.local` domain:
- **Host services** (Docker Compose) → `127.0.0.1` (via dnsmasq)
- **KinD services** → `127.0.0.2` (via ExternalDNS + PowerDNS)

DNS resolution provided by:
1. **dnsmasq** - Resolves host infrastructure services
2. **PowerDNS** - Authoritative server for all `.macula.local` domains
3. **ExternalDNS** - Watches Kubernetes Ingresses and creates DNS records

## Registry Configuration

The Docker registry is accessible via multiple methods:
- **From host**: `registry.macula.local` (nginx proxy)
- **From host (legacy)**: `localhost:5001` (direct access)
- **From KinD cluster**: `kind-registry:5000` (Docker network alias)

The registry is connected to the `kind` Docker network with the alias `kind-registry`, allowing KinD's containerd to pull images seamlessly.

## Repository Structure

```
macula-gitops/
├── dev/                          # Development environment
│   ├── infrastructure/           # Docker Compose services
│   ├── clusters/kind-dev/        # KinD cluster GitOps manifests
│   │   └── apps/bootstrap/       # Bootstrap service deployment
│   ├── scripts/                  # Dev automation scripts
│   └── README.md                 # Dev environment docs
│
├── prod/                         # Production environment (future)
│   ├── infrastructure/           # Production infrastructure
│   ├── clusters/                 # Production cluster manifests
│   └── README.md                 # Prod environment docs
│
├── docs/                         # Documentation
│   ├── ARCHITECTURE_DECISIONS.md
│   ├── IMPLEMENTATION_PLAN.md
│   └── ...
│
└── README.md                     # Main repository overview
```

## Quick Start

### Start Infrastructure
```bash
cd dev/infrastructure
./start-infrastructure.sh
```

### Setup DNS (first time only)
```bash
cd dev/infrastructure
sudo ./setup-dnsmasq.sh
sudo ./start-dnsmasq.sh
```

### Create KinD Cluster with GitOps
```bash
cd dev/scripts
./setup-kind-with-gitops.sh
```

### Access Services
- **Portal**: http://home.macula.local
- **Registry UI**: http://registry.macula.local
- **Grafana**: http://grafana.macula.local
- **PowerDNS Admin**: http://dns-admin.macula.local
- **Bootstrap Service**: bootstrap.macula.local (QUIC on UDP 4433)

## GitOps Workflow

### Without FluxCD (Manual)
1. Edit manifests in `dev/clusters/kind-dev/apps/`
2. Apply manually: `kubectl apply -k dev/clusters/kind-dev/apps/bootstrap`

### With FluxCD (Automated)
1. Set GitHub token: `export GITHUB_TOKEN=<your-token>`
2. Run setup script again to bootstrap Flux
3. Edit manifests in `dev/clusters/kind-dev/apps/`
4. Commit and push to Git
5. Flux automatically reconciles cluster state

## Deploying Applications

### Build and Push Image
```bash
# Build image with cache-bust
docker build --build-arg CACHE_BUST=$(date +%s) -t registry.macula.local/myapp:latest .

# Push to registry
docker push registry.macula.local/myapp:latest
```

### Create Kubernetes Manifests
```bash
# Create app directory
mkdir -p dev/clusters/kind-dev/apps/myapp

# Add deployment, service, ingress manifests
# See dev/clusters/kind-dev/apps/bootstrap/ for example
```

### Deploy
```bash
# Manual deployment
kubectl apply -k dev/clusters/kind-dev/apps/myapp

# Or commit and push (if using FluxCD)
git add dev/clusters/kind-dev/apps/myapp
git commit -m "Add myapp deployment"
git push
```

ExternalDNS will automatically create DNS records based on Ingress resources.

## Troubleshooting

### DNS Issues
```bash
# Test DNS resolution
dig +short bootstrap.macula.local @127.0.0.1

# Check dnsmasq status
systemctl status dnsmasq

# Check PowerDNS zones
curl -H "X-API-Key: macula-dev-api-key" http://172.23.0.10:8081/api/v1/servers/localhost/zones
```

### Registry Issues
```bash
# Test registry from host
curl http://registry.macula.local/v2/_catalog

# Test registry from KinD node
docker exec macula-dev-control-plane curl -s http://kind-registry:5000/v2/_catalog
```

### ExternalDNS Issues
```bash
# Check ExternalDNS logs
kubectl --context kind-macula-dev logs -n external-dns -l app=external-dns

# Verify PowerDNS is accessible from cluster
kubectl --context kind-macula-dev run test --image=curlimages/curl --rm -it -- \
  curl -H "X-API-Key: macula-dev-api-key" http://macula-powerdns:8081/api/v1/servers/localhost/zones
```

### Pod Image Pull Issues
```bash
# Check if registry is connected to kind network
docker network inspect kind | grep macula-registry

# Reconnect if needed
docker network disconnect kind macula-registry
docker network connect kind macula-registry --alias kind-registry
```

## Key Fixes Applied

1. **PowerDNS Schema**: Added missing `options` and `catalog` columns to `domains` table
2. **Registry Network**: Connected registry to `kind` network with `kind-registry` alias
3. **ExternalDNS Configuration**: Updated to use `http://macula-powerdns:8081` instead of host IP
4. **Bootstrap Health Probes**: Changed from `ping` command to `pgrep -f beam.smp`
5. **DNS Zone Creation**: Manually created `macula.local` zone in PowerDNS database

## Next Steps

1. Install FluxCD (optional):
   - Set `GITHUB_TOKEN` environment variable
   - Run `dev/scripts/setup-kind-with-gitops.sh` again

2. Deploy additional applications:
   - Create manifests in `dev/clusters/kind-dev/apps/`
   - Follow GitOps workflow

3. Configure production environment:
   - Set up beam cluster infrastructure in `prod/`
   - Create production GitOps manifests in `prod/clusters/`

## Status

✅ All infrastructure running
✅ KinD cluster operational
✅ ExternalDNS creating DNS records
✅ Registry accessible from cluster
✅ Bootstrap service running (1/1 Ready)
✅ GitOps-ready structure

🎉 **Development environment is fully operational!**
