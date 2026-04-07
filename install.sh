#!/usr/bin/env bash
set -eu
set -o pipefail 2>/dev/null || true

SCRIPT_URL="https://raw.githubusercontent.com/cosmaut/bbr/main/bbr.sh"
INSTALL_PATH="/usr/local/bin/bbr"

LANG_MODE=""
locale_value="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
forced="${BBR_LANG:-}"
if [[ "${forced}" =~ ^(zh|zh_CN|cn|chinese)$ ]] || [[ "${locale_value}" == *"zh"* || "${locale_value}" == *"ZH"* ]]; then
  LANG_MODE="zh"
else
  LANG_MODE="en"
fi

if [[ "${LANG_MODE}" == "zh" ]]; then
  echo -e "\033[1;32m正在安装 bbr 命令...\033[0m"
else
  echo -e "\033[1;32mInstalling bbr command...\033[0m"
fi

curl -fsSL "$SCRIPT_URL" | tr -d '\r' > "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"

if [[ "${LANG_MODE}" == "zh" ]]; then
  echo -e "\033[1;32m安装完成！\033[0m"
  echo "用法:"
else
  echo -e "\033[1;32mInstall successfully!\033[0m"
  echo "Usage:"
fi
echo "  sudo bbr enable"
echo "  sudo bbr disable"
echo "  sudo bbr status"
echo "  sudo bbr diagnose"
echo "  sudo bbr ss"
echo "  sudo bbr menu"
