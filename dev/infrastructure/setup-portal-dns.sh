#!/usr/bin/env bash
# Quick setup to add home.macula.local to /etc/hosts
# Run with: sudo ./setup-portal-dns.sh

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo $0"
    exit 1
fi

# Check if entry already exists
if grep -q "home.macula.local" /etc/hosts; then
    echo "✓ home.macula.local already in /etc/hosts"
else
    echo "127.0.0.1 home.macula.local" >> /etc/hosts
    echo "✓ Added home.macula.local to /etc/hosts"
fi

echo ""
echo "Portal is now accessible at: http://home.macula.local"
echo ""
echo "Test with: curl http://home.macula.local"
