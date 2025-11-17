# Phase 2: Observability Stack & Development Tools

## Overview

Phase 2 adds the observability stack and development tools to the infrastructure, providing comprehensive monitoring, logging, tracing, and collaborative diagramming capabilities.

## Services to Add

### Observability Stack

1. **Prometheus** (http://prometheus.macula.local)
   - Metrics collection and storage
   - Scrapes metrics from all infrastructure and cluster services
   - Time-series database with PromQL query language
   - Port: 9090
   - Loopback IP: 127.0.0.3

2. **Grafana** (http://grafana.macula.local)
   - Unified dashboards for metrics, logs, and traces
   - Pre-configured data sources (Prometheus, Loki, Tempo)
   - Custom dashboards for Macula platform
   - Port: 3000
   - Loopback IP: 127.0.0.4

3. **Loki** (http://loki.macula.local)
   - Log aggregation from all services
   - LogQL query language (like PromQL for logs)
   - Lightweight alternative to ELK stack
   - Grafana-native integration
   - Port: 3100
   - Loopback IP: 127.0.0.5

4. **Tempo** (http://tempo.macula.local)
   - Distributed tracing
   - No index database needed (uses MinIO backend)
   - TraceQL query language
   - Grafana-native integration
   - Modern alternative to Jaeger
   - Port: 3200 (HTTP), 4317 (OTLP gRPC), 4318 (OTLP HTTP)
   - Loopback IP: 127.0.0.6

### Development Tools

5. **Excalidraw** (http://draw.macula.local)
   - Self-hosted collaborative whiteboarding
   - Architecture diagrams and system design
   - No database required (browser/local storage)
   - Perfect for documenting Macula architecture
   - Port: 80 (container)
   - Loopback IP: 127.0.0.7
   - Docker image: excalidraw/excalidraw

## Implementation Tasks

### Task 1: Add Services to docker-compose.yml

Add the following services to `infrastructure/docker-compose.yml`:

```yaml
  # Prometheus
  prometheus:
    image: prom/prometheus:latest
    container_name: macula-prometheus
    restart: unless-stopped
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    volumes:
      - ./config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    networks:
      macula-infra:
        ipv4_address: 172.23.0.20

  # Grafana
  grafana:
    image: grafana/grafana:latest
    container_name: macula-grafana
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - ./config/grafana/datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml:ro
      - grafana-data:/var/lib/grafana
    networks:
      macula-infra:
        ipv4_address: 172.23.0.21
    depends_on:
      - prometheus
      - loki
      - tempo

  # Loki
  loki:
    image: grafana/loki:latest
    container_name: macula-loki
    restart: unless-stopped
    command: -config.file=/etc/loki/local-config.yaml
    volumes:
      - ./config/loki/loki-config.yml:/etc/loki/local-config.yaml:ro
      - loki-data:/loki
    networks:
      macula-infra:
        ipv4_address: 172.23.0.22

  # Tempo
  tempo:
    image: grafana/tempo:latest
    container_name: macula-tempo
    restart: unless-stopped
    command: [ "-config.file=/etc/tempo.yaml" ]
    volumes:
      - ./config/tempo/tempo.yml:/etc/tempo.yaml:ro
      - tempo-data:/tmp/tempo
    networks:
      macula-infra:
        ipv4_address: 172.23.0.23

  # Excalidraw
  excalidraw:
    image: excalidraw/excalidraw:latest
    container_name: macula-excalidraw
    restart: unless-stopped
    networks:
      macula-infra:
        ipv4_address: 172.23.0.24

volumes:
  prometheus-data:
  grafana-data:
  loki-data:
  tempo-data:
```

### Task 2: Create Configuration Files

**Prometheus** (`infrastructure/config/prometheus/prometheus.yml`):
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'docker'
    static_configs:
      - targets: ['172.23.0.1:9323']  # Docker daemon metrics

  # Add KinD cluster scraping
  - job_name: 'kind-cluster'
    static_configs:
      - targets: ['172.18.0.2:10250']  # kubelet metrics
```

**Grafana** (`infrastructure/config/grafana/datasources.yml`):
```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100

  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo:3200
```

**Loki** (`infrastructure/config/loki/loki-config.yml`):
```yaml
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2020-05-15
      store: boltdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 168h

storage_config:
  boltdb:
    directory: /loki/index
  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
```

**Tempo** (`infrastructure/config/tempo/tempo.yml`):
```yaml
server:
  http_listen_port: 3200

distributor:
  receivers:
    otlp:
      protocols:
        http:
          endpoint: 0.0.0.0:4318
        grpc:
          endpoint: 0.0.0.0:4317

storage:
  trace:
    backend: local
    local:
      path: /tmp/tempo/blocks
    wal:
      path: /tmp/tempo/wal
```

### Task 3: Update Nginx Ingress Configuration

Add to `infrastructure/config/nginx/ingress.conf`:

```nginx
# Prometheus - prometheus.macula.local
upstream prometheus {
  server 172.23.0.20:9090;
}

server {
  listen 80;
  server_name prometheus.macula.local;

  location / {
    proxy_pass http://prometheus/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }
}

# Grafana - grafana.macula.local
upstream grafana {
  server 172.23.0.21:3000;
}

server {
  listen 80;
  server_name grafana.macula.local;

  location / {
    proxy_pass http://grafana/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }
}

# Loki - loki.macula.local
upstream loki {
  server 172.23.0.22:3100;
}

server {
  listen 80;
  server_name loki.macula.local;

  location / {
    proxy_pass http://loki/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }
}

# Tempo - tempo.macula.local
upstream tempo {
  server 172.23.0.23:3200;
}

server {
  listen 80;
  server_name tempo.macula.local;

  location / {
    proxy_pass http://tempo/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }
}

# Excalidraw - draw.macula.local
upstream excalidraw {
  server 172.23.0.24:80;
}

server {
  listen 80;
  server_name draw.macula.local;

  location / {
    proxy_pass http://excalidraw/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
```

### Task 4: Update Dnsmasq Configuration

Update `infrastructure/setup-dnsmasq.sh` to add:

```bash
# Observability stack (127.0.0.3-6)
address=/prometheus.macula.local/127.0.0.3
address=/grafana.macula.local/127.0.0.4
address=/loki.macula.local/127.0.0.5
address=/tempo.macula.local/127.0.0.6

# Tools (127.0.0.7)
address=/draw.macula.local/127.0.0.7
```

### Task 5: Update Port Forwarding

Update `scripts/setup-port-forwarding.sh` to add:

```bash
# Observability Stack
start_forward "prometheus" "127.0.0.3" "9090" "172.23.0.20" "9090"
start_forward "grafana" "127.0.0.4" "3000" "172.23.0.21" "3000"
start_forward "loki" "127.0.0.5" "3100" "172.23.0.22" "3100"
start_forward "tempo" "127.0.0.6" "3200" "172.23.0.23" "3200"

# Development Tools
start_forward "excalidraw" "127.0.0.7" "80" "172.23.0.24" "80"
```

### Task 6: Update LAN Exposure

Add to `infrastructure/docker-compose.lan.yml`:

```yaml
  prometheus:
    ports:
      - "0.0.0.0:9090:9090"

  grafana:
    ports:
      - "0.0.0.0:3000:3000"

  loki:
    ports:
      - "0.0.0.0:3100:3100"

  tempo:
    ports:
      - "0.0.0.0:3200:3200"
      - "0.0.0.0:4317:4317"
      - "0.0.0.0:4318:4318"

  excalidraw:
    ports:
      - "0.0.0.0:8888:80"  # Different port to avoid conflict
```

### Task 7: Update Firewall Configuration

Add to `infrastructure/setup-firewall.sh`:

```bash
SERVICES=(
    # ... existing services ...
    "9090:tcp:Prometheus"
    "3000:tcp:Grafana"
    "3100:tcp:Loki"
    "3200:tcp:Tempo"
    "4317:tcp:OTLP gRPC"
    "4318:tcp:OTLP HTTP"
    "8888:tcp:Excalidraw"
)
```

### Task 8: Update Test Scripts

Update `scripts/test-infrastructure.sh` to test:
- Prometheus: `http://prometheus.macula.local/-/healthy`
- Grafana: `http://grafana.macula.local/api/health`
- Loki: `http://loki.macula.local/ready`
- Tempo: `http://tempo.macula.local/ready`
- Excalidraw: `http://draw.macula.local/`

Update `scripts/health-check.sh` similarly.

## Testing Phase 2

After implementation:

```bash
# 1. Restart infrastructure with new services
cd infrastructure
docker compose down
./start-infrastructure.sh

# 2. Verify all services are running
docker compose ps

# 3. Run health check
cd ../scripts
./health-check.sh

# 4. Run comprehensive tests
./test-infrastructure.sh

# 5. Access services
open http://prometheus.macula.local
open http://grafana.macula.local (admin/admin)
open http://draw.macula.local
```

## Benefits

### Observability
- **Complete visibility** into infrastructure and applications
- **Unified dashboards** for metrics, logs, and traces
- **Troubleshooting** with correlated data
- **Performance monitoring** and optimization

### Development Tools
- **Collaborative diagramming** for architecture design
- **Self-hosted** - no data leaves your infrastructure
- **Team collaboration** on technical designs

### Shared Infrastructure
- **Centralized monitoring** for both KinD and beam clusters
- **Single pane of glass** for all environments
- **Cost-effective** - one observability stack for all clusters

## Documentation Updates Needed

- [ ] Update README.md with Phase 2 services
- [ ] Update QUICK_START.md with new setup steps
- [ ] Add Grafana dashboard export/import guide
- [ ] Document Prometheus scrape configuration
- [ ] Add log shipping guide for applications
- [ ] Document distributed tracing setup

## Estimated Time

- Docker Compose services: 1 hour
- Configuration files: 1 hour
- Nginx/DNS/Port forwarding: 30 minutes
- Testing and validation: 30 minutes
- Documentation updates: 1 hour

**Total: ~4 hours**

## Next: Phase 3

After Phase 2 is complete, Phase 3 will add:
- MinIO (S3-compatible object storage)
- TimescaleDB (PostgreSQL with time-series)

These will provide data services for:
- Tempo trace storage (MinIO backend)
- Time-series data (TimescaleDB)
- Application storage needs
