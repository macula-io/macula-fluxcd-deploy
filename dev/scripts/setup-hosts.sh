#!/usr/bin/env bash
set -e

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

HOSTS_ENTRY="127.0.0.1 registry.macula.local dns.macula.local dns-admin.macula.local"
HOSTS_FILE="/etc/hosts"

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  Macula Infrastructure - /etc/hosts Setup              ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Check if entries already exist
if grep -q "registry.macula.local" "$HOSTS_FILE" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Entries already exist in $HOSTS_FILE"
    echo ""
    echo "Current entries:"
    grep "macula.local" "$HOSTS_FILE" | sed 's/^/  /'
    echo ""
    exit 0
fi

echo -e "${CYAN}▸${NC} Adding DNS entries to $HOSTS_FILE"
echo ""
echo "  This will add:"
echo "    $HOSTS_ENTRY"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}⚠${NC}  This operation requires sudo privileges"
    echo ""
    echo "$HOSTS_ENTRY" | sudo tee -a "$HOSTS_FILE" > /dev/null
else
    echo "$HOSTS_ENTRY" >> "$HOSTS_FILE"
fi

echo ""
echo -e "${GREEN}✓${NC} Entries added successfully"
echo ""
echo "Verify:"
echo "  cat /etc/hosts | grep macula.local"
echo ""
echo "Services will be available at:"
echo "  📦 http://registry.macula.local"
echo "  🌐 http://dns.macula.local"
echo "  ⚙️  http://dns-admin.macula.local"
echo ""
