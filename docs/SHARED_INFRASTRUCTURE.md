# Shared Infrastructure Architecture

## Overview

Yes! The infrastructure running in Docker Compose on your workstation can be shared between:
- **Local KinD clusters** (on your workstation)
- **Remote k3s clusters** (on beam00-03.lab)

This creates a unified infrastructure layer serving multiple Kubernetes clusters.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Workstation (192.168.1.x)                                      │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  Infrastructure Services (Docker Compose)                 │ │
│  │  ┌─────────────┬──────────────┬────────────┬────────────┐ │ │
│  │  │ Registry    │ PowerDNS     │ Prometheus │ Grafana    │ │ │
│  │  │ MinIO       │ TimescaleDB  │ Loki       │ Tempo      │ │ │
│  │  └─────────────┴──────────────┴────────────┴────────────┘ │ │
│  │                                                             │ │
│  │  Exposed on: 192.168.1.x (LAN IP)                          │ │
│  └───────────────────────────────────────────────────────────┘ │
│                          ▲            ▲                          │
│                          │            │                          │
│  ┌───────────────────────┘            │                          │
│  │  Local KinD Cluster                │                          │
│  │  ├─ console.macula.local           │                          │
│  │  ├─ bootstrap.macula.local         │                          │
│  │  └─ ExternalDNS → PowerDNS         │                          │
│  └────────────────────────────────────┘                          │
└─────────────────────────────────────────────────────────────────┘
                                             │
                    ┌────────────────────────┼────────────────┐
                    │                        │                │
                    ▼                        ▼                ▼
        ┌───────────────────┐   ┌───────────────────┐   ┌───────────────────┐
        │ beam00.lab        │   │ beam01.lab        │   │ beam02-03.lab     │
        │ (192.168.1.10)    │   │ (192.168.1.11)    │   │                   │
        │                   │   │                   │   │                   │
        │ k3s control plane │   │ k3s worker        │   │ k3s workers       │
        │                   │   │                   │   │                   │
        │ ├─ Applications   │   │ ├─ Applications   │   │ ├─ Applications   │
        │ └─ ExternalDNS ───┼───┴─┘                 │   │                   │
        │       │           │                       │   │                   │
        └───────┼───────────┘   └───────────────────┘   └───────────────────┘
                │
                └──> PowerDNS on workstation (192.168.1.x)
```

## Benefits

### ✅ Unified Management
- Single infrastructure instance to manage
- Consistent configuration across all clusters
- Centralized monitoring and logging

### ✅ Resource Efficiency
- No need to run infrastructure on each beam node
- Beam nodes focus on application workloads
- Workstation resources utilized efficiently

### ✅ Development/Production Parity
- Same infrastructure for dev (KinD) and "production" (beam cluster)
- Test infrastructure changes safely on KinD first
- Promotes infrastructure as code

### ✅ Centralized Observability
- All clusters report to same Prometheus
- Unified Grafana dashboards
- Single Loki instance for all logs
- Tempo traces from all clusters

### ✅ Shared Data Layer
- Common MinIO for backups and artifacts
- Shared TimescaleDB for cross-cluster data
- Single Docker registry for all clusters

## Configuration Changes Required

### 1. Infrastructure Docker Compose (Workstation)

Update `infrastructure/docker-compose.yml` to bind to LAN IP instead of localhost:

```yaml
services:
  # Current: Binds to docker network only
  # Change: Also expose on LAN IP

  nginx-ingress:
    ports:
      - "80:80"                    # Localhost access
      - "192.168.1.x:80:80"        # LAN access (replace x with your IP)
      - "5001:5001"                # Registry legacy port

  prometheus:
    ports:
      - "192.168.1.x:9090:9090"    # Expose on LAN

  grafana:
    ports:
      - "192.168.1.x:3000:3000"    # Expose on LAN

  # ... similar for other services
```

**Better approach:** Use nginx as reverse proxy for all services (already implemented), just expose nginx on LAN:

```yaml
  nginx-ingress:
    ports:
      - "0.0.0.0:80:80"            # Listen on all interfaces
      - "0.0.0.0:5001:5001"        # Registry on all interfaces
```

### 2. DNS Configuration

#### Option A: PowerDNS as LAN DNS (Recommended)

Configure your LAN router to use PowerDNS on your workstation as authoritative DNS for `*.macula.local`:

**Router Configuration:**
```
Forward zone: macula.local
DNS Server: 192.168.1.x (your workstation)
Port: 53
```

**PowerDNS Records:**
```
# Infrastructure (workstation)
registry.macula.local      A  192.168.1.x
prometheus.macula.local    A  192.168.1.x
grafana.macula.local       A  192.168.1.x
...

# beam00 applications (via ExternalDNS)
beam-console.macula.local  A  192.168.1.10
beam-app1.macula.local     A  192.168.1.10
...

# workstation applications (via ExternalDNS)
dev-console.macula.local   A  192.168.1.x
dev-app1.macula.local      A  192.168.1.x
```

**Expose PowerDNS on LAN:**
```yaml
  powerdns:
    ports:
      - "0.0.0.0:53:53/tcp"        # DNS queries from LAN
      - "0.0.0.0:53:53/udp"
      - "0.0.0.0:8081:8081/tcp"    # API for ExternalDNS
```

#### Option B: Split DNS

Keep dnsmasq on workstation for local (127.0.0.x), configure beam nodes to use workstation PowerDNS for infrastructure lookups.

**On each beam node:**
```bash
# /etc/hosts or /etc/dnsmasq.d/macula.conf
server=/macula.local/192.168.1.x
```

### 3. Registry Configuration

#### Workstation KinD Cluster

Already configured to use `kind-registry:5000` (docker network alias).

#### Beam k3s Clusters

Configure each beam node to pull from workstation registry:

**On each beam node (`/etc/rancher/k3s/registries.yaml`):**
```yaml
mirrors:
  "registry.macula.local:5000":
    endpoint:
      - "http://192.168.1.x:5000"
  "registry.macula.local":
    endpoint:
      - "http://192.168.1.x:5000"

configs:
  "192.168.1.x:5000":
    tls:
      insecure_skip_verify: true
```

**Restart k3s:**
```bash
sudo systemctl restart k3s
```

### 4. ExternalDNS Configuration

#### Workstation KinD Cluster

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: kube-system
spec:
  template:
    spec:
      containers:
      - name: external-dns
        image: registry.k8s.io/external-dns/external-dns:v0.14.0
        args:
        - --source=ingress
        - --source=service
        - --domain-filter=macula.local
        - --provider=pdns
        - --pdns-server=http://192.168.1.x:8081  # Your workstation
        - --pdns-api-key=<your-api-key>
        - --txt-prefix=kind-dev-                  # Prefix to identify cluster
```

#### Beam k3s Cluster

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: kube-system
spec:
  template:
    spec:
      containers:
      - name: external-dns
        image: registry.k8s.io/external-dns/external-dns:v0.14.0
        args:
        - --source=ingress
        - --source=service
        - --domain-filter=macula.local
        - --provider=pdns
        - --pdns-server=http://192.168.1.x:8081  # Your workstation
        - --pdns-api-key=<your-api-key>
        - --txt-prefix=beam-                      # Prefix to identify cluster
```

### 5. Observability Configuration

#### Workstation Prometheus

Configure to scrape both local and remote clusters:

**`infrastructure/config/prometheus/prometheus.yml`:**
```yaml
global:
  scrape_interval: 15s

scrape_configs:
  # Infrastructure services (localhost)
  - job_name: 'infrastructure'
    static_configs:
      - targets: ['nginx-ingress:80', 'registry:5000', 'powerdns:8081']

  # KinD cluster (localhost)
  - job_name: 'kind-cluster'
    kubernetes_sd_configs:
      - role: node
        kubeconfig_file: /kubeconfig/kind-macula-dev.yaml
    relabel_configs:
      - source_labels: [__meta_kubernetes_node_name]
        target_label: node

  # beam00 k3s cluster (remote)
  - job_name: 'beam00-cluster'
    kubernetes_sd_configs:
      - role: node
        kubeconfig_file: /kubeconfig/beam00.yaml
        api_server: https://192.168.1.10:6443
    relabel_configs:
      - source_labels: [__meta_kubernetes_node_name]
        target_label: node
      - replacement: beam00
        target_label: cluster

  # beam01-03 k3s clusters (if separate)
  # ...similar configuration
```

**Mount kubeconfigs in docker-compose:**
```yaml
  prometheus:
    volumes:
      - ./config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ~/.kube/beam-clusters:/kubeconfig:ro          # Add this
      - prometheus-data:/prometheus
```

#### Cluster Prometheus (Optional)

Each cluster can also run local Prometheus for redundancy and remote-write to central:

```yaml
# In-cluster Prometheus on beam00
prometheus:
  remoteWrite:
    - url: http://192.168.1.x:9090/api/v1/write
```

### 6. Loki Configuration

Configure applications in all clusters to ship logs to workstation Loki:

**Promtail DaemonSet (in each cluster):**
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: promtail
  namespace: kube-system
spec:
  template:
    spec:
      containers:
      - name: promtail
        image: grafana/promtail:latest
        args:
          - -config.file=/etc/promtail/promtail.yaml
        volumeMounts:
          - name: config
            mountPath: /etc/promtail
          - name: varlog
            mountPath: /var/log
          - name: varlibdockercontainers
            mountPath: /var/lib/docker/containers
            readOnly: true
      volumes:
        - name: config
          configMap:
            name: promtail-config
        - name: varlog
          hostPath:
            path: /var/log
        - name: varlibdockercontainers
          hostPath:
            path: /var/lib/docker/containers
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: kube-system
data:
  promtail.yaml: |
    server:
      http_listen_port: 9080
      grpc_listen_port: 0

    positions:
      filename: /tmp/positions.yaml

    clients:
      - url: http://192.168.1.x:3100/loki/api/v1/push  # Workstation Loki

    scrape_configs:
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace]
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            target_label: pod
          - source_labels: [__meta_kubernetes_node_name]
            target_label: node
```

### 7. Tempo Configuration

Configure applications to send traces to workstation Tempo:

**OTLP Endpoint:** `http://192.168.1.x:4317` (gRPC) or `http://192.168.1.x:4318` (HTTP)

Expose Tempo OTLP ports:
```yaml
  tempo:
    ports:
      - "192.168.1.x:4317:4317"    # OTLP gRPC
      - "192.168.1.x:4318:4318"    # OTLP HTTP
```

### 8. MinIO Configuration

For shared storage across clusters:

```yaml
  minio:
    ports:
      - "0.0.0.0:9000:9000"    # S3 API on all interfaces
      - "0.0.0.0:9001:9001"    # Console on all interfaces
```

**Application access from any cluster:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: minio-credentials
stringData:
  endpoint: http://192.168.1.x:9000
  accessKey: minioadmin
  secretKey: minioadmin
```

### 9. TimescaleDB Configuration

For shared database:

```yaml
  timescaledb:
    ports:
      - "0.0.0.0:5432:5432"    # PostgreSQL on all interfaces
```

**Connection from any cluster:**
```
postgres://postgres:password@192.168.1.x:5432/macula
```

## Security Considerations

### Firewall Rules (Workstation)

Allow incoming connections from beam cluster subnet:

```bash
# Ubuntu/Debian (UFW)
sudo ufw allow from 192.168.1.0/24 to any port 80
sudo ufw allow from 192.168.1.0/24 to any port 53
sudo ufw allow from 192.168.1.0/24 to any port 5000
sudo ufw allow from 192.168.1.0/24 to any port 8081
sudo ufw allow from 192.168.1.0/24 to any port 9090
sudo ufw allow from 192.168.1.0/24 to any port 3000
sudo ufw allow from 192.168.1.0/24 to any port 3100
sudo ufw allow from 192.168.1.0/24 to any port 4317
sudo ufw allow from 192.168.1.0/24 to any port 4318
sudo ufw allow from 192.168.1.0/24 to any port 9000
sudo ufw allow from 192.168.1.0/24 to any port 5432
```

### Authentication

- **PowerDNS API:** Require API key (already configured)
- **Registry:** Consider adding authentication for production
- **Grafana:** Set strong admin password
- **MinIO:** Change default credentials
- **TimescaleDB:** Use strong password, create per-cluster users

### Network Segmentation

Consider using VPN or WireGuard tunnel if workstation is not always on LAN with beam cluster.

## Service Discovery

### Cluster-Specific Prefixes

Use DNS prefixes to identify which cluster a service belongs to:

```
# Workstation KinD cluster
kind-console.macula.local
kind-bootstrap.macula.local

# Beam cluster
beam-console.macula.local
beam-bootstrap.macula.local

# Infrastructure (shared)
registry.macula.local
grafana.macula.local
```

Configure ExternalDNS with `--txt-prefix` to identify owner:
- KinD: `kind-dev-`
- Beam: `beam-`

## Deployment Workflow

### Development Cycle

1. **Develop locally** on KinD cluster
2. **Build and push** to shared registry
3. **Test infrastructure** changes on KinD
4. **Deploy to beam** when ready
5. **Monitor** via shared Grafana

### Infrastructure Updates

1. **Update** `infrastructure/docker-compose.yml`
2. **Restart** infrastructure services
3. **Both clusters** automatically use new infrastructure
4. **Monitor** in Grafana for issues

## Practical Example

### Deploy Application to Both Clusters

```bash
# Build once
cd scripts
./build-and-push.sh
# Pushes to registry.macula.local (workstation)

# Deploy to KinD (local)
kubectl --context kind-macula-dev apply -k apps/console/

# Deploy to beam cluster
kubectl --context beam00 apply -k apps/console/

# Both clusters pull from same registry
# Both show up in same Grafana
# Both logs go to same Loki
# Both traces go to same Tempo
```

### Access Services

```
# Infrastructure (workstation)
http://registry.macula.local
http://grafana.macula.local

# KinD applications (workstation)
http://kind-console.macula.local

# Beam applications (beam cluster)
http://beam-console.macula.local
```

## High Availability Considerations

### Workstation Unavailable

If your workstation is off:
- beam cluster can't pull new images (cache helps)
- beam cluster can't register new DNS (existing works)
- beam cluster can't send metrics/logs (queues locally)

**Mitigation:**
- Keep workstation on when beam cluster is active
- Or migrate infrastructure to beam00 for 24/7 operation
- Or use hybrid: critical services on beam00, dev tools on workstation

### Recommendation

For production-like beam cluster: Run infrastructure on **beam00** instead of workstation, but use same docker-compose configuration.

## Migration Path

### Current State
- Infrastructure on workstation (localhost only)
- KinD cluster on workstation

### Phase 1 (Immediate)
- Expose infrastructure on LAN (0.0.0.0)
- Configure firewall rules
- Keep both clusters using it

### Phase 2 (Optional)
- Move infrastructure to beam00
- Keep same configuration
- Workstation uses beam00 infrastructure

### Phase 3 (Production)
- Split infrastructure:
  - Dev tools (Grafana, etc.) on workstation
  - Critical services (Registry, DNS) on beam00

## Summary

**Yes, you can absolutely share infrastructure!**

**Minimal changes required:**
1. Bind Docker Compose services to `0.0.0.0` instead of localhost
2. Configure k3s on beam nodes to use workstation registry
3. Point ExternalDNS in both clusters to workstation PowerDNS
4. Configure observability agents to send to workstation
5. Set up firewall rules

**Benefits:**
- Single source of truth
- Unified observability
- Resource efficiency
- Development/production parity

**Next Step:**
Create `infrastructure/docker-compose.prod.yml` with LAN-exposed ports?
