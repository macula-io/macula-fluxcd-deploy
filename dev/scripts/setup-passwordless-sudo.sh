#!/bin/bash
#
# Setup Passwordless Sudo for Network Scripts
# This allows running network configuration scripts without password
#
# Usage: ./setup-passwordless-sudo.sh
# Note: You'll need to enter your password ONCE to set this up
#

set -e

SUDOERS_FILE="/etc/sudoers.d/network-scripts"
USER=$(whoami)

echo "=== Setup Passwordless Sudo for Network Scripts ==="
echo "User: ${USER}"
echo ""

# Create sudoers entry
SUDOERS_CONTENT="# Allow ${USER} to run network scripts without password
${USER} ALL=(ALL) NOPASSWD: /home/${USER}/work/github.com/macula-io/macula-gitops/scripts/prioritize-fast-interface.sh
${USER} ALL=(ALL) NOPASSWD: /home/${USER}/work/github.com/macula-io/macula-gitops/scripts/setup-nat-gateway.sh
${USER} ALL=(ALL) NOPASSWD: /usr/bin/nmcli
${USER} ALL=(ALL) NOPASSWD: /usr/bin/ip
${USER} ALL=(ALL) NOPASSWD: /usr/sbin/netplan
"

echo "Creating sudoers file: ${SUDOERS_FILE}"
echo ""
echo "Contents:"
echo "${SUDOERS_CONTENT}"
echo ""

# Use sudo tee to write the file
echo "${SUDOERS_CONTENT}" | sudo tee "${SUDOERS_FILE}" > /dev/null

# Set correct permissions (must be 0440)
sudo chmod 0440 "${SUDOERS_FILE}"

# Validate sudoers file
if sudo visudo -c -f "${SUDOERS_FILE}"; then
  echo ""
  echo "✓ Sudoers file created and validated successfully"
  echo ""
  echo "You can now run these commands without password:"
  echo "  sudo ./scripts/prioritize-fast-interface.sh"
  echo "  sudo ./scripts/setup-nat-gateway.sh"
else
  echo ""
  echo "✗ ERROR: Sudoers file validation failed!"
  echo "Removing invalid file..."
  sudo rm -f "${SUDOERS_FILE}"
  exit 1
fi
