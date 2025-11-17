#!/bin/bash
#
# Prioritize Fast Network Interface
# This ensures enp5s0 (2.5Gb) is used over enp4s0 (1Gb)
#
# Usage: sudo ./prioritize-fast-interface.sh
#

set -e

FAST_IFACE="enp5s0"   # 2500 Mbps
SLOW_IFACE="enp4s0"   # 1000 Mbps

echo "=== Prioritize Fast Interface ==="
echo "Fast interface: ${FAST_IFACE} (2.5Gb)"
echo "Slow interface: ${SLOW_IFACE} (1Gb)"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: This script must be run as root (use sudo)"
  exit 1
fi

echo "Current routing table:"
ip route show
echo ""

echo "Step 1: Adjusting interface metrics..."
echo "  - Setting ${FAST_IFACE} metric to 50 (highest priority)"
echo "  - Setting ${SLOW_IFACE} metric to 200 (lowest priority)"
echo ""

# Detect if using NetworkManager or netplan
if systemctl is-active --quiet NetworkManager; then
  echo "Detected NetworkManager configuration"

  # Get connection names
  FAST_CONN=$(nmcli -t -f NAME,DEVICE connection show --active | grep "${FAST_IFACE}" | cut -d: -f1)
  SLOW_CONN=$(nmcli -t -f NAME,DEVICE connection show --active | grep "${SLOW_IFACE}" | cut -d: -f1)

  if [ -n "${FAST_CONN}" ]; then
    echo "  - Updating ${FAST_CONN} (${FAST_IFACE})..."
    nmcli connection modify "${FAST_CONN}" ipv4.route-metric 50
    nmcli connection modify "${FAST_CONN}" ipv6.route-metric 50
  fi

  if [ -n "${SLOW_CONN}" ]; then
    echo "  - Updating ${SLOW_CONN} (${SLOW_IFACE})..."
    nmcli connection modify "${SLOW_CONN}" ipv4.route-metric 200
    nmcli connection modify "${SLOW_CONN}" ipv6.route-metric 200
  fi

  echo ""
  echo "Step 2: Restarting connections to apply changes..."
  [ -n "${FAST_CONN}" ] && nmcli connection down "${FAST_CONN}" && nmcli connection up "${FAST_CONN}"
  [ -n "${SLOW_CONN}" ] && nmcli connection down "${SLOW_CONN}" && nmcli connection up "${SLOW_CONN}"

elif [ -d /etc/netplan ]; then
  echo "Detected netplan configuration"

  NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"

  # Backup existing config
  if [ -f "${NETPLAN_FILE}" ]; then
    cp "${NETPLAN_FILE}" "${NETPLAN_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
    echo "  - Backed up existing config"
  fi

  # Create netplan configuration with metrics
  cat > "${NETPLAN_FILE}" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${FAST_IFACE}:
      dhcp4: yes
      dhcp4-overrides:
        route-metric: 50
      dhcp6: yes
      dhcp6-overrides:
        route-metric: 50
    ${SLOW_IFACE}:
      dhcp4: yes
      dhcp4-overrides:
        route-metric: 200
      dhcp6: yes
      dhcp6-overrides:
        route-metric: 200
EOF

  echo "  - Created ${NETPLAN_FILE}"
  echo ""
  echo "Step 2: Applying netplan configuration..."
  netplan apply
else
  echo "ERROR: Neither NetworkManager nor netplan detected"
  echo "Manual configuration required"
  exit 1
fi

echo ""
echo "=== New Routing Table ==="
ip route show
echo ""

echo "=== Default Route ==="
ip route show default
echo ""

echo "=== Configuration Complete ==="
echo ""
echo "✓ Fast interface (${FAST_IFACE} @ 2.5Gb) is now prioritized"
echo "✓ All traffic will prefer ${FAST_IFACE} over ${SLOW_IFACE}"
echo ""
echo "You can now optionally disconnect ${SLOW_IFACE} if you don't need redundancy"
