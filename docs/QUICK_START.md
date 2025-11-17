#!/usr/bin/env bash
# Macula GitOps - Complete Quick Start Guide
# This guide walks through the complete setup from scratch

set -e

cat << 'EOF'
╔════════════════════════════════════════════════════════╗
║  Macula GitOps - Complete Setup Guide                 ║
║  Development Workstation (KinD + Docker Compose)       ║
╚════════════════════════════════════════════════════════╝

Prerequisites:
  ✓ Docker Desktop or Docker Engine
  ✓ kubectl (brew install kubectl)
  ✓ kind (brew install kind)
  ✓ socat (will be installed)
  ✓ dnsmasq (will be installed)

This will install:
  📦 Docker Registry + UI
  🌐 PowerDNS + Admin UI
  📊 Prometheus + Grafana + Loki + Tempo (observability)
  💾 MinIO + TimescaleDB (data services)
  🎮 KinD cluster for applications

═══════════════════════════════════════════════════════════

PHASE 1: DNS Setup (One-time)
═══════════════════════════════════════════════════════════

This installs dnsmasq and configures wildcard *.macula.local DNS.

EOF

read -p "Install and configure dnsmasq? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd infrastructure
    sudo ./setup-dnsmasq.sh
    cd ..
    echo "✓ Dnsmasq configured"
else
    echo "⚠  Skipping dnsmasq setup. You'll need to configure DNS manually."
fi

cat << 'EOF'

═══════════════════════════════════════════════════════════

PHASE 2: Start Infrastructure Services
═══════════════════════════════════════════════════════════

Starting Docker Compose infrastructure on host:
  - Registry (registry.macula.local)
  - PowerDNS (dns.macula.local, dns-admin.macula.local)
  - Prometheus (prometheus.macula.local)
  - Grafana (grafana.macula.local)
  - Loki (loki.macula.local)
  - Tempo (tempo.macula.local)
  - MinIO (s3.macula.local)
  - TimescaleDB (postgres.macula.local)

EOF

read -p "Start infrastructure services? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd infrastructure
    ./start-infrastructure.sh
    cd ..
    echo "✓ Infrastructure services started"
else
    echo "⚠  Skipping infrastructure. Start manually with: cd infrastructure && ./start-infrastructure.sh"
fi

cat << 'EOF'

═══════════════════════════════════════════════════════════

PHASE 3: Setup Port Forwarding
═══════════════════════════════════════════════════════════

This forwards Docker container ports to dedicated loopback IPs:
  127.0.0.2 → KinD applications
  127.0.0.3 → Prometheus
  127.0.0.4 → Grafana
  127.0.0.5 → Loki
  127.0.0.6 → Tempo
  127.0.0.7 → TimescaleDB
  127.0.0.8 → MinIO

EOF

read -p "Setup port forwarding? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd scripts
    ./setup-port-forwarding.sh start
    cd ..
    echo "✓ Port forwarding configured"

    read -p "Install as systemd service (auto-start on boot)? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd scripts
        sudo ./install-systemd-service.sh
        cd ..
    fi
else
    echo "⚠  Skipping port forwarding. Run manually: cd scripts && ./setup-port-forwarding.sh start"
fi

cat << 'EOF'

═══════════════════════════════════════════════════════════

PHASE 4: Create KinD Cluster
═══════════════════════════════════════════════════════════

Creating KinD cluster with:
  - Ingress-ready node labels
  - Port mappings: 8080 (HTTP), 8443 (HTTPS), 4433 (QUIC)
  - Registry connection

EOF

read -p "Create KinD cluster? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd scripts
    ./setup-cluster.sh
    cd ..
    echo "✓ KinD cluster created"
else
    echo "⚠  Skipping cluster creation. Run manually: cd scripts && ./setup-cluster.sh"
fi

cat << 'EOF'

═══════════════════════════════════════════════════════════

PHASE 5: Deploy nginx-ingress-controller
═══════════════════════════════════════════════════════════

Deploying nginx-ingress-controller to KinD cluster for
application routing (console.macula.local, etc.)

EOF

read -p "Deploy nginx-ingress to KinD? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl apply -k apps/nginx-ingress/
    echo "✓ nginx-ingress-controller deployed"
    echo "Waiting for ingress controller to be ready..."
    kubectl wait --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=90s
else
    echo "⚠  Skipping nginx-ingress. Deploy manually: kubectl apply -k apps/nginx-ingress/"
fi

cat << 'EOF'

═══════════════════════════════════════════════════════════

PHASE 6: Build and Push Application Images
═══════════════════════════════════════════════════════════

Building Macula application images and pushing to local registry:
  - macula-bootstrap
  - macula-console
  - macula-arcade

EOF

read -p "Build and push images? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd scripts
    ./build-and-push.sh
    cd ..
    echo "✓ Images built and pushed"
else
    echo "⚠  Skipping image build. Run manually: cd scripts && ./build-and-push.sh"
fi

cat << 'EOF'

═══════════════════════════════════════════════════════════

SETUP COMPLETE!
═══════════════════════════════════════════════════════════

Your Macula development environment is ready!

Access Services:
════════════════

Infrastructure (Host):
  📦 Registry:        http://registry.macula.local
  🌐 DNS Admin:       http://dns-admin.macula.local
  📊 Prometheus:      http://prometheus.macula.local
  📈 Grafana:         http://grafana.macula.local
  📝 Loki:            http://loki.macula.local
  🔍 Tempo:           http://tempo.macula.local
  💾 MinIO Console:   http://s3-console.macula.local
  🗄️  PostgreSQL:     postgres://postgres.macula.local:5432

Applications (KinD):
  🎮 Console:         http://console.macula.local
  📡 Bootstrap:       http://bootstrap.macula.local
  🎯 Arcade Peer 1:   http://peer1.macula.local
  🎯 Arcade Peer 2:   http://peer2.macula.local

Common Commands:
════════════════

# View infrastructure status
cd infrastructure && docker compose ps

# View cluster status
kubectl get nodes
kubectl get pods -A

# View port forwarding status
cd scripts && ./setup-port-forwarding.sh status

# Restart infrastructure
cd infrastructure && docker compose restart

# Stop everything
cd scripts && ./setup-port-forwarding.sh stop
cd ../infrastructure && ./stop-infrastructure.sh
kind delete cluster --name macula-dev

Next Steps:
═══════════

1. Open Grafana: http://grafana.macula.local
   - Explore pre-configured dashboards
   - View logs in Loki
   - View traces in Tempo

2. Deploy your applications:
   kubectl apply -k apps/

3. Check application logs:
   kubectl logs -n macula -l app=console

4. Access PowerDNS Admin: http://dns-admin.macula.local
   - View DNS records
   - Manage zones

Documentation:
══════════════

- README.md                        - Overview and workflow
- ARCHITECTURE_DECISIONS.md        - Why each service was chosen
- IMPLEMENTATION_PLAN.md           - Detailed implementation steps
- INFRASTRUCTURE_SUMMARY.md        - Quick reference
- BEAM_CLUSTER_DEPLOYMENT.md       - Deploy to physical beam cluster
- infrastructure/README.md         - Infrastructure details
- infrastructure/NGINX_INGRESS.md  - Ingress configuration

Troubleshooting:
════════════════

Problem: DNS not resolving
Solution: Check dnsmasq status
  sudo systemctl status dnsmasq
  dig @127.0.0.1 registry.macula.local

Problem: Port forwarding not working
Solution: Check socat processes
  cd scripts && ./setup-port-forwarding.sh status
  ps aux | grep socat

Problem: Services not accessible
Solution: Check infrastructure
  cd infrastructure && docker compose ps
  docker compose logs <service-name>

Problem: KinD cluster issues
Solution: Recreate cluster
  kind delete cluster --name macula-dev
  cd scripts && ./setup-cluster.sh

Happy hacking! 🚀

EOF
