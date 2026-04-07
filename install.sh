#!/usr/bin/env bash
set -euo pipefail

SCRIPT_URL="https://raw.githubusercontent.com/cosmaut/bbr/main/bbr.sh"
INSTALL_PATH="/usr/local/bin/bbr"

echo -e "\033[1;32mInstalling bbr command...\033[0m"

curl -fsSL "$SCRIPT_URL" -o "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"

echo -e "\033[1;32mInstall successfully!\033[0m"
echo "Usage:"
echo "  sudo bbr enable"
echo "  sudo bbr disable"
echo "  sudo bbr status"
echo "  sudo bbr menu"
