#!/usr/bin/env bash
set -e

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
LAN_MODE=false
if [ "$1" = "--lan" ]; then
    LAN_MODE=true
fi

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  Macula Infrastructure Startup                         ║"
if [ "$LAN_MODE" = true ]; then
echo "║  Mode: LAN (Shared with beam cluster)                 ║"
else
echo "║  Mode: Localhost (KinD only)                          ║"
fi
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Check if docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC} Docker is not running. Please start Docker and try again."
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${CYAN}▸${NC} Starting infrastructure services..."
echo ""

# Start services
cd "$SCRIPT_DIR"
if [ "$LAN_MODE" = true ]; then
    # LAN mode: expose on all interfaces
    docker compose -f docker-compose.yml -f docker-compose.lan.yml up -d
else
    # Local mode: localhost only
    docker compose up -d
fi

echo ""
echo -e "${GREEN}✓${NC} Waiting for services to become healthy..."
echo ""

# Wait for registry
echo -e "${CYAN}▸${NC} Waiting for registry..."
timeout 60 bash -c 'until docker compose ps registry | grep -q "healthy"; do sleep 2; done' || {
    echo -e "${YELLOW}⚠${NC} Registry health check timeout - checking manually..."
}

# Wait for PowerDNS
echo -e "${CYAN}▸${NC} Waiting for PowerDNS..."
timeout 60 bash -c 'until docker compose ps powerdns | grep -q "healthy"; do sleep 2; done' || {
    echo -e "${YELLOW}⚠${NC} PowerDNS health check timeout - checking manually..."
}

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  Infrastructure Ready                                  ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

echo -e "${GREEN}Services (via host-based routing):${NC}"
echo ""
echo "  📦 Docker Registry"
echo "     URL:       http://registry.macula.local"
echo "     API:       http://registry.macula.local/v2/"
echo "     Legacy:    http://localhost:5001/"
echo "     Test:      curl http://registry.macula.local/v2/_catalog"
echo ""
echo "  🌐 PowerDNS"
echo "     API:       http://dns.macula.local"
echo "     Admin UI:  http://dns-admin.macula.local"
echo "     API Key:   macula-dev-api-key (default)"
echo ""
if [ "$LAN_MODE" = true ]; then
    echo -e "${YELLOW}⚠  LAN Mode Active:${NC}"
    echo "     Services are exposed on: $(hostname -I | awk '{print $1}')"
    echo ""
    echo -e "${YELLOW}⚠  Configure firewall (if not already done):${NC}"
    echo "     sudo ./setup-firewall.sh"
    echo ""
    echo -e "${YELLOW}⚠  Configure beam clusters:${NC}"
    echo "     1. Update /etc/rancher/k3s/registries.yaml on each beam node"
    echo "     2. Point to: $(hostname -I | awk '{print $1}'):5000"
    echo "     3. Deploy ExternalDNS pointing to: $(hostname -I | awk '{print $1}'):8081"
    echo ""
else
    echo -e "${YELLOW}⚠  Add DNS (if not already done):${NC}"
    echo "     cd ../scripts && sudo ./setup-dnsmasq.sh"
    echo ""
fi

echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "  1. Create KinD cluster:"
echo "     cd ../scripts && ./setup-cluster.sh"
echo ""
echo "  2. Build and push images:"
echo "     cd ../scripts && ./build-and-push.sh"
echo ""
echo "  3. Deploy applications:"
echo "     kubectl apply -k ../clusters/dev"
echo ""
