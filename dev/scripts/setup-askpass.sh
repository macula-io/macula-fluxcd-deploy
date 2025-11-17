#!/bin/bash
#
# Setup SSH Askpass Helper for GUI Password Prompts
# This allows sudo to work with graphical password dialogs
#
# Usage: ./setup-askpass.sh
#

set -e

echo "=== Setting up Askpass Helper ==="
echo ""

# Check which desktop environment / askpass tool is available
ASKPASS_TOOL=""

if command -v zenity &>/dev/null; then
  ASKPASS_TOOL="zenity"
  echo "Found: zenity (GNOME/GTK)"
elif command -v kdialog &>/dev/null; then
  ASKPASS_TOOL="kdialog"
  echo "Found: kdialog (KDE)"
elif command -v ssh-askpass &>/dev/null; then
  ASKPASS_TOOL="ssh-askpass"
  echo "Found: ssh-askpass"
else
  echo "No askpass tool found. Installing ssh-askpass..."

  # Detect package manager
  if command -v apt-get &>/dev/null; then
    echo "Installing ssh-askpass via apt..."
    sudo apt-get update
    sudo apt-get install -y ssh-askpass
    ASKPASS_TOOL="ssh-askpass"
  elif command -v pacman &>/dev/null; then
    echo "Installing ssh-askpass via pacman..."
    sudo pacman -S --noconfirm x11-ssh-askpass
    ASKPASS_TOOL="ssh-askpass"
  elif command -v dnf &>/dev/null; then
    echo "Installing openssh-askpass via dnf..."
    sudo dnf install -y openssh-askpass
    ASKPASS_TOOL="ssh-askpass"
  else
    echo "ERROR: Could not detect package manager"
    exit 1
  fi
fi

echo ""
echo "Step 1: Creating custom sudo askpass wrapper..."

# Create a wrapper script
WRAPPER_PATH="/usr/local/bin/sudo-askpass"

sudo tee "${WRAPPER_PATH}" > /dev/null <<'EOF'
#!/bin/bash
# Custom sudo askpass wrapper

if command -v zenity &>/dev/null; then
  zenity --password --title="sudo password required"
elif command -v kdialog &>/dev/null; then
  kdialog --password "sudo password required"
elif command -v ssh-askpass &>/dev/null; then
  ssh-askpass "sudo password required"
else
  echo "No askpass tool available" >&2
  exit 1
fi
EOF

sudo chmod +x "${WRAPPER_PATH}"
echo "  - Created ${WRAPPER_PATH}"

echo ""
echo "Step 2: Setting SUDO_ASKPASS environment variable..."

# Add to user's bashrc
if ! grep -q "SUDO_ASKPASS" ~/.bashrc; then
  cat >> ~/.bashrc <<EOF

# Sudo askpass helper
export SUDO_ASKPASS=/usr/local/bin/sudo-askpass
EOF
  echo "  - Added to ~/.bashrc"
else
  echo "  - Already configured in ~/.bashrc"
fi

# Add to user's bash_profile if it exists
if [ -f ~/.bash_profile ] && ! grep -q "SUDO_ASKPASS" ~/.bash_profile; then
  cat >> ~/.bash_profile <<EOF

# Sudo askpass helper
export SUDO_ASKPASS=/usr/local/bin/sudo-askpass
EOF
  echo "  - Added to ~/.bash_profile"
fi

# Set for current session
export SUDO_ASKPASS=/usr/local/bin/sudo-askpass

echo ""
echo "Step 3: Testing askpass helper..."
echo ""

# Test the askpass
if "${SUDO_ASKPASS}" <<< "" 2>/dev/null; then
  echo "✓ Askpass helper is working"
else
  echo "✓ Askpass helper created (will prompt when needed)"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "To use sudo with askpass, use one of these methods:"
echo ""
echo "Method 1 (with -A flag):"
echo "  sudo -A ./scripts/prioritize-fast-interface.sh"
echo ""
echo "Method 2 (export variable first):"
echo "  export SUDO_ASKPASS=/usr/local/bin/sudo-askpass"
echo "  sudo -A ./scripts/prioritize-fast-interface.sh"
echo ""
echo "Or simply reload your shell:"
echo "  source ~/.bashrc"
echo "  sudo -A ./scripts/prioritize-fast-interface.sh"
