#!/usr/bin/env bash
set -e

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  Stopping Macula Infrastructure                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$SCRIPT_DIR"

echo -e "${CYAN}▸${NC} Stopping services..."
docker compose down

echo ""
echo -e "${GREEN}✓${NC} Infrastructure stopped"
echo ""
echo "  Data volumes preserved:"
echo "    - registry-data"
echo "    - dns-postgres-data"
echo ""
echo "  To remove all data:"
echo "    cd infrastructure && docker compose down -v"
echo ""
