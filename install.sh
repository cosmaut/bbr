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
  echo "  sudo bbr            打开交互菜单"
  echo "  sudo bbr enable     启用 BBR"
  echo "  sudo bbr disable    关闭 BBR（恢复默认/恢复备份）"
  echo "  sudo bbr status     查看当前状态"
  echo "  sudo bbr diagnose   诊断环境（含队列/缓冲/ss 摘要）"
  echo "  sudo bbr ss         查看 TCP 连接状态（ss -tin）"
  echo "  sudo bbr uninstall  卸载脚本（尝试恢复设置）"
else
  echo -e "\033[1;32mInstall successfully!\033[0m"
  echo "Usage:"
  echo "  sudo bbr            Open interactive menu"
  echo "  sudo bbr enable     Enable BBR"
  echo "  sudo bbr disable    Disable BBR (restore defaults/backup)"
  echo "  sudo bbr status     Show current status"
  echo "  sudo bbr diagnose   Diagnose environment (qdisc/buffers/ss summary)"
  echo "  sudo bbr ss         Inspect TCP connections (ss -tin)"
  echo "  sudo bbr uninstall  Uninstall (try to restore settings)"
fi
