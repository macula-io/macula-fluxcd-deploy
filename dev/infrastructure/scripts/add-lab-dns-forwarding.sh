#!/bin/bash
# Add DNS forwarding for .lab domain to PowerDNS
# PowerDNS runs at 172.22.0.10 in docker network

set -e

DNSMASQ_CONF="/etc/dnsmasq.d/macula.conf"
POWERDNS_IP="172.22.0.10"

# Check if already configured
if grep -q "server=/lab/" "$DNSMASQ_CONF" 2>/dev/null; then
    echo "DNS forwarding for .lab already configured"
    exit 0
fi

echo "Adding DNS forwarding for .lab to PowerDNS at $POWERDNS_IP"

# Add server directive for .lab domain
cat >> "$DNSMASQ_CONF" << EOF

# Forward .lab domain queries to PowerDNS
server=/lab/$POWERDNS_IP
EOF

# Restart dnsmasq to apply changes
echo "Restarting dnsmasq..."
systemctl restart dnsmasq

echo "Done. Testing DNS resolution..."
dig console.beam01.lab +short
