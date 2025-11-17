#!/bin/bash
#
# Identify Network Interfaces
# Run this on your workstation to identify which interface is which
#
# Usage: ./identify-interfaces.sh
#

echo "=== Network Interface Identification ==="
echo ""
echo "All network interfaces:"
ip -br link show
echo ""

echo "=== Interface Details with IP Addresses ==="
echo ""
for iface in $(ip -br link show | awk '{print $1}'); do
  if [[ "${iface}" != "lo" ]]; then
    echo "Interface: ${iface}"
    echo "  Hardware: $(ethtool ${iface} 2>/dev/null | grep -E 'Speed|Duplex' || echo 'N/A')"
    echo "  IP Address: $(ip -4 addr show ${iface} | grep inet | awk '{print $2}' || echo 'None')"
    echo "  Status: $(ip link show ${iface} | grep -oP '(?<=state )[^ ]+')"
    echo "  Default route via this interface: $(ip route show default | grep ${iface} || echo 'No')"
    echo ""
  fi
done

echo "=== Routing Table ==="
echo ""
ip route show
echo ""

echo "=== Default Gateway ==="
ip route show default
echo ""

echo "=== Connected Networks ==="
echo ""
ip -4 addr show | grep inet | grep -v "127.0.0.1"
echo ""

echo "=== Instructions ==="
echo "1. Identify your FAST interface (likely the one with internet gateway)"
echo "2. Identify your SLOW/LAN interface (likely the one on 192.168.1.x network)"
echo "3. Update setup-nat-gateway.sh with these interface names"
echo "   Example: FAST_INTERFACE=eno1 SLOW_INTERFACE=enp3s0"
