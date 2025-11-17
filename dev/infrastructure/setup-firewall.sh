#!/usr/bin/env bash
set -e

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

BEAM_SUBNET="192.168.1.0/24"

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  Macula Infrastructure - Firewall Configuration        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗${NC} This script must be run as root (use sudo)"
    exit 1
fi

# Detect firewall
if command -v ufw &> /dev/null; then
    FIREWALL="ufw"
elif command -v firewall-cmd &> /dev/null; then
    FIREWALL="firewalld"
else
    echo -e "${YELLOW}⚠${NC}  No supported firewall detected (ufw or firewalld)"
    echo "Please configure firewall manually"
    exit 1
fi

echo -e "${CYAN}▸${NC} Detected firewall: $FIREWALL"
echo ""

# Services to expose
SERVICES=(
    "80:tcp:HTTP/Nginx"
    "53:tcp:DNS"
    "53:udp:DNS"
    "5000:tcp:Registry"
    "5001:tcp:Registry (legacy)"
    "8081:tcp:PowerDNS API"
    "9090:tcp:Prometheus"
    "3000:tcp:Grafana"
    "3100:tcp:Loki"
    "3200:tcp:Tempo"
    "4317:tcp:OTLP gRPC"
    "4318:tcp:OTLP HTTP"
    "8888:tcp:Excalidraw"
    "9000:tcp:MinIO S3 API"
    "9001:tcp:MinIO Console"
    "5432:tcp:TimescaleDB"
    "9191:tcp:PowerDNS Admin (optional)"
)

echo -e "${CYAN}▸${NC} Configuring firewall rules for beam cluster subnet: $BEAM_SUBNET"
echo ""

if [ "$FIREWALL" = "ufw" ]; then
    # UFW configuration
    echo -e "${CYAN}Allowing services from beam cluster:${NC}"

    for service in "${SERVICES[@]}"; do
        port=$(echo $service | cut -d: -f1)
        proto=$(echo $service | cut -d: -f2)
        desc=$(echo $service | cut -d: -f3)

        ufw allow from $BEAM_SUBNET to any port $port proto $proto comment "Macula: $desc"
        echo -e "  ${GREEN}✓${NC} $port/$proto - $desc"
    done

    # Enable UFW if not already enabled
    if ! ufw status | grep -q "Status: active"; then
        echo ""
        read -p "Enable UFW firewall? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ufw --force enable
            echo -e "${GREEN}✓${NC} UFW enabled"
        fi
    fi

elif [ "$FIREWALL" = "firewalld" ]; then
    # Firewalld configuration
    echo -e "${CYAN}Creating rich rules for beam cluster:${NC}"

    for service in "${SERVICES[@]}"; do
        port=$(echo $service | cut -d: -f1)
        proto=$(echo $service | cut -d: -f2)
        desc=$(echo $service | cut -d: -f3)

        firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$BEAM_SUBNET' port protocol='$proto' port='$port' accept"
        echo -e "  ${GREEN}✓${NC} $port/$proto - $desc"
    done

    firewall-cmd --reload
    echo -e "${GREEN}✓${NC} Firewall rules reloaded"
fi

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  Firewall Configuration Complete                       ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Display current rules
if [ "$FIREWALL" = "ufw" ]; then
    echo -e "${CYAN}Current UFW status:${NC}"
    ufw status numbered | grep -E "(Macula|192.168.1)" || echo "  No Macula rules found"
elif [ "$FIREWALL" = "firewalld" ]; then
    echo -e "${CYAN}Current firewalld rich rules:${NC}"
    firewall-cmd --list-rich-rules | grep "192.168.1" || echo "  No rules found"
fi

echo ""
echo -e "${GREEN}Infrastructure is now accessible from beam cluster${NC}"
echo ""
echo "Test from beam00:"
echo "  curl http://$(hostname -I | awk '{print $1}')/health"
echo "  dig @$(hostname -I | awk '{print $1}') registry.macula.local"
echo ""
