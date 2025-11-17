#!/bin/bash
#
# Setup NAT Gateway on Workstation
# This configures the workstation to route beam cluster traffic through the fast internet connection
#
# Usage: sudo ./setup-nat-gateway.sh
#

set -e

# Configuration variables
FAST_INTERFACE="${FAST_INTERFACE:-eth0}"      # Replace with your fast internet interface name
SLOW_INTERFACE="${SLOW_INTERFACE:-eth1}"      # Replace with your switch/LAN interface name
BEAM_NETWORK="${BEAM_NETWORK:-192.168.1.0/24}" # Beam cluster network

echo "=== NAT Gateway Setup ==="
echo "Fast internet interface: ${FAST_INTERFACE}"
echo "LAN/Switch interface: ${SLOW_INTERFACE}"
echo "Beam network: ${BEAM_NETWORK}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: This script must be run as root (use sudo)"
  exit 1
fi

# Verify interfaces exist
if ! ip link show "${FAST_INTERFACE}" &>/dev/null; then
  echo "ERROR: Fast interface ${FAST_INTERFACE} not found"
  echo "Available interfaces:"
  ip link show
  exit 1
fi

if ! ip link show "${SLOW_INTERFACE}" &>/dev/null; then
  echo "ERROR: LAN interface ${SLOW_INTERFACE} not found"
  echo "Available interfaces:"
  ip link show
  exit 1
fi

echo "Step 1: Enable IP forwarding"
# Enable IP forwarding temporarily
sysctl -w net.ipv4.ip_forward=1

# Make it persistent across reboots
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  echo "  - Added to /etc/sysctl.conf for persistence"
else
  echo "  - Already configured in /etc/sysctl.conf"
fi

echo ""
echo "Step 2: Configure iptables NAT rules"

# Flush existing NAT rules (optional - be careful if you have other rules)
# iptables -t nat -F
# iptables -F FORWARD

# Enable NAT (masquerading) for traffic from beam network going out fast interface
iptables -t nat -A POSTROUTING -s "${BEAM_NETWORK}" -o "${FAST_INTERFACE}" -j MASQUERADE

# Allow forwarding from LAN to internet
iptables -A FORWARD -i "${SLOW_INTERFACE}" -o "${FAST_INTERFACE}" -j ACCEPT

# Allow established connections back
iptables -A FORWARD -i "${FAST_INTERFACE}" -o "${SLOW_INTERFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "  - NAT rules configured"
echo ""

echo "Step 3: Install iptables-persistent to save rules"
if command -v netfilter-persistent &>/dev/null; then
  echo "  - iptables-persistent already installed"
  netfilter-persistent save
  echo "  - Rules saved"
else
  echo "  - Installing iptables-persistent..."
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
  echo "  - Rules saved automatically during installation"
fi

echo ""
echo "=== Current NAT Configuration ==="
echo ""
echo "IP Forwarding status:"
sysctl net.ipv4.ip_forward
echo ""
echo "NAT rules (POSTROUTING):"
iptables -t nat -L POSTROUTING -n -v
echo ""
echo "Forward rules:"
iptables -L FORWARD -n -v
echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Verify interface names are correct (check with 'ip link show')"
echo "2. Update beam nodes to use this workstation as default gateway"
echo "3. Run ./configure-beam-gateway.sh on each beam node"
echo "4. Optionally disconnect the slow internet connection from the switch"
