#!/usr/bin/env bash
set -e

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="macula-port-forwarding.service"
SYSTEMD_DIR="/etc/systemd/system"

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  Install Macula Port Forwarding Systemd Service        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗${NC} This script must be run as root (use sudo)"
    exit 1
fi

# Update the service file with correct script path
echo -e "${CYAN}▸${NC} Installing systemd service..."

sed "s|/home/rl/work/github.com/macula-io/macula-gitops|${SCRIPT_DIR}/..| g" \
    "${SCRIPT_DIR}/${SERVICE_FILE}" > "${SYSTEMD_DIR}/${SERVICE_FILE}"

# Reload systemd
systemctl daemon-reload

echo -e "${GREEN}✓${NC} Service installed: ${SERVICE_FILE}"
echo ""

echo -e "${CYAN}Available commands:${NC}"
echo "  sudo systemctl start macula-port-forwarding    # Start service"
echo "  sudo systemctl stop macula-port-forwarding     # Stop service"
echo "  sudo systemctl enable macula-port-forwarding   # Auto-start on boot"
echo "  sudo systemctl status macula-port-forwarding   # Check status"
echo "  sudo journalctl -u macula-port-forwarding -f   # View logs"
echo ""

read -p "Enable and start the service now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    systemctl enable macula-port-forwarding
    systemctl start macula-port-forwarding
    sleep 2
    systemctl status macula-port-forwarding --no-pager
fi
