# Beam Cluster Deployment Guide

## Overview

This guide covers deploying Macula infrastructure and applications to the physical beam cluster (beam00-03.lab) as documented in the global CLAUDE.md.

## Beam Cluster Hardware

### Physical Nodes

| Node | IP | CPU | RAM | Storage | Role |
|------|---------|-----|-----|---------|------|
| beam00 | 192.168.1.10 | Intel Celeron J4105 | 16GB | 1x 932GB HDD, 1x 224GB NVMe | Control + Infrastructure |
| beam01 | 192.168.1.11 | Intel Celeron J4105 | 32GB | 2x 932GB HDD, 1x 224GB NVMe | Worker |
| beam02 | 192.168.1.12 | Intel Celeron J4105 | 32GB | 2x 932GB HDD, 1x 224GB NVMe | Worker |
| beam03 | 192.168.1.13 | Intel Celeron J4105 | 32GB | 2x 932GB HDD, 1x 932GB NVMe | Worker |

### Storage Layout

**Per Node:**
- `/` (eMMC, ~13GB) - OS only
- `/fast` (NVMe) - k3s system data (via symlink from `/var/lib/rancher/k3s`)
- `/bulk0`, `/bulk1` (HDD) - Application data, persistent volumes

**Important:** All application PersistentVolumes MUST use `/bulk` drives!

## Architecture Differences: Dev vs Beam

### Development Workstation (KinD)

```
Single machine:
  - Docker Compose (infrastructure on host)
  - KinD cluster (applications)
  - Dnsmasq (127.0.0.x routing)
  - Socat (port forwarding)
```

### Beam Cluster (k3s)

```
4 physical nodes:
  - beam00: Infrastructure services + k3s control plane
  - beam01-03: k3s worker nodes
  - No KinD, no Docker Compose
  - Direct k3s installation
```

## Deployment Strategy for Beam Cluster

### Option 1: Infrastructure on beam00, Apps on k3s (Recommended)

**beam00 (192.168.1.10):**
- Docker + Docker Compose
- Infrastructure services:
  - Registry (registry.beam.lab)
  - PowerDNS (dns.beam.lab, dns-admin.beam.lab)
  - Prometheus (prometheus.beam.lab)
  - Grafana (grafana.beam.lab)
  - Loki (loki.beam.lab)
  - Tempo (tempo.beam.lab)
  - MinIO (s3.beam.lab)
  - TimescaleDB (postgres.beam.lab)
- Nginx ingress for infrastructure

**beam00-03 k3s cluster:**
- Application workloads
- Nginx ingress controller (Kubernetes)
- ExternalDNS → points to PowerDNS on beam00
- Application ingress: console.beam.lab, etc.

### Option 2: Everything in k3s (Alternative)

Run all services (infrastructure + apps) directly in k3s.

**Pros:**
- Unified management
- Native Kubernetes

**Cons:**
- Infrastructure coupled to cluster
- Harder to manage infrastructure independently
- Rebuilding cluster loses everything

**Recommendation:** Use Option 1 (infrastructure separate)

## DNS Configuration for Beam Cluster

### PowerDNS on beam00

Instead of dnsmasq on each node, use PowerDNS with actual DNS records:

**Zone:** `beam.lab`

**Records:**
```
# Infrastructure (beam00)
registry.beam.lab      A  192.168.1.10
dns.beam.lab           A  192.168.1.10
dns-admin.beam.lab     A  192.168.1.10
prometheus.beam.lab    A  192.168.1.10
grafana.beam.lab       A  192.168.1.10
loki.beam.lab          A  192.168.1.10
tempo.beam.lab         A  192.168.1.10
s3.beam.lab            A  192.168.1.10
postgres.beam.lab      A  192.168.1.10

# Applications (managed by ExternalDNS pointing to k3s ingress)
console.beam.lab       A  192.168.1.10  (via nginx ingress)
bootstrap.beam.lab     A  192.168.1.10
peer1.beam.lab         A  192.168.1.10
peer2.beam.lab         A  192.168.1.10
```

**LAN DNS Configuration:**
Configure your LAN router or DNS server to use beam00 (192.168.1.10) as the authoritative server for `*.beam.lab`.

## Step-by-Step Deployment

### Phase 1: Setup beam00 Infrastructure

#### 1.1 SSH to beam00

```bash
ssh rl@beam00.lab
```

#### 1.2 Install Docker and Docker Compose

```bash
# Install Docker
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker rl
newgrp docker

# Verify
docker --version
docker compose version
```

#### 1.3 Clone macula-gitops

```bash
cd ~/work
git clone https://github.com/macula-io/macula-gitops.git
cd macula-gitops
```

#### 1.4 Configure for beam cluster

Update `infrastructure/.env`:
```bash
# Beam cluster configuration
POSTGRES_PASSWORD=<secure-password>
POWERDNS_API_KEY=<secure-api-key>
PDNS_ADMIN_SECRET_KEY=<secure-secret>
MINIO_ROOT_USER=<admin-user>
MINIO_ROOT_PASSWORD=<secure-password>
GRAFANA_PASSWORD=<secure-password>
```

#### 1.5 Start infrastructure

```bash
cd infrastructure
./start-infrastructure.sh
```

#### 1.6 Configure DNS zone

```bash
# Create beam.lab zone
curl -X POST http://192.168.1.10:8081/api/v1/servers/localhost/zones \
  -H "X-API-Key: <your-api-key>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "beam.lab.",
    "kind": "Native",
    "nameservers": ["beam00.beam.lab."]
  }'

# Add infrastructure records
curl -X PATCH http://192.168.1.10:8081/api/v1/servers/localhost/zones/beam.lab. \
  -H "X-API-Key: <your-api-key>" \
  -H "Content-Type: application/json" \
  -d '{
    "rrsets": [
      {"name": "registry.beam.lab.", "type": "A", "changetype": "REPLACE",
       "records": [{"content": "192.168.1.10", "disabled": false}]},
      {"name": "dns-admin.beam.lab.", "type": "A", "changetype": "REPLACE",
       "records": [{"content": "192.168.1.10", "disabled": false}]},
      {"name": "grafana.beam.lab.", "type": "A", "changetype": "REPLACE",
       "records": [{"content": "192.168.1.10", "disabled": false}]}
    ]
  }'
```

### Phase 2: Deploy to k3s Cluster

#### 2.1 Verify k3s cluster

```bash
# From your workstation
kubectl --kubeconfig ~/.kube/beam-clusters/beam00.yaml get nodes
kubectl --kubeconfig ~/.kube/beam-clusters/beam01.yaml get nodes
kubectl --kubeconfig ~/.kube/beam-clusters/beam02.yaml get nodes
kubectl --kubeconfig ~/.kube/beam-clusters/beam03.yaml get nodes
```

#### 2.2 Choose deployment approach

**Option A: Individual kubeconfig (current)**
Deploy to each node independently with separate kubeconfigs.

**Option B: Unified cluster**
Configure all nodes as one k3s cluster with shared control plane.

**Recommendation:** Unified cluster for proper Kubernetes experience.

#### 2.3 Configure k3s to use beam00 registry

On each beam node:
```bash
# Add registry configuration
sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/registries.yaml <<EOF
mirrors:
  "registry.beam.lab:5000":
    endpoint:
      - "http://192.168.1.10:5000"
configs:
  "192.168.1.10:5000":
    insecure: true
EOF

# Restart k3s
sudo systemctl restart k3s
```

#### 2.4 Deploy nginx-ingress-controller

```bash
kubectl --kubeconfig ~/.kube/beam-clusters/beam00.yaml \
  apply -k apps/nginx-ingress/
```

#### 2.5 Deploy ExternalDNS

Create ExternalDNS deployment pointing to PowerDNS on beam00:

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
        - --domain-filter=beam.lab
        - --provider=pdns
        - --pdns-server=http://192.168.1.10:8081
        - --pdns-api-key=<your-api-key>
```

#### 2.6 Build and push application images

```bash
cd scripts
./build-and-push.sh
```

**Note:** Update script to use `registry.beam.lab:5000` instead of `localhost:5001`.

#### 2.7 Deploy applications

```bash
kubectl --kubeconfig ~/.kube/beam-clusters/beam00.yaml \
  apply -k apps/
```

### Phase 3: Storage Configuration

#### 3.1 Create PersistentVolumes on /bulk drives

Example for console database:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: console-postgres-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /bulk0/macula/console-postgres  # On /bulk drive!
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - beam01.lab
```

**Important:** Always use `/bulk0` or `/bulk1` for application data!

## Monitoring and Observability

### Access Services

From any machine on LAN (after DNS is configured):

**Infrastructure:**
- http://registry.beam.lab
- http://dns-admin.beam.lab
- http://prometheus.beam.lab
- http://grafana.beam.lab

**Applications:**
- http://console.beam.lab
- http://bootstrap.beam.lab

### Grafana Dashboards

Pre-configure dashboards for:
- Node resource usage (CPU, memory, disk)
- k3s cluster health
- Application metrics
- Distributed tracing

## Backup Strategy

### Infrastructure Data

Backup from beam00:
```bash
# Registry images
docker run --rm -v macula_infrastructure_registry-data:/data \
  -v /bulk0/backups:/backup alpine \
  tar czf /backup/registry-$(date +%Y%m%d).tar.gz -C /data .

# DNS records (PostgreSQL)
docker exec macula-dns-postgres \
  pg_dump -U powerdns powerdns > /bulk0/backups/dns-$(date +%Y%m%d).sql

# Grafana dashboards
docker run --rm -v macula_infrastructure_grafana-data:/data \
  -v /bulk0/backups:/backup alpine \
  tar czf /backup/grafana-$(date +%Y%m%d).tar.gz -C /data .
```

### Application Data

Use Velero or similar for k3s PersistentVolume backups.

## Troubleshooting

### Registry Not Accessible

```bash
# Check beam00 infrastructure
ssh rl@beam00.lab
cd ~/work/macula-gitops/infrastructure
docker compose ps
docker compose logs registry

# Check k3s registry configuration
ssh rl@beam01.lab
cat /etc/rancher/k3s/registries.yaml
sudo systemctl status k3s
```

### DNS Not Resolving

```bash
# Test PowerDNS on beam00
dig @192.168.1.10 registry.beam.lab

# Check ExternalDNS logs
kubectl logs -n kube-system -l app=external-dns
```

### Application Not Starting

```bash
# Check pod status
kubectl get pods -n macula

# Check events
kubectl get events -n macula --sort-by=.lastTimestamp

# Check logs
kubectl logs -n macula <pod-name>
```

## Migration from Dev to Beam

### 1. Test locally first

Ensure everything works in KinD environment.

### 2. Update image tags

Change from `kind-registry:5000` to `registry.beam.lab:5000`.

### 3. Update domain names

Change from `*.macula.local` to `*.beam.lab`.

### 4. Update PersistentVolumes

Ensure all volumes use `/bulk` paths.

### 5. Deploy incrementally

Deploy infrastructure → nginx-ingress → applications.

### 6. Test end-to-end

Verify all services accessible from LAN.

## Security Considerations

### Production Beam Cluster

For production use:
- Enable TLS for all services
- Configure proper authentication
- Use Kubernetes RBAC
- Secure PowerDNS API key
- Enable audit logging
- Configure network policies

### Secrets Management

Use Kubernetes Secrets or external secret manager (Vault, Sealed Secrets).

## Differences Summary

| Aspect | Dev (KinD) | Beam Cluster |
|--------|------------|--------------|
| Infrastructure | Docker Compose on host | Docker Compose on beam00 |
| Cluster | KinD (single node) | k3s (4 physical nodes) |
| DNS | Dnsmasq (127.0.0.x) | PowerDNS (192.168.1.10) |
| Domain | *.macula.local | *.beam.lab |
| Registry | localhost:5001 | registry.beam.lab:5000 |
| Storage | Docker volumes | /bulk0, /bulk1 on nodes |
| Port Forwarding | Socat (loopback) | Direct (LAN IPs) |
| Access | Localhost only | LAN-wide |

## Next Steps

1. Deploy infrastructure to beam00
2. Configure PowerDNS with beam.lab zone
3. Deploy nginx-ingress to k3s
4. Deploy ExternalDNS
5. Build and push images to beam registry
6. Deploy applications
7. Configure Grafana dashboards
8. Set up automated backups
9. Document any beam-specific issues
10. Create runbook for operations
