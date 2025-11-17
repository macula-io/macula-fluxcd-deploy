# Implementation Plan - Complete Infrastructure

## Overview

Implementing complete infrastructure setup with:
- ✅ **Current:** Registry, PowerDNS, Host Nginx
- 🔄 **Phase 1:** Dnsmasq + KinD ingress separation
- 📊 **Phase 2:** Observability stack (Prometheus, Grafana, Loki, Tempo)
- 💾 **Phase 3:** Data services (MinIO, TimescaleDB)

---

## Phase 1: DNS and Ingress Separation (Immediate)

### Objective
Separate infrastructure (host) and application (KinD) ingress using dnsmasq with multiple loopback IPs.

### IP Allocation

```
127.0.0.1    → Host Nginx (infrastructure)
127.0.0.2    → KinD Ingress (applications)
127.0.0.3-5  → Observability (Grafana, Loki, Tempo)
127.0.0.6    → TimescaleDB
127.0.0.7    → MinIO
127.0.0.8+   → Reserved for future services
```

### DNS Configuration

**Service DNS Mapping:**

| Service | DNS | IP | Port |
|---------|-----|-----|------|
| **Infrastructure** | | | |
| Registry UI | registry.macula.local | 127.0.0.1 | 80 |
| Registry API | registry.macula.local/v2/ | 127.0.0.1 | 80 |
| PowerDNS API | dns.macula.local | 127.0.0.1 | 80 |
| PowerDNS Admin | dns-admin.macula.local | 127.0.0.1 | 80 |
| **Observability** | | | |
| Prometheus | prometheus.macula.local | 127.0.0.3 | 9090 |
| Grafana | grafana.macula.local | 127.0.0.4 | 3000 |
| Loki | loki.macula.local | 127.0.0.5 | 3100 |
| Tempo | tempo.macula.local | 127.0.0.6 | 3200 |
| **Data Services** | | | |
| TimescaleDB | postgres.macula.local | 127.0.0.7 | 5432 |
| MinIO | s3.macula.local | 127.0.0.8 | 9000 |
| MinIO Console | s3-console.macula.local | 127.0.0.8 | 9001 |
| **Applications** | | | |
| Console | console.macula.local | 127.0.0.2 | 80 |
| Bootstrap | bootstrap.macula.local | 127.0.0.2 | 80 |
| Arcade Peer 1 | peer1.macula.local | 127.0.0.2 | 80 |
| Arcade Peer 2 | peer2.macula.local | 127.0.0.2 | 80 |

### Tasks

#### 1.1 Create dnsmasq setup script

**File:** `infrastructure/setup-dnsmasq.sh`

```bash
#!/usr/bin/env bash
# Install and configure dnsmasq for *.macula.local wildcard DNS

# Install dnsmasq
if command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y dnsmasq
elif command -v brew &> /dev/null; then
    brew install dnsmasq
fi

# Configure dnsmasq for wildcard DNS
sudo mkdir -p /etc/dnsmasq.d
cat <<EOF | sudo tee /etc/dnsmasq.d/macula.conf
# Infrastructure services (host nginx)
address=/registry.macula.local/127.0.0.1
address=/dns.macula.local/127.0.0.1
address=/dns-admin.macula.local/127.0.0.1

# Application services (KinD cluster)
address=/console.macula.local/127.0.0.2
address=/bootstrap.macula.local/127.0.0.2
address=/peer1.macula.local/127.0.0.2
address=/peer2.macula.local/127.0.0.2

# Observability stack
address=/prometheus.macula.local/127.0.0.3
address=/grafana.macula.local/127.0.0.4
address=/loki.macula.local/127.0.0.5
address=/tempo.macula.local/127.0.0.6

# Data services
address=/postgres.macula.local/127.0.0.7
address=/s3.macula.local/127.0.0.8
address=/s3-console.macula.local/127.0.0.8
EOF

# Restart dnsmasq
sudo systemctl restart dnsmasq

# Configure NetworkManager to use dnsmasq
echo "Configure your system to use 127.0.0.1 as nameserver"
```

#### 1.2 Update KinD cluster configuration

**File:** `scripts/setup-cluster.sh`

Update port mappings to avoid conflict:

```yaml
extraPortMappings:
- containerPort: 80
  hostPort: 8080      # Changed from 80 → bind to 127.0.0.2:80 via socat
- containerPort: 443
  hostPort: 8443      # Changed from 443 → bind to 127.0.0.2:443 via socat
- containerPort: 4433
  hostPort: 4433
  protocol: UDP
```

#### 1.3 Create IP forwarding for KinD

**File:** `scripts/setup-kind-routing.sh`

```bash
#!/usr/bin/env bash
# Forward 127.0.0.2:80 → 127.0.0.1:8080 (KinD ingress)

# Using socat for port forwarding
socat TCP-LISTEN:80,bind=127.0.0.2,reuseaddr,fork TCP:127.0.0.1:8080 &
socat TCP-LISTEN:443,bind=127.0.0.2,reuseaddr,fork TCP:127.0.0.1:8443 &

echo "KinD routing configured"
```

#### 1.4 Deploy nginx-ingress-controller to KinD

**File:** `apps/nginx-ingress/deployment.yaml`

```yaml
# Use official nginx-ingress-controller for KinD
# Deploy via kubectl or Flux
```

---

## Phase 2: Observability Stack

### Objective
Add Prometheus, Grafana, Loki, and Tempo for complete observability.

### 2.1 Add services to docker-compose.yml

**File:** `infrastructure/docker-compose.yml`

```yaml
services:
  # ... existing services ...

  # Prometheus - Metrics
  prometheus:
    image: prom/prometheus:latest
    container_name: macula-prometheus
    restart: unless-stopped
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'
    volumes:
      - ./config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    networks:
      macula-infra:
        ipv4_address: 172.23.0.20
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:9090/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Grafana - Dashboards
  grafana:
    image: grafana/grafana:latest
    container_name: macula-grafana
    restart: unless-stopped
    environment:
      GF_SERVER_ROOT_URL: http://grafana.macula.local
      GF_AUTH_ANONYMOUS_ENABLED: "true"
      GF_AUTH_ANONYMOUS_ORG_ROLE: "Admin"
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD:-admin}
    volumes:
      - grafana-data:/var/lib/grafana
      - ./config/grafana/provisioning:/etc/grafana/provisioning:ro
    networks:
      macula-infra:
        ipv4_address: 172.23.0.21
    depends_on:
      - prometheus
      - loki
      - tempo
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Loki - Logs
  loki:
    image: grafana/loki:latest
    container_name: macula-loki
    restart: unless-stopped
    command: -config.file=/etc/loki/local-config.yaml
    volumes:
      - ./config/loki/loki.yml:/etc/loki/local-config.yaml:ro
      - loki-data:/loki
    networks:
      macula-infra:
        ipv4_address: 172.23.0.22
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3100/ready"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Tempo - Traces
  tempo:
    image: grafana/tempo:latest
    container_name: macula-tempo
    restart: unless-stopped
    command: ["-config.file=/etc/tempo/tempo.yml"]
    volumes:
      - ./config/tempo/tempo.yml:/etc/tempo/tempo.yml:ro
      - tempo-data:/tmp/tempo
    networks:
      macula-infra:
        ipv4_address: 172.23.0.23
    depends_on:
      - minio
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3200/ready"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  prometheus-data:
  grafana-data:
  loki-data:
  tempo-data:
```

### 2.2 Create configuration files

**Prometheus:** `infrastructure/config/prometheus/prometheus.yml`
**Grafana datasources:** `infrastructure/config/grafana/provisioning/datasources/`
**Loki:** `infrastructure/config/loki/loki.yml`
**Tempo:** `infrastructure/config/tempo/tempo.yml`

### 2.3 Create forwarding for observability services

**File:** `scripts/setup-observability-routing.sh`

```bash
#!/usr/bin/env bash
# Forward observability services to their dedicated IPs

socat TCP-LISTEN:9090,bind=127.0.0.3,reuseaddr,fork TCP:172.23.0.20:9090 &  # Prometheus
socat TCP-LISTEN:3000,bind=127.0.0.4,reuseaddr,fork TCP:172.23.0.21:3000 &  # Grafana
socat TCP-LISTEN:3100,bind=127.0.0.5,reuseaddr,fork TCP:172.23.0.22:3100 &  # Loki
socat TCP-LISTEN:3200,bind=127.0.0.6,reuseaddr,fork TCP:172.23.0.23:3200 &  # Tempo

echo "Observability routing configured"
```

---

## Phase 3: Data Services

### Objective
Add MinIO (S3) and TimescaleDB (PostgreSQL) for shared storage and database.

### 3.1 Add services to docker-compose.yml

```yaml
services:
  # ... existing services ...

  # MinIO - S3-compatible object storage
  minio:
    image: minio/minio:latest
    container_name: macula-minio
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER:-minioadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD:-minioadmin}
    volumes:
      - minio-data:/data
    networks:
      macula-infra:
        ipv4_address: 172.23.0.30
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 10s
      retries: 3

  # TimescaleDB - PostgreSQL with time-series
  timescaledb:
    image: timescale/timescaledb:latest-pg16
    container_name: macula-timescaledb
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
      POSTGRES_DB: ${POSTGRES_DB:-macula}
    volumes:
      - timescaledb-data:/var/lib/postgresql/data
      - ./config/timescaledb/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    networks:
      macula-infra:
        ipv4_address: 172.23.0.31
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  minio-data:
  timescaledb-data:
```

### 3.2 Create port forwarding

**File:** `scripts/setup-data-routing.sh`

```bash
#!/usr/bin/env bash
# Forward data services to their dedicated IPs

socat TCP-LISTEN:5432,bind=127.0.0.7,reuseaddr,fork TCP:172.23.0.31:5432 &  # TimescaleDB
socat TCP-LISTEN:9000,bind=127.0.0.8,reuseaddr,fork TCP:172.23.0.30:9000 &  # MinIO API
socat TCP-LISTEN:9001,bind=127.0.0.8,reuseaddr,fork TCP:172.23.0.30:9001 &  # MinIO Console

echo "Data services routing configured"
```

---

## Complete Workflow

### Initial Setup

```bash
# 1. Install dnsmasq
cd infrastructure
./setup-dnsmasq.sh

# 2. Start all infrastructure services
./start-infrastructure.sh

# 3. Setup port forwarding for all services
cd ../scripts
./setup-observability-routing.sh
./setup-data-routing.sh
./setup-kind-routing.sh

# 4. Create KinD cluster
./setup-cluster.sh

# 5. Deploy nginx-ingress to KinD
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# 6. Build and push images
./build-and-push.sh

# 7. Deploy applications
kubectl apply -k ../apps/
```

### Access Services

**Infrastructure:**
- http://registry.macula.local
- http://dns-admin.macula.local

**Observability:**
- http://prometheus.macula.local
- http://grafana.macula.local
- http://loki.macula.local (API only)
- http://tempo.macula.local (API only)

**Data:**
- postgres://postgres.macula.local:5432
- http://s3.macula.local (MinIO API)
- http://s3-console.macula.local (MinIO UI)

**Applications:**
- http://console.macula.local
- http://bootstrap.macula.local
- http://peer1.macula.local
- http://peer2.macula.local

---

## File Structure

```
macula-gitops/
├── infrastructure/
│   ├── docker-compose.yml               # All infrastructure services
│   ├── config/
│   │   ├── nginx/
│   │   │   └── ingress.conf
│   │   ├── prometheus/
│   │   │   └── prometheus.yml
│   │   ├── grafana/
│   │   │   └── provisioning/
│   │   ├── loki/
│   │   │   └── loki.yml
│   │   ├── tempo/
│   │   │   └── tempo.yml
│   │   ├── timescaledb/
│   │   │   └── init.sql
│   │   └── powerdns/
│   │       ├── pdns.conf
│   │       └── init-schema.sql
│   ├── setup-dnsmasq.sh
│   ├── start-infrastructure.sh
│   └── stop-infrastructure.sh
│
├── scripts/
│   ├── setup-hosts.sh                   # Deprecated (use dnsmasq)
│   ├── setup-cluster.sh                 # Updated for new port mappings
│   ├── setup-kind-routing.sh            # Port forwarding for KinD
│   ├── setup-observability-routing.sh   # Port forwarding for observability
│   ├── setup-data-routing.sh            # Port forwarding for data services
│   └── build-and-push.sh
│
└── apps/
    ├── nginx-ingress/                   # KinD nginx-ingress-controller
    ├── bootstrap/
    ├── console/
    └── arcade/
```

---

## Next Steps

1. **Implement Phase 1** (DNS + KinD ingress separation)
2. **Test end-to-end** (infrastructure + applications)
3. **Implement Phase 2** (Observability stack)
4. **Implement Phase 3** (Data services)
5. **Document** complete setup guide
6. **Create** systemd services for port forwarding
