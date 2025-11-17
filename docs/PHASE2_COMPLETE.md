# Phase 2 Complete: Observability Stack & Development Tools

Phase 2 of the Macula GitOps infrastructure is now complete with full observability and developer collaboration tools.

## What's Been Added

### Observability Stack

✅ **Prometheus** - http://prometheus.macula.local
- Metrics collection and time-series database
- Configured to scrape infrastructure services
- Ready for KinD cluster metrics
- Docker IP: 172.23.0.20:9090
- Loopback IP: 127.0.0.3:9090

✅ **Grafana** - http://grafana.macula.local
- Unified dashboards for metrics, logs, and traces
- Pre-configured datasources (Prometheus, Loki, Tempo)
- Login: admin / admin (default)
- Docker IP: 172.23.0.21:3000
- Loopback IP: 127.0.0.4:3000

✅ **Loki** - http://loki.macula.local
- Log aggregation with LogQL query language
- Lightweight, Grafana-native integration
- Ready for Promtail agents
- Docker IP: 172.23.0.22:3100
- Loopback IP: 127.0.0.5:3100

✅ **Tempo** - http://tempo.macula.local
- Distributed tracing with TraceQL
- OTLP receivers (gRPC: 4317, HTTP: 4318)
- Metrics generation to Prometheus
- Docker IP: 172.23.0.23:3200
- Loopback IP: 127.0.0.6:3200

### Development Tools

✅ **Excalidraw** - http://draw.macula.local
- Collaborative whiteboarding
- Perfect for architecture diagrams
- Self-hosted, no external dependencies
- Docker IP: 172.23.0.24:80
- Loopback IP: 127.0.0.7:80

## Configuration Files Created

### Prometheus
- `infrastructure/config/prometheus/prometheus.yml`
  - Scrapes infrastructure services
  - Scrapes observability stack
  - Ready for Docker and KinD metrics
  - 15s scrape interval

### Grafana
- `infrastructure/config/grafana/provisioning/datasources/datasources.yml`
  - Prometheus (default datasource)
  - Loki with trace ID linking
  - Tempo with logs linking
  - Service map and node graph enabled

### Loki
- `infrastructure/config/loki/loki-config.yml`
  - Filesystem storage
  - BoltDB shipper
  - Ready for log ingestion

### Tempo
- `infrastructure/config/tempo/tempo.yml`
  - Multiple receiver protocols (OTLP, Jaeger, Zipkin)
  - Metrics generator with service graphs
  - Remote write to Prometheus

## Infrastructure Updates

### Docker Compose
✅ Added 5 new services to `infrastructure/docker-compose.yml`:
- prometheus (with volumes and health checks)
- grafana (with provisioning)
- loki (with persistent storage)
- tempo (with OTLP receivers)
- excalidraw (lightweight, no database)

✅ Created 4 new volumes:
- prometheus-data
- grafana-data
- loki-data
- tempo-data

### Nginx Ingress
✅ Updated `infrastructure/config/nginx/ingress.conf`:
- Added 5 upstream definitions
- Added 5 server blocks for host-based routing
- Added health check endpoints
- WebSocket support for Excalidraw

### DNS Configuration
✅ Updated `infrastructure/setup-dnsmasq.sh`:
- prometheus.macula.local → 127.0.0.3
- grafana.macula.local → 127.0.0.4
- loki.macula.local → 127.0.0.5
- tempo.macula.local → 127.0.0.6
- draw.macula.local → 127.0.0.7

### Port Forwarding
✅ Updated `scripts/setup-port-forwarding.sh`:
- Added forwarding for all 5 services
- Organized by service tier (Observability, Tools)
- Ready for Phase 3 data services (commented)

### LAN Exposure
✅ Updated `infrastructure/docker-compose.lan.yml`:
- Exposed Prometheus on 0.0.0.0:9090
- Exposed Grafana on 0.0.0.0:3000
- Exposed Loki on 0.0.0.0:3100
- Exposed Tempo on 0.0.0.0:3200, 4317, 4318
- Exposed Excalidraw on 0.0.0.0:8888

### Firewall Configuration
✅ Updated `infrastructure/setup-firewall.sh`:
- Added ports for all observability services
- Added port 8888 for Excalidraw
- Ready for beam cluster access

### Testing
✅ Updated `scripts/health-check.sh`:
- Added checks for all 5 new services
- Validates HTTP accessibility
- Fast validation for development

✅ Updated `scripts/test-infrastructure.sh`:
- Docker service status checks
- DNS resolution validation
- HTTP endpoint testing
- Health endpoint verification

## How to Use Phase 2

### Start Infrastructure with Phase 2

```bash
cd infrastructure

# First time: Update DNS configuration
sudo ./setup-dnsmasq.sh

# Stop old infrastructure (if running)
docker compose down

# Start with Phase 2 services
./start-infrastructure.sh

# Verify all services
docker compose ps
```

### Test Phase 2

```bash
cd scripts

# Quick health check
./health-check.sh

# Comprehensive tests
./test-infrastructure.sh
```

### Access Services

**Observability:**
```bash
# Prometheus
open http://prometheus.macula.local

# Grafana (admin/admin)
open http://grafana.macula.local

# Loki
curl http://loki.macula.local/ready

# Tempo
curl http://tempo.macula.local/ready
```

**Development Tools:**
```bash
# Excalidraw
open http://draw.macula.local
```

### Port Forwarding Setup

```bash
cd scripts

# Start port forwarding for Phase 2 services
./setup-port-forwarding.sh start

# Check status
./setup-port-forwarding.sh status

# Stop if needed
./setup-port-forwarding.sh stop
```

### LAN Mode (Share with Beam Clusters)

```bash
cd infrastructure

# Start in LAN mode
./start-infrastructure.sh --lan

# Configure firewall (one-time)
sudo ./setup-firewall.sh
```

## Integration Examples

### Sending Metrics to Prometheus

From application or cluster:
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'my-app'
    static_configs:
      - targets: ['prometheus.macula.local:9090']
```

### Sending Logs to Loki

Using Promtail:
```yaml
clients:
  - url: http://loki.macula.local:3100/loki/api/v1/push
```

### Sending Traces to Tempo

OpenTelemetry configuration:
```yaml
exporters:
  otlp:
    endpoint: tempo.macula.local:4317
    # or HTTP
    endpoint: http://tempo.macula.local:4318
```

### Grafana Dashboards

1. Access Grafana: http://grafana.macula.local
2. Login: admin / admin
3. Datasources are pre-configured:
   - Prometheus (metrics)
   - Loki (logs)
   - Tempo (traces)
4. Create dashboards or import from grafana.com

## What Phase 2 Enables

### Complete Observability
- **Metrics**: Track performance, resources, custom application metrics
- **Logs**: Centralized log aggregation from all services
- **Traces**: Distributed tracing across microservices
- **Unified View**: Single Grafana interface for everything

### Developer Collaboration
- **Excalidraw**: Collaborative architecture diagramming
- **Self-hosted**: No external dependencies or data leakage
- **Team-friendly**: Share diagrams via URLs

### Multi-Cluster Ready
- **Shared Infrastructure**: One observability stack for all clusters
- **LAN Mode**: Beam clusters can send data
- **Centralized**: Monitor KinD + beam00-03 from one place

## File Changes Summary

### New Files Created
```
infrastructure/config/prometheus/prometheus.yml
infrastructure/config/grafana/provisioning/datasources/datasources.yml
infrastructure/config/loki/loki-config.yml
infrastructure/config/tempo/tempo.yml
```

### Modified Files
```
infrastructure/docker-compose.yml          (added 5 services)
infrastructure/config/nginx/ingress.conf   (added 5 server blocks)
infrastructure/setup-dnsmasq.sh           (added 5 DNS entries)
infrastructure/docker-compose.lan.yml     (added 5 LAN exposures)
infrastructure/setup-firewall.sh          (added 6 ports)
scripts/setup-port-forwarding.sh          (added 5 forwards)
scripts/health-check.sh                   (added 5 checks)
scripts/test-infrastructure.sh            (added 5 tests)
```

## Service URLs Quick Reference

| Service | URL | Purpose |
|---------|-----|---------|
| Prometheus | http://prometheus.macula.local | Metrics & queries |
| Grafana | http://grafana.macula.local | Dashboards |
| Loki | http://loki.macula.local | Log queries |
| Tempo | http://tempo.macula.local | Trace queries |
| Excalidraw | http://draw.macula.local | Diagrams |

## Next: Phase 3

Phase 3 will add data services:
- **MinIO**: S3-compatible object storage (for Tempo traces, backups)
- **TimescaleDB**: PostgreSQL with time-series extensions

## Troubleshooting

**Services not starting?**
```bash
cd infrastructure
docker compose logs prometheus
docker compose logs grafana
docker compose logs loki
docker compose logs tempo
docker compose logs excalidraw
```

**DNS not resolving?**
```bash
dig @127.0.0.1 prometheus.macula.local
dig @127.0.0.1 grafana.macula.local

# Re-run DNS setup if needed
cd infrastructure
sudo ./setup-dnsmasq.sh
```

**Can't access Grafana?**
```bash
# Check service
curl http://grafana.macula.local/api/health

# Check port forwarding
cd scripts
./setup-port-forwarding.sh status

# Restart if needed
./setup-port-forwarding.sh restart
```

**Grafana datasources not working?**
- Check that Prometheus, Loki, Tempo are running
- Verify network connectivity between containers
- Check Grafana logs: `docker compose logs grafana`

## Summary

Phase 2 delivers a **production-ready observability stack** with:

✅ Complete observability (metrics + logs + traces)
✅ Unified Grafana dashboards
✅ Collaborative diagramming tool
✅ Multi-cluster support
✅ LAN exposure for beam clusters
✅ Comprehensive testing

**Phase 2 is ready for use!**

Access your new services at:
- http://prometheus.macula.local
- http://grafana.macula.local (admin/admin)
- http://loki.macula.local
- http://tempo.macula.local
- http://draw.macula.local
