#!/usr/bin/env bash
set -eu
set -o pipefail 2>/dev/null || true

VERSION="0.0.1"

SCRIPT_URL="https://raw.githubusercontent.com/cosmaut/bbr/main/bbr.sh"
INSTALL_PATH="/usr/local/bin/bbr"
SHASUM_URL="https://raw.githubusercontent.com/cosmaut/bbr/main/shasum.txt"

LANG_MODE=""
locale_value="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
forced="${BBR_LANG:-}"
if [[ "${forced}" =~ ^(zh|zh_CN|cn|chinese)$ ]] || [[ "${locale_value}" == *"zh"* || "${locale_value}" == *"ZH"* ]]; then
  LANG_MODE="zh"
else
  LANG_MODE="en"
fi

if [[ "${LANG_MODE}" == "zh" ]]; then
  echo -e "\033[1;32m正在安装 bbr v${VERSION}...\033[0m"
else
  echo -e "\033[1;32mInstalling bbr v${VERSION}...\033[0m"
fi

# Download script
TMP_SCRIPT="$(mktemp)"
curl -fsSL "$SCRIPT_URL" | tr -d '\r' > "$TMP_SCRIPT"

# Verify SHA256 checksum if shasum is available
verify_shasum() {
    if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
        if [[ "${LANG_MODE}" == "zh" ]]; then
            echo -e "\033[1;33m警告: 未找到 sha256sum/shasum，跳过完整性校验。\033[0m"
            echo "  如需验证，请手动检查: curl -fsSL $SCRIPT_URL | sha256sum"
        else
            echo -e "\033[1;33mWarning: sha256sum/shasum not found, skipping integrity check.\033[0m"
            echo "  To verify manually: curl -fsSL $SCRIPT_URL | sha256sum"
        fi
        return 0
    fi

    local expected_hash
    expected_hash="$(curl -fsSL "${SHASUM_URL}" 2>/dev/null | grep 'bbr.sh$' | awk '{print$1}' || true)"

    if [[ -z "${expected_hash}" ]]; then
        if [[ "${LANG_MODE}" == "zh" ]]; then
            echo -e "\033[1;33m警告: 无法获取校验和文件，跳过完整性校验。\033[0m"
            echo "  请访问 $SHASUM_URL 确认脚本完整性。"
        else
            echo -e "\033[1;33mWarning: Could not fetch shasum file, skipping integrity check.\033[0m"
            echo "  Please visit $SHASUM_URL to verify script integrity."
        fi
        return 0
    fi

    local actual_hash
    if command -v sha256sum >/dev/null 2>&1; then
        actual_hash="$(sha256sum "$TMP_SCRIPT" | awk '{print$1}')"
    else
        actual_hash="$(shasum -a 256 "$TMP_SCRIPT" | awk '{print$1}')"
    fi

    if [[ "${actual_hash}" != "${expected_hash}" ]]; then
        if [[ "${LANG_MODE}" == "zh" ]]; then
            echo -e "\033[1;31m错误: 校验失败！脚本可能被篡改。\033[0m"
            echo "  预期: ${expected_hash}"
            echo "  实际: ${actual_hash}"
        else
            echo -e "\033[1;31mError: Checksum verification FAILED! Script may be tampered.\033[0m"
            echo "  Expected: ${expected_hash}"
            echo "  Actual:   ${actual_hash}"
        fi
        rm -f "$TMP_SCRIPT"
        exit 1
    fi

    if [[ "${LANG_MODE}" == "zh" ]]; then
        echo -e "\033[0;32m✓ 校验通过\033[0m"
    else
        echo -e "\033[0;32m✓ Checksum verified\033[0m"
    fi
}

verify_shasum

chmod +x "$TMP_SCRIPT"
mv -f "$TMP_SCRIPT" "$INSTALL_PATH"

if [[ "${LANG_MODE}" == "zh" ]]; then
  echo -e "\033[1;32m安装完成！当前版本：v${VERSION}\033[0m"
  echo "用法:"
  echo "  sudo bbr            打开交互菜单"
  echo "  sudo bbr enable     启用 BBR"
  echo "  sudo bbr disable    关闭 BBR（恢复默认/恢复备份）"
  echo "  sudo bbr status     查看当前状态"
  echo "  sudo bbr diagnose   诊断环境（含队列/缓冲/ss 摘要）"
  echo "  sudo bbr ss         查看 TCP 连接状态（ss -tin）"
  echo "  sudo bbr version    查看版本号"
  echo "  sudo bbr uninstall  卸载脚本（尝试恢复设置）"
else
  echo -e "\033[1;32mInstall successfully! Current version: v${VERSION}\033[0m"
  echo "Usage:"
  echo "  sudo bbr            Open interactive menu"
  echo "  sudo bbr enable     Enable BBR"
  echo "  sudo bbr disable    Disable BBR (restore defaults/backup)"
  echo "  sudo bbr status     Show current status"
  echo "  sudo bbr diagnose   Diagnose environment (qdisc/buffers/ss summary)"
  echo "  sudo bbr ss         Inspect TCP connections (ss -tin)"
  echo "  sudo bbr version    Show version"
  echo "  sudo bbr uninstall  Uninstall (try to restore settings)"
fi
