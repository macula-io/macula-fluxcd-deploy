# Architecture Decisions - Infrastructure vs Cluster Services

## Key Decision: Ingress Architecture

### Option 1: Dual Ingress (Recommended)

**Host Nginx (Docker Compose)** - Infrastructure services only
- Docker Registry: `registry.macula.local`
- PowerDNS API: `dns.macula.local`
- PowerDNS Admin: `dns-admin.macula.local`
- Monitoring/observability UIs (Prometheus, Grafana, etc.)

**KinD Nginx Ingress Controller** - Application services
- Console: `console.macula.local`
- Bootstrap: `bootstrap.macula.local`
- Arcade peers: `peer1.macula.local`, `peer2.macula.local`
- All other Macula application services

**Rationale:**
- ✅ Clear separation: infrastructure vs applications
- ✅ Infrastructure survives cluster recreation
- ✅ Each can be upgraded independently
- ✅ Different security/auth policies
- ✅ Infrastructure accessible even if cluster is down

**Port Mapping:**
```
Host Nginx (Docker Compose):
  - Port 80 → Infrastructure services (via host-based routing)
  - Port 5001 → Registry (legacy/direct access)

KinD Nginx Ingress:
  - Port 8080 → Application services (mapped from KinD port 80)
  - Port 8443 → Application services TLS (mapped from KinD port 443)
  - Port 4433/UDP → QUIC (Bootstrap service)
```

### Option 2: Single Ingress (Not Recommended)

Use Docker Compose nginx as ingress for both infrastructure AND KinD services.

**Problems:**
- ❌ Tight coupling between host and cluster
- ❌ Harder to manage routing rules
- ❌ No native Kubernetes Ingress resources
- ❌ Manual service discovery
- ❌ Can't use standard Kubernetes patterns

---

## Recommended Infrastructure Services (Outside KinD)

### Tier 1: Essential Infrastructure (Already Implemented)

1. **Docker Registry** ✅
   - Why outside: KinD needs it to pull images
   - Current: `registry.macula.local`

2. **PowerDNS** ✅
   - Why outside: Manages DNS for multiple clusters
   - ExternalDNS in each cluster connects to it
   - Current: `dns.macula.local`, `dns-admin.macula.local`

3. **Host Nginx Ingress** ✅
   - Why outside: Entry point for all infrastructure
   - Current: Routes infrastructure services

### Tier 2: Observability Stack (Recommended to Add)

**Modern Observability Stack - The Three Pillars:**

4. **Prometheus** (Host instance)
   - Why outside: Monitors infrastructure + all clusters
   - Scrapes metrics from host services and KinD services
   - Survives cluster recreation
   - URL: `prometheus.macula.local` → 127.0.0.1:9090
   - Cluster instances can remote-write to it

5. **Grafana**
   - Why outside: Unified dashboards for all environments
   - Connects to Prometheus, Loki, Tempo
   - Persisted dashboards and data sources
   - URL: `grafana.macula.local` → 127.0.0.2:3000
   - Native support for all three backends

6. **Loki** (Logs)
   - Why outside: Centralized logging aggregation
   - Clusters ship logs via promtail/fluentd
   - URL: `loki.macula.local` → 127.0.0.3:3100
   - Much lighter than ELK stack
   - Native Grafana integration

7. **Tempo** (Traces)
   - Why outside: Distributed tracing for microservices
   - Essential for debugging distributed systems
   - URL: `tempo.macula.local` → 127.0.0.4:3200
   - OTLP, Jaeger, Zipkin compatible
   - Stores traces in object storage (MinIO)
   - **Modern alternative to Jaeger** - simpler, S3-backed

**Why Tempo over Jaeger:**
- ✅ No index database needed (uses object storage)
- ✅ Native Grafana integration (same company)
- ✅ TraceQL query language (like LogQL/PromQL)
- ✅ Lower resource usage
- ✅ Simpler deployment
- ✅ Better for high-cardinality traces
- ❌ Jaeger has more mature UI (but Grafana is catching up)

**Alternative: Jaeger (if preferred)**
- More mature ecosystem
- Better standalone UI
- Cassandra/Elasticsearch backend
- URL: `jaeger.macula.local` → 127.0.0.4:16686

**Decision:** Use **Tempo** (modern, lightweight, Grafana-native)

6. **Excalidraw** (Collaborative whiteboarding) ✅ APPROVED
   - Why outside: Shared diagramming tool for team collaboration
   - Architecture diagrams, system design, technical discussions
   - Self-hosted alternative to Excalidraw.com
   - URL: `draw.macula.local` → 127.0.0.7:80
   - No database required (stores in browser/local storage)
   - Perfect for documenting Macula architecture

### Tier 3: Data Services (Essential)

7. **MinIO** (S3-compatible object storage) ✅ APPROVED
   - Why outside: Shared storage across clusters
   - Tempo trace storage backend
   - Backups, artifacts, data lakes
   - URL: `s3.macula.local` → 127.0.0.5:9000
   - Console: `s3-console.macula.local` → 127.0.0.5:9001

8. **TimescaleDB** (PostgreSQL with time-series) ✅ APPROVED
   - Why outside: Shared database for multiple clusters/apps
   - Time-series optimized (perfect for metrics/events)
   - Survives cluster recreation
   - URL: `postgres.macula.local` → 127.0.0.6:5432
   - Built on PostgreSQL (familiar, standard tools)
   - Excellent for event-sourced applications

**Services NOT included:**

9. ~~**Redis**~~ ❌ NOT INCLUDED
   - Not needed for current architecture
   - Apps can use in-cluster Redis if required

10. ~~**Gitea/GitLab**~~ ❌ NOT INCLUDED
    - Use GitHub for GitOps source
    - Avoid unnecessary infrastructure

### Tier 4: CI/CD (Optional)

11. **Tekton Dashboard** or **ArgoCD**
    - Why outside: Manages deployments to multiple clusters
    - URL: `cicd.macula.local`
    - Alternative: Run in KinD if single cluster

---

## Proposed Architecture

### Network Architecture

```
                    ┌─────────────────────────────────────┐
                    │  Host Machine (127.0.0.1)           │
                    │                                     │
                    │  ┌────────────────────────────────┐ │
                    │  │  /etc/hosts                    │ │
                    │  │  127.0.0.1 *.macula.local      │ │
                    │  └────────────────────────────────┘ │
                    │                                     │
                    │  Port 80 ↓                          │
┌───────────────────┼──────────────────────────────────────┼───────────────────┐
│                   │                                     │                   │
│  ┌────────────────▼──────────────────────────────────┐  │                   │
│  │  Host Nginx Ingress (Docker Compose)             │  │                   │
│  │  - registry.macula.local                         │  │                   │
│  │  - dns.macula.local                              │  │                   │
│  │  - dns-admin.macula.local                        │  │                   │
│  │  - prometheus.macula.local     (proposed)        │  │                   │
│  │  - grafana.macula.local        (proposed)        │  │                   │
│  │  - s3.macula.local             (proposed)        │  │                   │
│  └──────────────────────────────────────────────────┘  │                   │
│                                                         │                   │
│  ┌──────────────────────────────────────────────────┐  │                   │
│  │  Infrastructure Services (Docker Compose)        │  │                   │
│  │  ├─ Registry + UI                                │  │                   │
│  │  ├─ PowerDNS + PostgreSQL + Admin               │  │                   │
│  │  ├─ Prometheus (proposed)                        │  │                   │
│  │  ├─ Grafana (proposed)                           │  │                   │
│  │  └─ MinIO (proposed)                             │  │                   │
│  └──────────────────────────────────────────────────┘  │                   │
│                                                         │                   │
└─────────────────────────────────────────────────────────┘                   │
                                                                              │
                    Port 8080 ↓                                               │
┌─────────────────────────────────────────────────────────────────────────────┤
│  KinD Cluster (macula-dev)                                                  │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  Nginx Ingress Controller (in cluster)                               │  │
│  │  - console.macula.local                                               │  │
│  │  - bootstrap.macula.local                                             │  │
│  │  - peer1.macula.local, peer2.macula.local                             │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  Application Services (Kubernetes)                                    │  │
│  │  ├─ macula-console (Phoenix LiveView)                                 │  │
│  │  ├─ macula-bootstrap (DHT bootstrap)                                  │  │
│  │  ├─ macula-arcade (Game peers)                                        │  │
│  │  └─ PostgreSQL (per-app)                                              │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  Cluster Services                                                     │  │
│  │  ├─ ExternalDNS → connects to dns.macula.local:80                     │  │
│  │  ├─ Prometheus (cluster instance) → remote-writes to host Prometheus │  │
│  │  └─ Flux (optional) → pulls from git.macula.local                     │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Port Mapping Strategy

| Port | Service | Purpose |
|------|---------|---------|
| **80** | Host Nginx | Infrastructure services (*.macula.local) |
| **8080** | KinD Ingress | Application services (forwarded from KinD :80) |
| **8443** | KinD Ingress | Application services TLS (forwarded from KinD :443) |
| **5001** | Host Nginx | Registry direct access (backward compat) |
| **4433/UDP** | KinD (direct) | QUIC/Bootstrap (mapped through) |

**DNS Resolution Strategy:**

Option A: **Wildcard /etc/hosts (Simple)**
```bash
127.0.0.1 registry.macula.local dns.macula.local dns-admin.macula.local
127.0.0.1 prometheus.macula.local grafana.macula.local s3.macula.local
127.0.0.1 console.macula.local bootstrap.macula.local
127.0.0.1 peer1.macula.local peer2.macula.local
```

Option B: **Dnsmasq (Clean)**
```bash
# Install dnsmasq
# Add: address=/.macula.local/127.0.0.1
# All *.macula.local automatically resolves to 127.0.0.1
```

---

## Recommended Next Steps

### Phase 1: Current State (Complete ✅)
- Docker Registry with nginx ingress
- PowerDNS with nginx ingress
- KinD cluster with registry connection

### Phase 2: Ingress Separation (Immediate)

1. **Keep host nginx for infrastructure only**
2. **Deploy nginx-ingress-controller in KinD**
3. **Update setup-cluster.sh to:**
   - Map KinD port 80 → host 8080
   - Map KinD port 443 → host 8443
   - Deploy nginx ingress controller in cluster
4. **Update /etc/hosts routing:**
   - Infrastructure: Direct to port 80
   - Applications: Proxy to port 8080

### Phase 3: Add Observability (Recommended)

Add to `infrastructure/docker-compose.yml`:
- Prometheus
- Grafana
- Loki (optional)

### Phase 4: Optional Enhancements
- MinIO for object storage
- Shared PostgreSQL instance
- Redis for caching
- Gitea for local git server

---

## Implementation: Ingress Separation

### Required Changes

**1. Update setup-cluster.sh port mappings:**

```yaml
# Current (PORT CONFLICT - both on 80)
extraPortMappings:
- containerPort: 80
  hostPort: 80    # ← CONFLICTS with host nginx

# Proposed (no conflict)
extraPortMappings:
- containerPort: 80
  hostPort: 8080  # KinD apps on 8080
- containerPort: 443
  hostPort: 8443  # KinD TLS on 8443
- containerPort: 4433
  hostPort: 4433
  protocol: UDP
```

**2. Deploy nginx-ingress-controller to KinD:**

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

**3. Create Ingress resources for apps:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: macula-console
spec:
  ingressClassName: nginx
  rules:
  - host: console.macula.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: macula-console
            port:
              number: 4000
```

**4. Update /etc/hosts with port routing:**

Since /etc/hosts doesn't support ports, use either:
- Proxy through host nginx (port-based backend routing)
- Or accept using `console.macula.local:8080` in browser

---

## Decision Required

**Question for you:** How do you want to handle the application ingress?

### Option A: Port-based (Simpler)
- Infrastructure: `http://registry.macula.local` (port 80)
- Applications: `http://console.macula.local:8080` (port 8080)
- Users type port in browser

### Option B: Path-based Proxy (Cleaner URLs)
- Host nginx proxies `/app/*` to KinD
- Infrastructure: `http://macula.local/registry/`
- Applications: `http://macula.local/console/`
- Single port, but path prefixes

### Option C: Port-based with Dnsmasq (Best UX)
- Install dnsmasq on host
- Configure different IPs for different services
- Infrastructure: `http://registry.macula.local` → 127.0.0.1:80
- Applications: `http://console.macula.local` → 127.0.0.2:8080
- Clean URLs, but requires dnsmasq setup

**Which approach do you prefer?**
