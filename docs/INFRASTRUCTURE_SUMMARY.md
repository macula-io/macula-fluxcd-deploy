# Infrastructure Summary - Approved Design

## Final Approved Stack

### ✅ Infrastructure Services (Outside KinD)

**Host Services (Tier 1):**
- Docker Registry + UI
- PowerDNS + PostgreSQL + Admin UI
- Nginx Ingress (infrastructure only)

**Observability Stack (Tier 2):**
- **Prometheus** - Metrics collection and storage
- **Grafana** - Unified visualization (metrics + logs + traces)
- **Loki** - Log aggregation (lightweight, Grafana-native)
- **Tempo** - Distributed tracing (modern, S3-backed, replaces Jaeger)

**Data Services (Tier 3):**
- **MinIO** - S3-compatible object storage (Tempo backend, backups, artifacts)
- **TimescaleDB** - PostgreSQL with time-series extensions (event sourcing, metrics)

### ❌ Services NOT Included

- ~~Redis~~ - Not needed; apps can deploy in-cluster if required
- ~~Gitea/GitLab~~ - Use GitHub for GitOps
- ~~Jaeger~~ - Replaced by Tempo (simpler, lighter, Grafana-native)

---

## DNS Architecture: Dnsmasq with Multiple Loopback IPs

### Why Tempo Instead of Jaeger?

| Feature | Tempo | Jaeger |
|---------|-------|--------|
| Storage | Object storage (MinIO/S3) | Cassandra/Elasticsearch |
| Index | None (S3 native) | Required database |
| Resource Usage | Low | High |
| Grafana Integration | Native (same company) | Third-party |
| Query Language | TraceQL (PromQL-like) | Custom |
| Deployment | Simple (1 service) | Complex (collector, query, etc.) |
| Maturity | Newer (2020) | Mature (2015) |
| **Decision** | ✅ **APPROVED** | ❌ Rejected |

### IP Allocation

```
127.0.0.1    → Host Nginx (infrastructure services)
127.0.0.2    → KinD Ingress (application services)
127.0.0.3    → Prometheus (metrics)
127.0.0.4    → Grafana (dashboards)
127.0.0.5    → Loki (logs)
127.0.0.6    → Tempo (traces)
127.0.0.7    → Excalidraw (whiteboarding)
127.0.0.8    → TimescaleDB (database)
127.0.0.9    → MinIO (object storage)
127.0.0.10+  → Reserved for future services
```

### DNS Configuration via Dnsmasq

**Installation:**
```bash
# Ubuntu/Debian
sudo apt-get install dnsmasq

# macOS
brew install dnsmasq
```

**Configuration:** `/etc/dnsmasq.d/macula.conf`
```
# Infrastructure (127.0.0.1)
address=/registry.macula.local/127.0.0.1
address=/dns.macula.local/127.0.0.1
address=/dns-admin.macula.local/127.0.0.1

# Applications (127.0.0.2)
address=/console.macula.local/127.0.0.2
address=/bootstrap.macula.local/127.0.0.2
address=/peer1.macula.local/127.0.0.2
address=/peer2.macula.local/127.0.0.2

# Observability (127.0.0.3-6)
address=/prometheus.macula.local/127.0.0.3
address=/grafana.macula.local/127.0.0.4
address=/loki.macula.local/127.0.0.5
address=/tempo.macula.local/127.0.0.6

# Tools (127.0.0.7)
address=/draw.macula.local/127.0.0.7

# Data Services (127.0.0.8-9)
address=/postgres.macula.local/127.0.0.8
address=/s3.macula.local/127.0.0.9
address=/s3-console.macula.local/127.0.0.9
```

### Port Forwarding via socat

Each service runs in Docker on its internal IP/port and is forwarded to its dedicated loopback IP:

**Infrastructure (via Host Nginx):**
- Host Nginx listens on 127.0.0.1:80
- Routes to backend services via docker network

**KinD Applications:**
```bash
# KinD ingress listens on 127.0.0.1:8080
# Forward 127.0.0.2:80 → 127.0.0.1:8080
socat TCP-LISTEN:80,bind=127.0.0.2,reuseaddr,fork TCP:127.0.0.1:8080 &
```

**Observability:**
```bash
socat TCP-LISTEN:9090,bind=127.0.0.3,reuseaddr,fork TCP:172.23.0.20:9090 &  # Prometheus
socat TCP-LISTEN:3000,bind=127.0.0.4,reuseaddr,fork TCP:172.23.0.21:3000 &  # Grafana
socat TCP-LISTEN:3100,bind=127.0.0.5,reuseaddr,fork TCP:172.23.0.22:3100 &  # Loki
socat TCP-LISTEN:3200,bind=127.0.0.6,reuseaddr,fork TCP:172.23.0.23:3200 &  # Tempo
```

**Data Services:**
```bash
socat TCP-LISTEN:5432,bind=127.0.0.7,reuseaddr,fork TCP:172.23.0.31:5432 &  # TimescaleDB
socat TCP-LISTEN:9000,bind=127.0.0.8,reuseaddr,fork TCP:172.23.0.30:9000 &  # MinIO API
socat TCP-LISTEN:9001,bind=127.0.0.8,reuseaddr,fork TCP:172.23.0.30:9001 &  # MinIO Console
```

---

## Service Access URLs

### Infrastructure Services

| Service | URL | Purpose |
|---------|-----|---------|
| Registry UI | http://registry.macula.local | Container registry web interface |
| Registry API | http://registry.macula.local/v2/ | Docker push/pull |
| PowerDNS API | http://dns.macula.local | DNS management API |
| PowerDNS Admin | http://dns-admin.macula.local | DNS web console |

### Observability Services

| Service | URL | Purpose |
|---------|-----|---------|
| Prometheus | http://prometheus.macula.local | Metrics query interface |
| Grafana | http://grafana.macula.local | Unified dashboards |
| Loki | http://loki.macula.local | Log query API (use via Grafana) |
| Tempo | http://tempo.macula.local | Trace query API (use via Grafana) |

### Data Services

| Service | URL | Purpose |
|---------|-----|---------|
| TimescaleDB | postgres://postgres.macula.local:5432 | Shared database |
| MinIO API | http://s3.macula.local | S3-compatible API |
| MinIO Console | http://s3-console.macula.local | Object storage UI |

### Application Services

| Service | URL | Purpose |
|---------|-----|---------|
| Console | http://console.macula.local | Macula management UI |
| Bootstrap | http://bootstrap.macula.local | DHT bootstrap node |
| Arcade Peer 1 | http://peer1.macula.local | Demo game peer |
| Arcade Peer 2 | http://peer2.macula.local | Demo game peer |

---

## Architecture Diagram

```
                         Developer Browser
                               |
                    ┌──────────┴──────────┐
                    |                     |
           *.macula.local DNS      127.0.0.x:port
                    |                     |
                dnsmasq               socat forwarding
                    |                     |
         ┌──────────┴──────────┬──────────┴──────────┬─────────────┐
         |                     |                     |             |
    127.0.0.1:80          127.0.0.2:80         127.0.0.3-8      Docker
         |                     |                     |          Network
    Host Nginx           KinD Ingress         Observability   172.23.0.x
         |                     |                  + Data           |
    ┌────┴─────┐          ┌────┴─────┐              |          ┌───┴────┐
    |Infrastructure|      |Applications|         ┌───┴───┐      |Services|
    |                                                             |
    ├─ Registry                                    ├─ Prometheus  ├─ Registry
    ├─ PowerDNS                                    ├─ Grafana     ├─ PowerDNS
    └─ Nginx                                       ├─ Loki        ├─ Prometheus
                                                   ├─ Tempo       ├─ Grafana
                          ├─ Console               ├─ TimescaleDB ├─ Loki
                          ├─ Bootstrap             └─ MinIO       ├─ Tempo
                          ├─ Arcade Peers                         ├─ MinIO
                          └─ Per-app DBs                          └─ TimescaleDB
```

---

## Implementation Phases

### Phase 1: DNS + Ingress Separation ⏳ NEXT

**Goal:** Separate infrastructure and application ingress using dnsmasq

**Tasks:**
1. Create dnsmasq setup script
2. Update KinD cluster configuration (port 8080 instead of 80)
3. Create socat forwarding scripts
4. Deploy nginx-ingress-controller to KinD
5. Test end-to-end routing

**Files:**
- `infrastructure/setup-dnsmasq.sh`
- `scripts/setup-kind-routing.sh`
- `scripts/setup-cluster.sh` (update port mappings)

### Phase 2: Observability Stack 📊 PLANNED

**Goal:** Add Prometheus, Grafana, Loki, Tempo

**Tasks:**
1. Add services to docker-compose.yml
2. Create configuration files for each service
3. Create port forwarding script
4. Configure Grafana datasources
5. Create default dashboards

**Files:**
- `infrastructure/docker-compose.yml` (add services)
- `infrastructure/config/prometheus/prometheus.yml`
- `infrastructure/config/grafana/provisioning/`
- `infrastructure/config/loki/loki.yml`
- `infrastructure/config/tempo/tempo.yml`
- `scripts/setup-observability-routing.sh`

### Phase 3: Data Services 💾 PLANNED

**Goal:** Add MinIO and TimescaleDB

**Tasks:**
1. Add services to docker-compose.yml
2. Create init scripts for TimescaleDB
3. Configure MinIO for Tempo
4. Create port forwarding script
5. Document connection strings

**Files:**
- `infrastructure/docker-compose.yml` (add services)
- `infrastructure/config/timescaledb/init.sql`
- `scripts/setup-data-routing.sh`

---

## Benefits of This Architecture

### Clean URLs
✅ No port numbers in browser
✅ Memorable DNS names
✅ Consistent patterns

### Separation of Concerns
✅ Infrastructure survives cluster recreation
✅ Independent upgrade paths
✅ Different security policies

### Scalability
✅ Easy to add new services (allocate new IP)
✅ Easy to add new clusters (allocate new IP)
✅ No port conflicts

### Observability
✅ Complete metrics, logs, and traces
✅ Unified Grafana dashboards
✅ Modern, lightweight stack (Loki + Tempo)

### Data Persistence
✅ Shared database survives cluster recreation
✅ Object storage for traces and backups
✅ Time-series optimized for events

---

## Next Steps

1. **Review IMPLEMENTATION_PLAN.md** for detailed tasks
2. **Implement Phase 1** (dnsmasq + ingress separation)
3. **Test thoroughly** before proceeding
4. **Document learnings** and update guides
5. **Proceed to Phase 2** (observability)

See `IMPLEMENTATION_PLAN.md` for complete step-by-step instructions.
