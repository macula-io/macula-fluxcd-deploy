#!/usr/bin/env bash
# Quick health check for Macula infrastructure
# Use this for rapid validation without extensive testing

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
        return 0
    else
        echo -e "${RED}✗${NC} $1"
        return 1
    fi
}

echo ""
echo "Macula Infrastructure Health Check"
echo "===================================="
echo ""

# Docker Compose
docker compose -f /home/rl/work/github.com/macula-io/macula-gitops/infrastructure/docker-compose.yml ps registry &>/dev/null
check "Docker Compose infrastructure running"

# Registry
curl -sf http://registry.macula.local/v2/ &>/dev/null
check "Registry API accessible (http://registry.macula.local/v2/)"

# PowerDNS
curl -sf http://dns.macula.local/api/v1/servers &>/dev/null
check "PowerDNS API accessible (http://dns.macula.local)"

# DNS Resolution
[ "$(dig +short registry.macula.local @127.0.0.1 | head -n1)" = "127.0.0.1" ]
check "DNS resolution (registry.macula.local → 127.0.0.1)"

# Observability Stack (Phase 2)
curl -sf http://prometheus.macula.local/-/healthy &>/dev/null
check "Prometheus accessible (http://prometheus.macula.local)"

curl -sf http://grafana.macula.local/api/health &>/dev/null
check "Grafana accessible (http://grafana.macula.local)"

curl -sf http://loki.macula.local/ready &>/dev/null
check "Loki accessible (http://loki.macula.local)"

curl -sf http://tempo.macula.local/ready &>/dev/null
check "Tempo accessible (http://tempo.macula.local)"

# Development Tools (Phase 2)
curl -sf http://draw.macula.local/ &>/dev/null
check "Excalidraw accessible (http://draw.macula.local)"

# Data Services (Phase 3)
curl -sf http://s3.macula.local/minio/health/live &>/dev/null
check "MinIO S3 API accessible (http://s3.macula.local)"

curl -sf http://s3-console.macula.local/ &>/dev/null
check "MinIO Console accessible (http://s3-console.macula.local)"

# TimescaleDB (PostgreSQL) - check if port is open
timeout 2 bash -c 'cat < /dev/null > /dev/tcp/postgres.macula.local/5432' &>/dev/null
check "TimescaleDB accessible (postgres.macula.local:5432)"

# KinD Cluster (optional)
if kubectl cluster-info --context kind-macula-dev &>/dev/null; then
    check "KinD cluster accessible"

    # nginx-ingress in KinD
    if kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --context kind-macula-dev 2>/dev/null | grep -q "Running"; then
        check "nginx-ingress controller running in KinD"
    else
        echo -e "${YELLOW}⚠${NC} nginx-ingress controller not deployed"
    fi
else
    echo -e "${YELLOW}⚠${NC} KinD cluster not found (optional)"
fi

# Port Forwarding (optional)
if pgrep -f "socat.*127.0.0.2.*8080" &>/dev/null; then
    check "Port forwarding active (KinD HTTP)"
else
    echo -e "${YELLOW}⚠${NC} Port forwarding not active (optional)"
fi

echo ""
