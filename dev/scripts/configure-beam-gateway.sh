#!/bin/bash
#
# Configure Beam Node to use Workstation as Gateway
# Run this on each beam node (beam00-beam03)
#
# Usage: sudo ./configure-beam-gateway.sh <workstation-ip>
#

set -e

WORKSTATION_IP="${1:-192.168.1.100}"  # Replace with your workstation IP
INTERFACE="${INTERFACE:-enp2s0}"      # Default for beam00, beam01-03 use enp3s0

echo "=== Configure Beam Node Gateway ==="
echo "Workstation gateway IP: ${WORKSTATION_IP}"
echo "Network interface: ${INTERFACE}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: This script must be run as root (use sudo)"
  exit 1
fi

# Detect which beam node this is
HOSTNAME=$(hostname)
if [[ "${HOSTNAME}" == "beam00"* ]]; then
  INTERFACE="enp2s0"
elif [[ "${HOSTNAME}" =~ beam0[1-3] ]]; then
  INTERFACE="enp3s0"
else
  echo "WARNING: Unknown hostname ${HOSTNAME}, using interface: ${INTERFACE}"
fi

echo "Detected interface for ${HOSTNAME}: ${INTERFACE}"
echo ""

# Check if using netplan (Ubuntu default)
if [ -d /etc/netplan ]; then
  echo "Step 1: Configuring netplan..."

  NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"

  # Backup existing config
  if [ -f "${NETPLAN_FILE}" ]; then
    cp "${NETPLAN_FILE}" "${NETPLAN_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
    echo "  - Backed up existing config"
  fi

  # Create netplan configuration
  cat > "${NETPLAN_FILE}" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${INTERFACE}:
      dhcp4: no
      addresses:
        - $(ip -4 addr show ${INTERFACE} | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+')
      routes:
        - to: default
          via: ${WORKSTATION_IP}
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
EOF

  echo "  - Created ${NETPLAN_FILE}"
  echo ""
  echo "Step 2: Applying netplan configuration..."
  netplan apply
  echo "  - Configuration applied"
else
  echo "ERROR: netplan not found. Manual configuration required."
  exit 1
fi

echo ""
echo "Step 3: Testing gateway connectivity..."
if ping -c 3 "${WORKSTATION_IP}" &>/dev/null; then
  echo "  ✓ Can reach workstation gateway"
else
  echo "  ✗ WARNING: Cannot reach workstation gateway"
fi

if ping -c 3 8.8.8.8 &>/dev/null; then
  echo "  ✓ Can reach internet (8.8.8.8)"
else
  echo "  ✗ WARNING: Cannot reach internet"
fi

echo ""
echo "=== Current Network Configuration ==="
echo ""
echo "IP address:"
ip -4 addr show "${INTERFACE}"
echo ""
echo "Default route:"
ip route show default
echo ""
echo "=== Configuration Complete ==="
echo ""
echo "Gateway is now set to: ${WORKSTATION_IP}"
