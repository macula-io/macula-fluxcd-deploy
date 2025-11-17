# Macula Infrastructure

Host-level infrastructure services for Macula platform development.

## Overview

This directory contains Docker Compose configuration for infrastructure services that run on the host machine and provide services to KinD Kubernetes clusters.

### Services

1. **Nginx Ingress** - Host-based routing for all services
   - Routes traffic via HTTP Host headers
   - Exposes on port 80 (HTTP)
   - Maintains port 5001 for backward compatibility

2. **Docker Registry** - Local container registry
   - Registry v2 API server
   - Web UI (joxit/docker-registry-ui)
   - Accessible via `http://registry.macula.local`

3. **PowerDNS** - Authoritative DNS server
   - PostgreSQL backend
   - HTTP API accessible via `http://dns.macula.local`
   - Admin web UI at `http://dns-admin.macula.local`

## Quick Start

```bash
# Add DNS entries to /etc/hosts
echo "127.0.0.1 registry.macula.local dns.macula.local dns-admin.macula.local" | sudo tee -a /etc/hosts

# Start all infrastructure services
./start-infrastructure.sh

# Stop services (keeps data)
./stop-infrastructure.sh

# Stop and remove all data
docker compose down -v
```

## Architecture

### Network Layout

```
Host Machine (127.0.0.1)
├── Port 80 (HTTP) → Nginx Ingress (host-based routing)
│   ├── registry.macula.local → registry + registry-ui
│   ├── dns.macula.local → powerdns:8081 (API)
│   └── dns-admin.macula.local → powerdns-admin
│
├── Port 5001 (HTTP) → Nginx Ingress (legacy/direct access)
│   └── localhost:5001 → registry + registry-ui
│
└── Infrastructure Network (172.23.0.0/16)
    ├── macula-nginx-ingress (nginx:alpine)
    ├── macula-registry (registry:2)
    ├── macula-registry-ui (joxit/docker-registry-ui)
    ├── macula-dns-postgres (postgres:15)
    ├── macula-powerdns (powerdns/pdns-auth-48)
    └── macula-powerdns-admin (ngoduykhanh/powerdns-admin)

KinD Network (created by KinD)
└── macula-dev-control-plane
    └── Connects to macula-nginx-ingress as "kind-registry:5000"
```

### Service Communication

1. **Registry Flow (DNS-based):**
   ```
   # From developer browser/docker CLI
   Developer → registry.macula.local:80 → nginx-ingress → registry-ui:80 (UI)
                                                         → registry:5000 (API /v2/)

   # From KinD pods
   KinD Pod → kind-registry:5000 → macula-nginx-ingress:5001 → registry:5000
   ```

2. **Registry Flow (Legacy):**
   ```
   Developer → localhost:5001 → nginx-ingress:5001 → registry-ui:80 (UI)
                                                    → registry:5000 (API /v2/)
   ```

3. **DNS Flow:**
   ```
   # PowerDNS API (for ExternalDNS)
   ExternalDNS → dns.macula.local:80 → nginx-ingress → powerdns:8081 (API)
                                                      → dns-postgres:5432 (backend)

   # PowerDNS Admin UI
   Developer → dns-admin.macula.local:80 → nginx-ingress → powerdns-admin:80
   ```

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and customize:

```bash
cp .env.example .env
```

Key variables:
- `POSTGRES_PASSWORD` - PostgreSQL password for PowerDNS backend
- `POWERDNS_API_KEY` - API key for PowerDNS HTTP API (used by ExternalDNS)
- `PDNS_ADMIN_SECRET_KEY` - Secret key for PowerDNS Admin UI

### Data Persistence

Data is stored in Docker volumes:
- `registry-data` - Container images
- `dns-postgres-data` - DNS records and PowerDNS configuration

**Location:** Managed by Docker (usually `/var/lib/docker/volumes/`)

**Backup:**
```bash
# Backup registry data
docker run --rm -v macula_infrastructure_registry-data:/data \
  -v $(pwd)/backup:/backup alpine tar czf /backup/registry-backup.tar.gz -C /data .

# Backup DNS data
docker run --rm -v macula_infrastructure_dns-postgres-data:/data \
  -v $(pwd)/backup:/backup alpine tar czf /backup/dns-backup.tar.gz -C /data .
```

**Restore:**
```bash
# Restore registry data
docker run --rm -v macula_infrastructure_registry-data:/data \
  -v $(pwd)/backup:/backup alpine tar xzf /backup/registry-backup.tar.gz -C /data

# Restore DNS data
docker run --rm -v macula_infrastructure_dns-postgres-data:/data \
  -v $(pwd)/backup:/backup alpine tar xzf /backup/dns-backup.tar.gz -C /data
```

## Usage

### Registry

**Push an image:**
```bash
# Build
docker build -t my-app:latest .

# Tag for local registry (DNS-based - recommended)
docker tag my-app:latest registry.macula.local/my-app:latest

# Push
docker push registry.macula.local/my-app:latest

# Or use legacy port-based access
docker tag my-app:latest localhost:5001/my-app:latest
docker push localhost:5001/my-app:latest
```

**View registry contents:**
```bash
# Via API (DNS-based)
curl http://registry.macula.local/v2/_catalog

# Via API (legacy)
curl http://localhost:5001/v2/_catalog

# Via Web UI (DNS-based)
open http://registry.macula.local/

# Via Web UI (legacy)
open http://localhost:5001/
```

**Use in Kubernetes:**
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: my-app
        image: kind-registry:5000/my-app:latest
        imagePullPolicy: Always
```

### PowerDNS

**Access Admin UI:**
```bash
open http://dns-admin.macula.local/
```

Default credentials (first time setup):
- Email: admin@example.com
- Password: admin

**API Access (for ExternalDNS):**
```bash
# Test API connectivity (DNS-based)
curl -H "X-API-Key: macula-dev-api-key" http://dns.macula.local/api/v1/servers

# List zones
curl -H "X-API-Key: macula-dev-api-key" http://dns.macula.local/api/v1/servers/localhost/zones
```

**Create DNS zone manually:**
```bash
curl -X POST http://dns.macula.local/api/v1/servers/localhost/zones \
  -H "X-API-Key: macula-dev-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "macula.local.",
    "kind": "Native",
    "nameservers": ["ns1.macula.local."]
  }'
```

**Add DNS record:**
```bash
curl -X PATCH http://dns.macula.local/api/v1/servers/localhost/zones/macula.local. \
  -H "X-API-Key: macula-dev-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "rrsets": [{
      "name": "console.macula.local.",
      "type": "A",
      "changetype": "REPLACE",
      "records": [{
        "content": "172.20.0.10",
        "disabled": false
      }]
    }]
  }'
```

## Troubleshooting

### Registry Issues

**Container not starting:**
```bash
docker compose logs registry
docker compose ps
```

**Images not visible:**
```bash
# Check registry API
curl http://localhost:5001/v2/_catalog

# Check if nginx is routing correctly
docker compose logs registry-nginx
```

**KinD can't pull images:**
```bash
# Check if registry is connected to kind network
docker network inspect kind | grep macula-registry-nginx

# Reconnect if needed
docker network connect kind macula-registry-nginx --alias kind-registry

# Check containerd configuration in KinD node
docker exec macula-dev-control-plane cat /etc/containerd/config.toml | grep -A 5 registry
```

### PowerDNS Issues

**API not accessible:**
```bash
# Check PowerDNS logs
docker compose logs powerdns

# Check if webserver is enabled
docker compose exec powerdns pdns_control show webserver

# Test API key
curl -H "X-API-Key: macula-dev-api-key" http://localhost:8081/api/v1/servers
```

**Database connection errors:**
```bash
# Check PostgreSQL
docker compose logs dns-postgres

# Verify database exists
docker compose exec dns-postgres psql -U powerdns -l
```

**Schema not initialized:**
```bash
# Recreate database with schema
docker compose down -v
docker compose up -d
```

## Integration with KinD

After starting the infrastructure, create a KinD cluster that uses these services:

```bash
cd ../scripts
./setup-cluster.sh
```

The setup script will:
1. Verify infrastructure is running
2. Create KinD cluster with registry configuration
3. Connect registry nginx container to KinD network
4. Configure cluster to use `kind-registry:5000` for image pulls

## Maintenance

### View logs
```bash
docker compose logs -f                  # All services
docker compose logs -f registry         # Registry only
docker compose logs -f powerdns         # PowerDNS only
```

### Restart services
```bash
docker compose restart registry         # Restart registry
docker compose restart powerdns         # Restart PowerDNS
docker compose restart                  # Restart all
```

### Update images
```bash
docker compose pull                     # Pull latest images
docker compose up -d                    # Recreate with new images
```

### Clean up old registry images
```bash
# Access registry container
docker compose exec registry sh

# Run garbage collection
registry garbage-collect /etc/docker/registry/config.yml
```

## Security Notes

⚠️ **Development Only**: This configuration is intended for local development only!

**Not suitable for production:**
- No TLS/SSL encryption
- Default passwords in .env.example
- Registry accessible without authentication
- PowerDNS API key in plain text
- No network isolation from host

**For production deployments:**
- Use proper secrets management (Kubernetes Secrets, Vault, etc.)
- Enable TLS for registry and PowerDNS
- Implement authentication and authorization
- Use managed DNS services or proper PowerDNS hardening
- Follow security best practices for each component
