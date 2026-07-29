#!/bin/bash
# ----------------------------------------------------------------------------
# Script Name: install.sh
# Description: Install user_init script (Debian or Alpine version)
# Author: peterweissdk
# Usage: curl -fsSL https://raw.githubusercontent.com/peterweissdk/user_init/main/install.sh | bash
# ----------------------------------------------------------------------------

SCRIPT_NAME="user_init"
SCRIPT_URL_DEBIAN="https://raw.githubusercontent.com/peterweissdk/user_init/main/user_init.sh"
SCRIPT_URL_ALPINE="https://raw.githubusercontent.com/peterweissdk/user_init/main/user_init-alpine.sh"
DEFAULT_PATH="/usr/local/bin"

echo ""
echo "📦 Installing ${SCRIPT_NAME}..."
echo ""

# Prompt for system type (read from tty to work with pipe)
echo "Select your system type:"
echo "  1) Debian/Ubuntu (apt-based systems)"
echo "  2) Alpine Linux (apk-based systems)"
echo ""

if [ -t 0 ]; then
    # Interactive mode
    read -p "Enter choice [1/2]: " system_choice
else
    # Piped mode - read from tty
    read -p "Enter choice [1/2]: " system_choice </dev/tty
fi

case $system_choice in
    1)
        SCRIPT_URL="$SCRIPT_URL_DEBIAN"
        echo "📋 Selected: Debian/Ubuntu version"
        ;;
    2)
        SCRIPT_URL="$SCRIPT_URL_ALPINE"
        echo "📋 Selected: Alpine Linux version"
        ;;
    *)
        echo "⛔ Invalid choice. Please enter 1 or 2."
        exit 1
        ;;
esac

echo ""

# Prompt for install path (read from tty to work with pipe)
if [ -t 0 ]; then
    # Interactive mode
    read -p "📁 Install path [${DEFAULT_PATH}]: " install_path
else
    # Piped mode - read from tty
    read -p "📁 Install path [${DEFAULT_PATH}]: " install_path </dev/tty
fi
install_path="${install_path:-$DEFAULT_PATH}"

# Create temp file
tmp_file=$(mktemp)
trap "rm -f $tmp_file" EXIT

# Download the script
echo "📥 Downloading ${SCRIPT_NAME}..."
if ! curl -fsSL "$SCRIPT_URL" -o "$tmp_file"; then
    echo "⛔ Failed to download ${SCRIPT_NAME}"
    exit 1
fi

# Install the script
echo "⚙️  Installing to ${install_path}/${SCRIPT_NAME}..."
if [ -w "$install_path" ]; then
    # User has write access
    if cp "$tmp_file" "$install_path/$SCRIPT_NAME" && chmod 755 "$install_path/$SCRIPT_NAME"; then
        echo "✅ Script installed successfully to ${install_path}/${SCRIPT_NAME}"
    else
        echo "⛔ Failed to install script"
        exit 1
    fi
elif sudo -n true 2>/dev/null; then
    # User has passwordless sudo
    if sudo cp "$tmp_file" "$install_path/$SCRIPT_NAME" && sudo chmod 755 "$install_path/$SCRIPT_NAME" && sudo chown root:root "$install_path/$SCRIPT_NAME"; then
        echo "✅ Script installed successfully to ${install_path}/${SCRIPT_NAME}"
    else
        echo "⛔ Failed to install script"
        exit 1
    fi
else
    # User needs to enter password for sudo
    echo "You need root privileges to install the script in ${install_path}."
    if sudo cp "$tmp_file" "$install_path/$SCRIPT_NAME" && sudo chmod 755 "$install_path/$SCRIPT_NAME" && sudo chown root:root "$install_path/$SCRIPT_NAME"; then
        echo "✅ Script installed successfully to ${install_path}/${SCRIPT_NAME}"
    else
        echo "⛔ Failed to install script"
        exit 1
    fi
fi

echo ""
echo "🚀 Run 'sudo ${SCRIPT_NAME}' to manage users on your system."
echo ""
