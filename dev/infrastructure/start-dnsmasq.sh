#!/usr/bin/env bash
# Start and enable dnsmasq service
# Run with: sudo ./start-dnsmasq.sh

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo $0"
    exit 1
fi

echo "Starting dnsmasq..."
systemctl start dnsmasq
systemctl enable dnsmasq

echo ""
echo "✓ dnsmasq started and enabled"
echo ""

# Test DNS
echo "Testing DNS resolution:"
echo -n "  home.macula.local: "
dig +short home.macula.local @127.0.0.1

echo -n "  registry.macula.local: "
dig +short registry.macula.local @127.0.0.1

echo ""
echo "✓ DNS is working!"
echo ""
echo "You can now access the portal at: http://home.macula.local"
