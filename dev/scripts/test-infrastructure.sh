#!/usr/bin/env bash
set -e

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  Macula Infrastructure - End-to-End Test               ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

test_service() {
    local name=$1
    local url=$2
    local expected_pattern=$3

    echo -e "${CYAN}▸${NC} Testing $name..."

    if response=$(curl -s -f -m 5 "$url" 2>&1); then
        if [ -n "$expected_pattern" ]; then
            if echo "$response" | grep -q "$expected_pattern"; then
                echo -e "  ${GREEN}✓${NC} $name is accessible and responding correctly"
                ((TESTS_PASSED++))
                return 0
            else
                echo -e "  ${RED}✗${NC} $name responded but content unexpected"
                echo -e "  ${YELLOW}Expected pattern: $expected_pattern${NC}"
                ((TESTS_FAILED++))
                return 1
            fi
        else
            echo -e "  ${GREEN}✓${NC} $name is accessible"
            ((TESTS_PASSED++))
            return 0
        fi
    else
        echo -e "  ${RED}✗${NC} $name is not accessible"
        echo -e "  ${YELLOW}URL: $url${NC}"
        echo -e "  ${YELLOW}Error: $response${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

test_dns() {
    local hostname=$1
    local expected_ip=$2

    echo -e "${CYAN}▸${NC} Testing DNS resolution: $hostname"

    if resolved_ip=$(dig +short "$hostname" @127.0.0.1 2>&1 | head -n1); then
        if [ "$resolved_ip" = "$expected_ip" ]; then
            echo -e "  ${GREEN}✓${NC} $hostname resolves to $resolved_ip"
            ((TESTS_PASSED++))
            return 0
        else
            echo -e "  ${RED}✗${NC} $hostname resolves to $resolved_ip (expected $expected_ip)"
            ((TESTS_FAILED++))
            return 1
        fi
    else
        echo -e "  ${RED}✗${NC} DNS resolution failed for $hostname"
        ((TESTS_FAILED++))
        return 1
    fi
}

test_docker_service() {
    local service_name=$1

    echo -e "${CYAN}▸${NC} Testing Docker service: $service_name"

    if docker compose -f ../infrastructure/docker-compose.yml ps "$service_name" 2>/dev/null | grep -q "Up\|healthy"; then
        echo -e "  ${GREEN}✓${NC} $service_name is running"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $service_name is not running"
        ((TESTS_FAILED++))
        return 1
    fi
}

test_kind_cluster() {
    echo -e "${CYAN}▸${NC} Testing KinD cluster"

    if kubectl cluster-info --context kind-macula-dev &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} KinD cluster is accessible"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${YELLOW}⚠${NC} KinD cluster not found (optional for infrastructure test)"
        return 0
    fi
}

test_kind_ingress() {
    echo -e "${CYAN}▸${NC} Testing KinD nginx-ingress controller"

    if kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --context kind-macula-dev 2>/dev/null | grep -q "Running"; then
        echo -e "  ${GREEN}✓${NC} nginx-ingress controller is running"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${YELLOW}⚠${NC} nginx-ingress controller not found (deploy with: kubectl apply -k ../apps/nginx-ingress/)"
        return 0
    fi
}

# ============================================================
# Phase 1: Infrastructure Services (Docker Compose)
# ============================================================

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Phase 1: Docker Compose Infrastructure Services${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

# Check if infrastructure is running
if ! docker compose -f ../infrastructure/docker-compose.yml ps &>/dev/null; then
    echo -e "${RED}✗${NC} Docker Compose infrastructure not running"
    echo ""
    echo "Start with: cd ../infrastructure && ./start-infrastructure.sh"
    exit 1
fi

# Test Docker services
test_docker_service "registry"
test_docker_service "registry-ui"
test_docker_service "powerdns"
test_docker_service "powerdns-admin"
test_docker_service "dns-postgres"
test_docker_service "nginx-ingress"

# Phase 2 Services
test_docker_service "prometheus"
test_docker_service "grafana"
test_docker_service "loki"
test_docker_service "tempo"
test_docker_service "excalidraw"

# Phase 3 Services
test_docker_service "timescaledb"
test_docker_service "minio"

# ============================================================
# Phase 2: DNS Resolution
# ============================================================

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Phase 2: DNS Resolution${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

# Check if dnsmasq is installed
if ! command -v dnsmasq &> /dev/null; then
    echo -e "${YELLOW}⚠${NC} dnsmasq not found. Install with: cd ../infrastructure && sudo ./setup-dnsmasq.sh"
    echo ""
else
    # Test infrastructure DNS (127.0.0.1)
    test_dns "registry.macula.local" "127.0.0.1"
    test_dns "dns.macula.local" "127.0.0.1"
    test_dns "dns-admin.macula.local" "127.0.0.1"

    # Test application DNS (127.0.0.2)
    test_dns "console.macula.local" "127.0.0.2"
    test_dns "bootstrap.macula.local" "127.0.0.2"

    # Test observability DNS (127.0.0.3-6)
    test_dns "prometheus.macula.local" "127.0.0.3"
    test_dns "grafana.macula.local" "127.0.0.4"
    test_dns "loki.macula.local" "127.0.0.5"
    test_dns "tempo.macula.local" "127.0.0.6"

    # Test tools DNS (127.0.0.7)
    test_dns "draw.macula.local" "127.0.0.7"

    # Test data services DNS (127.0.0.8-9)
    test_dns "postgres.macula.local" "127.0.0.8"
    test_dns "s3.macula.local" "127.0.0.9"
    test_dns "s3-console.macula.local" "127.0.0.9"
fi

# ============================================================
# Phase 3: HTTP Access via Nginx Ingress (Host)
# ============================================================

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Phase 3: HTTP Access via Host Nginx Ingress${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

# Test infrastructure services via DNS
test_service "Registry API" "http://registry.macula.local/v2/" "repositories"
test_service "Registry UI" "http://registry.macula.local/" "Docker Registry"
test_service "PowerDNS API" "http://dns.macula.local/api/v1/servers" "servers"
test_service "PowerDNS Admin" "http://dns-admin.macula.local/" "PowerDNS-Admin"

# Test legacy registry access
test_service "Registry (legacy port)" "http://localhost:5001/v2/" "repositories"

# Test observability services
test_service "Prometheus" "http://prometheus.macula.local/-/healthy" ""
test_service "Grafana" "http://grafana.macula.local/api/health" "database"
test_service "Loki" "http://loki.macula.local/ready" ""
test_service "Tempo" "http://tempo.macula.local/ready" ""

# Test development tools
test_service "Excalidraw" "http://draw.macula.local/" ""

# Test data services
test_service "MinIO S3 API" "http://s3.macula.local/minio/health/live" ""
test_service "MinIO Console" "http://s3-console.macula.local/" "MinIO"

# ============================================================
# Phase 4: KinD Cluster (Optional)
# ============================================================

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Phase 4: KinD Cluster and Ingress (Optional)${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

test_kind_cluster
test_kind_ingress

# ============================================================
# Phase 5: Port Forwarding (Optional)
# ============================================================

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Phase 5: Port Forwarding (Optional)${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}▸${NC} Checking port forwarding processes"

if pgrep -f "socat.*127.0.0.2.*8080" &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Port forwarding (127.0.0.2:80 → 127.0.0.1:8080) is active"
    ((TESTS_PASSED++))
else
    echo -e "  ${YELLOW}⚠${NC} Port forwarding not active (start with: ./setup-port-forwarding.sh start)"
fi

if pgrep -f "socat.*127.0.0.2.*8443" &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Port forwarding (127.0.0.2:443 → 127.0.0.1:8443) is active"
    ((TESTS_PASSED++))
else
    echo -e "  ${YELLOW}⚠${NC} HTTPS port forwarding not active"
fi

# ============================================================
# Test Summary
# ============================================================

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  Test Summary                                          ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "Your infrastructure is ready. Next steps:"
    echo ""
    echo "  1. Create KinD cluster (if not done):"
    echo "     ./setup-cluster.sh"
    echo ""
    echo "  2. Deploy nginx-ingress to KinD:"
    echo "     kubectl apply -k ../apps/nginx-ingress/"
    echo ""
    echo "  3. Build and push images:"
    echo "     ./build-and-push.sh"
    echo ""
    echo "  4. Deploy applications:"
    echo "     kubectl apply -k ../clusters/dev"
    echo ""
    exit 0
else
    echo -e "${YELLOW}⚠ Some tests failed. Please review the errors above.${NC}"
    echo ""
    echo "Common issues:"
    echo ""
    echo "  • Infrastructure not running:"
    echo "    cd ../infrastructure && ./start-infrastructure.sh"
    echo ""
    echo "  • DNS not configured:"
    echo "    cd ../infrastructure && sudo ./setup-dnsmasq.sh"
    echo ""
    echo "  • Port forwarding not active:"
    echo "    ./setup-port-forwarding.sh start"
    echo ""
    exit 1
fi
