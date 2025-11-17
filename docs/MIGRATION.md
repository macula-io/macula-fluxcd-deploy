# Infrastructure Migration Guide

This document describes the consolidation of infrastructure from existing repositories into `macula-gitops`.

## What Was Consolidated

### From `macula-energy-mesh-poc/infrastructure/`

**Registry Setup:**
- `registry/docker-compose.yml` → `infrastructure/docker-compose.yml` (registry services)
- `registry/config/nginx/nginx.conf` → `infrastructure/config/nginx/nginx.conf`

**PowerDNS Setup:**
- `docker-compose.dns.yml` → `infrastructure/docker-compose.yml` (DNS services)
- `config/powerdns/*.conf` → `infrastructure/config/powerdns/pdns.conf`
- `config/powerdns/init-schema.sql` → `infrastructure/config/powerdns/init-schema.sql`

**Scripts:**
- Management scripts replaced by `start-infrastructure.sh` and `stop-infrastructure.sh`

### From `cortex-iq-deploy/scripts/`

**Registry Connection:**
- `connect-registry.sh` → Integrated into `scripts/setup-cluster.sh`
- Logic moved to cluster setup script with proper error handling

**Cluster Setup:**
- Similar KinD cluster creation patterns
- Registry configuration consolidated

## Key Changes

### Unified Infrastructure

**Before:**
- Separate docker-compose files for registry and DNS
- Different network configurations
- Manual connection steps

**After:**
- Single `infrastructure/docker-compose.yml` with all host services
- Unified network (172.23.0.0/16)
- Automated setup scripts

### Improved Workflow

**Old Workflow:**
```bash
# Start registry (separate location)
cd macula-energy-mesh-poc/infrastructure/registry
docker compose up -d

# Start DNS (different location)
cd ../
docker compose -f docker-compose.dns.yml up -d

# Create cluster
cd cortex-iq-deploy/scripts
./create-clusters.sh

# Connect registry
./connect-registry.sh
```

**New Workflow:**
```bash
# Start all infrastructure
cd macula-gitops/infrastructure
./start-infrastructure.sh

# Create cluster (auto-connects to infrastructure)
cd ../scripts
./setup-cluster.sh
```

### Configuration Management

**Before:**
- Different registry ports (5000 vs 5001)
- Inconsistent naming (kind-registry vs macula-registry)
- Manual network configuration

**After:**
- Consistent port mapping (5001 for host access)
- Standardized naming (`macula-*` prefix)
- Automatic network connection via setup script

## Migration Steps

If you have existing infrastructure running:

### 1. Stop Old Infrastructure

```bash
# Stop old registry (if running)
cd macula-energy-mesh-poc/infrastructure/registry
docker compose down

# Stop old DNS (if running)
cd ../
docker compose -f docker-compose.dns.yml down

# Or stop all old infrastructure
docker stop macula-registry macula-dns-postgres macula-powerdns macula-powerdns-admin
docker rm macula-registry macula-dns-postgres macula-powerdns macula-powerdns-admin
```

### 2. Delete Old KinD Clusters

```bash
# List existing clusters
kind get clusters

# Delete old clusters
kind delete cluster --name macula-hub
kind delete cluster --name macula-edge-01
kind delete cluster --name macula-edge-02
# ... etc
```

### 3. Start New Infrastructure

```bash
cd macula-gitops/infrastructure
./start-infrastructure.sh
```

### 4. Create New Cluster

```bash
cd ../scripts
./setup-cluster.sh
```

## Data Migration

If you need to preserve data from old infrastructure:

### Registry Images

```bash
# Export images from old registry
# (Assuming old registry at localhost:5000)
OLD_IMAGES=$(curl -s http://localhost:5000/v2/_catalog | jq -r '.repositories[]')

for image in $OLD_IMAGES; do
  # Pull from old registry
  docker pull localhost:5000/${image}:latest

  # Re-tag for new registry
  docker tag localhost:5000/${image}:latest localhost:5001/${image}:latest

  # Push to new registry (after starting new infrastructure)
  docker push localhost:5001/${image}:latest
done
```

### DNS Records

PowerDNS data is stored in PostgreSQL. To migrate:

```bash
# Backup from old PowerDNS
docker exec macula-dns-postgres pg_dump -U powerdns powerdns > powerdns-backup.sql

# Restore to new PowerDNS (after starting new infrastructure)
cat powerdns-backup.sql | docker exec -i macula-dns-postgres psql -U powerdns powerdns
```

## Cleanup

After successfully migrating to the new infrastructure:

### Remove Old Directories

These can be safely removed or archived:

1. **macula-energy-mesh-poc/infrastructure/**
   - Keep: Application-specific configs
   - Remove: registry/, docker-compose.dns.yml

2. **cortex-iq-deploy/**
   - Review for any project-specific scripts
   - Most cluster management consolidated into macula-gitops

### Archive vs Delete

**Recommended Approach:**
```bash
# Archive instead of deleting
cd macula-energy-mesh-poc
mkdir _archived
mv infrastructure/registry _archived/
mv infrastructure/docker-compose.dns.yml _archived/
mv infrastructure/config/powerdns _archived/

# Same for cortex-iq-deploy
cd cortex-iq-deploy
mkdir _archived
mv scripts/connect-registry.sh _archived/
mv scripts/create-clusters.sh _archived/
```

This allows rollback if needed, while keeping working directories clean.

## Differences to Note

### Port Changes

| Service | Old Port | New Port | Notes |
|---------|----------|----------|-------|
| Registry | 5000 | 5001 | Changed to match new setup |
| PowerDNS API | 8081 | 8081 | No change |
| PowerDNS Admin | 9191 | 9191 | No change |

### Network Changes

| Component | Old Network | New Network |
|-----------|-------------|-------------|
| Registry | `registry` | `macula-infra` |
| PowerDNS | `dns-network` (172.22.0.0/16) | `macula-infra` (172.23.0.0/16) |

### Container Names

All containers now use `macula-*` prefix:
- `macula-registry`
- `macula-registry-ui`
- `macula-registry-nginx`
- `macula-dns-postgres`
- `macula-powerdns`
- `macula-powerdns-admin`

## Troubleshooting Migration

### Port Conflicts

If you get port binding errors:

```bash
# Check what's using the port
sudo lsof -i :5001
sudo lsof -i :8081
sudo lsof -i :9191

# Stop old containers
docker ps -a | grep -E "(registry|powerdns)" | awk '{print $1}' | xargs docker rm -f
```

### Network Conflicts

If networks conflict:

```bash
# Remove old networks
docker network rm registry dns-network

# Prune unused networks
docker network prune
```

### Volume Conflicts

If you want to start fresh:

```bash
# Remove old volumes
docker volume rm $(docker volume ls -q | grep -E "(registry|powerdns)")

# Or remove all unused volumes
docker volume prune
```

## Rollback Plan

If you need to rollback to the old infrastructure:

```bash
# Stop new infrastructure
cd macula-gitops/infrastructure
docker compose down

# Start old registry
cd macula-energy-mesh-poc/infrastructure/registry
docker compose up -d

# Start old DNS
cd ../
docker compose -f docker-compose.dns.yml up -d

# Recreate old clusters
cd cortex-iq-deploy/scripts
./create-clusters.sh
./connect-registry.sh
```

## Benefits of Consolidation

1. **Single Source of Truth**
   - All infrastructure in one repository
   - Easier to version and track changes

2. **Simplified Workflow**
   - One command to start all infrastructure
   - Automated cluster connection

3. **Better Documentation**
   - Centralized README
   - Clear usage examples

4. **Consistent Configuration**
   - Standardized naming
   - Unified networking

5. **Easier Onboarding**
   - New developers have single repo to clone
   - Clear setup instructions

## Next Steps

After successful migration:

1. Update team documentation to reference new infrastructure location
2. Update CI/CD pipelines to use new registry port (5001)
3. Archive old infrastructure directories
4. Update any automation scripts that reference old paths
5. Test complete workflow end-to-end

## Questions?

If you encounter issues during migration, check:
1. `macula-gitops/infrastructure/README.md` - Detailed infrastructure docs
2. `macula-gitops/README.md` - Overall workflow
3. `macula-gitops/infrastructure/docker-compose.yml` - Service configuration
