#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="/etc/sysctl.d/99-bbr-standalone.conf"
SYSCTL_CONF="/etc/sysctl.conf"
INSTALL_PATH="/usr/local/bin/bbr"
SYSTEMD_SERVICE_NAME="bbr-qdisc.service"
SYSTEMD_SERVICE_PATH="/etc/systemd/system/${SYSTEMD_SERVICE_NAME}"

green="\033[0;32m"
yellow="\033[0;33m"
red="\033[0;31m"
plain="\033[0m"

LANG_MODE=""

detect_language() {
    local forced locale_value
    forced="${BBR_LANG:-}"
    if [[ "${forced}" =~ ^(zh|zh_CN|cn|chinese)$ ]]; then
        LANG_MODE="zh"
        return 0
    fi
    if [[ "${forced}" =~ ^(en|en_US|english)$ ]]; then
        LANG_MODE="en"
        return 0
    fi
    locale_value="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
    if [[ "${locale_value}" == *"zh"* || "${locale_value}" == *"ZH"* ]]; then
        LANG_MODE="zh"
        return 0
    fi
    LANG_MODE="en"
    return 0
}

t() {
    local key
    key="${1:?}"
    case "${LANG_MODE}:${key}" in
        zh:only_linux) echo "此脚本仅支持 Linux 系统。" ;;
        en:only_linux) echo "This script supports Linux only." ;;

        zh:require_root) echo "请使用 root 用户或 sudo 执行此脚本。" ;;
        en:require_root) echo "Please run this script as root or via sudo." ;;

        zh:no_sysctl) echo "未找到 sysctl 命令，无法继续。" ;;
        en:no_sysctl) echo "sysctl not found; cannot continue." ;;

        zh:status_current_qdisc) echo "当前队列调度算法: %s" ;;
        en:status_current_qdisc) echo "Current qdisc: %s" ;;
        zh:status_current_cc) echo "当前拥塞控制算法: %s" ;;
        en:status_current_cc) echo "Current congestion control: %s" ;;
        zh:available_cc) echo "系统支持的拥塞控制算法:" ;;
        en:available_cc) echo "Available congestion control algorithms:" ;;

        zh:bbr_cc_enabled) echo "BBR 拥塞控制已启用。" ;;
        en:bbr_cc_enabled) echo "BBR congestion control is enabled." ;;
        zh:bbr_cc_disabled) echo "BBR 拥塞控制未启用。" ;;
        en:bbr_cc_disabled) echo "BBR congestion control is not enabled." ;;

        zh:bbr_qdisc_optimized) echo "BBR 队列调度已优化（fq/cake/fq_codel）。" ;;
        en:bbr_qdisc_optimized) echo "BBR qdisc is optimized (fq/cake/fq_codel)." ;;
        zh:bbr_qdisc_not_optimized) echo "BBR 已启用，但队列调度未优化（建议 fq/cake/fq_codel）。" ;;
        en:bbr_qdisc_not_optimized) echo "BBR is enabled, but qdisc is not optimized (recommend fq/cake/fq_codel)." ;;

        zh:default_iface) echo "默认路由网卡: %s" ;;
        en:default_iface) echo "Default route interface: %s" ;;
        zh:iface_root_qdisc) echo "网卡根队列调度: %s" ;;
        en:iface_root_qdisc) echo "Interface root qdisc: %s" ;;

        zh:kernel_version) echo "内核版本(major.minor): %s" ;;
        en:kernel_version) echo "Kernel version (major.minor): %s" ;;

        zh:socket_buf_small) echo "检测到 socket 缓冲上限偏小（rmem_max/wmem_max < 4MB），长 RTT/抖动链路下单流吞吐可能很差。" ;;
        en:socket_buf_small) echo "Socket buffer limits look small (rmem_max/wmem_max < 4MB); single-flow throughput may be poor on high-RTT/jittery paths." ;;

        zh:bbr_not_optimized_warn) echo "检测到 BBR 未配合 fq/cake/fq_codel，重负载场景下可能更抖或更容易触发上游限速/丢包。" ;;
        en:bbr_not_optimized_warn) echo "BBR is not paired with fq/cake/fq_codel; performance may be unstable under load or trigger upstream policing/loss more easily." ;;

        zh:ss_summary) echo "ss -tin（ESTAB，最多显示 5 条连接）:" ;;
        en:ss_summary) echo "ss -tin (ESTAB, showing up to 5 connections):" ;;
        zh:ss_not_found) echo "未找到 ss 命令（iproute2），无法查看连接状态。" ;;
        en:ss_not_found) echo "ss not found (iproute2); cannot inspect TCP connections." ;;
        zh:ss_port_prompt) echo "过滤端口（留空表示全部已建立连接）: " ;;
        en:ss_port_prompt) echo "Filter by port (empty for all established): " ;;
        zh:port_invalid) echo "端口无效。" ;;
        en:port_invalid) echo "Invalid port." ;;

        zh:press_enter) echo "按回车返回菜单..." ;;
        en:press_enter) echo "Press Enter to return to menu..." ;;

        zh:already_enabled) echo "BBR 已经处于启用状态。" ;;
        en:already_enabled) echo "BBR is already enabled." ;;
        zh:bbr_not_supported) echo "当前系统未检测到 bbr 支持，请确认内核版本 ≥ 4.9 且已启用 tcp_bbr。" ;;
        en:bbr_not_supported) echo "BBR is not supported on this system. Ensure kernel >= 4.9 and tcp_bbr is available." ;;
        zh:sysctl_reload_failed) echo "系统参数重载失败，请手动检查 sysctl 配置。" ;;
        en:sysctl_reload_failed) echo "Failed to reload sysctl settings. Please check sysctl configuration manually." ;;
        zh:iface_mq_warn) echo "检测到网卡 %s 根队列为 %s，脚本不会强制替换。请手动确认队列调度是否适配 BBR。" ;;
        en:iface_mq_warn) echo "Interface %s has root qdisc %s; not forcing replacement. Please verify qdisc suitability for BBR." ;;
        zh:iface_set_fq_warn) echo "未能为网卡 %s 设置 root fq，BBR 可能无法获得最佳效果。" ;;
        en:iface_set_fq_warn) echo "Failed to set root fq on interface %s; BBR may not reach best performance." ;;
        zh:enable_success) echo "BBR 已成功启用。" ;;
        en:enable_success) echo "BBR has been enabled successfully." ;;
        zh:enable_failed) echo "BBR 启用失败，请检查内核是否支持 tcp_bbr。" ;;
        en:enable_failed) echo "Failed to enable BBR. Please check whether tcp_bbr is supported." ;;

        zh:no_need_disable) echo "未找到脚本配置文件且当前非 BBR，无需关闭。" ;;
        en:no_need_disable) echo "No script config found and BBR is not enabled; nothing to disable." ;;
        zh:disable_success) echo "BBR 已关闭，并恢复为非 BBR 拥塞控制。" ;;
        en:disable_success) echo "BBR has been disabled and reverted to a non-BBR congestion control." ;;
        zh:disable_failed) echo "关闭 BBR 失败，请手动检查系统配置。" ;;
        en:disable_failed) echo "Failed to disable BBR. Please check system configuration manually." ;;

        zh:uninstall_done) echo "已卸载完成。" ;;
        en:uninstall_done) echo "Uninstall completed." ;;

        zh:systemd_not_available) echo "未检测到 systemd（或 systemctl 不可用），跳过开机持久化设置。" ;;
        en:systemd_not_available) echo "systemd not detected (or systemctl not available); skipping boot persistence." ;;
        zh:systemd_persist_enabled) echo "已启用 systemd 持久化：重启后将自动为默认网卡设置 root fq。" ;;
        en:systemd_persist_enabled) echo "Enabled systemd persistence: will set root fq on default interface after reboot." ;;
        zh:systemd_persist_enable_failed) echo "systemd 持久化启用失败，请手动检查 systemd 服务状态。" ;;
        en:systemd_persist_enable_failed) echo "Failed to enable systemd persistence; please check systemd service status." ;;
        zh:systemd_persist_removed) echo "已移除 systemd 持久化设置。" ;;
        en:systemd_persist_removed) echo "Removed systemd persistence." ;;
        zh:systemd_persist_remove_failed) echo "移除 systemd 持久化设置失败，请手动检查。" ;;
        en:systemd_persist_remove_failed) echo "Failed to remove systemd persistence; please check manually." ;;
        zh:apply_qdisc_no_iface) echo "未检测到默认路由网卡，跳过 qdisc 设置。" ;;
        en:apply_qdisc_no_iface) echo "Default route interface not detected; skipping qdisc setup." ;;
        zh:apply_qdisc_tc_missing) echo "未找到 tc 命令（iproute2），跳过 qdisc 设置。" ;;
        en:apply_qdisc_tc_missing) echo "tc not found (iproute2); skipping qdisc setup." ;;
        zh:apply_qdisc_iface_ok) echo "网卡 %s 根队列调度已是 %s，无需修改。" ;;
        en:apply_qdisc_iface_ok) echo "Interface %s already has root qdisc %s; no change needed." ;;
        zh:apply_qdisc_iface_set) echo "已为网卡 %s 设置 root fq。" ;;
        en:apply_qdisc_iface_set) echo "Set root fq on interface %s." ;;
        zh:apply_qdisc_iface_set_failed) echo "未能为网卡 %s 设置 root fq（可能被网络管理覆盖或内核不支持）。" ;;
        en:apply_qdisc_iface_set_failed) echo "Failed to set root fq on interface %s (may be overridden by network manager or unsupported)." ;;

        zh:help_header) echo "用法:" ;;
        en:help_header) echo "Usage:" ;;
        zh:help_enable) echo "启用 BBR" ;;
        en:help_enable) echo "Enable BBR" ;;
        zh:help_disable) echo "关闭 BBR" ;;
        en:help_disable) echo "Disable BBR" ;;
        zh:help_uninstall) echo "卸载脚本（并尝试恢复启用前设置）" ;;
        en:help_uninstall) echo "Uninstall (and try to restore previous settings)" ;;
        zh:help_status) echo "查看状态" ;;
        en:help_status) echo "Show status" ;;
        zh:help_diagnose) echo "诊断环境（只读输出）" ;;
        en:help_diagnose) echo "Diagnose environment (read-only output)" ;;
        zh:help_ss) echo "查看 TCP 连接状态（ss -tin）" ;;
        en:help_ss) echo "Inspect TCP connections (ss -tin)" ;;
        zh:help_menu) echo "打开交互菜单" ;;
        en:help_menu) echo "Open interactive menu" ;;
        zh:help_help) echo "查看帮助" ;;
        en:help_help) echo "Show help" ;;

        zh:menu_title) echo "BBR 管理脚本" ;;
        en:menu_title) echo "BBR Manager" ;;
        zh:menu_prompt) echo "请选择操作: " ;;
        en:menu_prompt) echo "Select an option: " ;;
        zh:menu_enable) echo "启用 BBR" ;;
        en:menu_enable) echo "Enable BBR" ;;
        zh:menu_disable) echo "关闭 BBR" ;;
        en:menu_disable) echo "Disable BBR" ;;
        zh:menu_status) echo "查看状态" ;;
        en:menu_status) echo "Show status" ;;
        zh:menu_diagnose) echo "诊断环境（含 ss -tin 摘要）" ;;
        en:menu_diagnose) echo "Diagnose (includes ss -tin summary)" ;;
        zh:menu_ss) echo "查看 TCP 连接（ss -tin）" ;;
        en:menu_ss) echo "Inspect TCP connections (ss -tin)" ;;
        zh:menu_uninstall) echo "卸载脚本（尝试恢复设置）" ;;
        en:menu_uninstall) echo "Uninstall (try to restore settings)" ;;
        zh:menu_help) echo "帮助" ;;
        en:menu_help) echo "Help" ;;
        zh:menu_language) echo "设置语言" ;;
        en:menu_language) echo "Language" ;;
        zh:menu_exit) echo "退出" ;;
        en:menu_exit) echo "Exit" ;;
        zh:language_title) echo "语言设置" ;;
        en:language_title) echo "Language Settings" ;;
        zh:language_current) echo "当前语言: %s" ;;
        en:language_current) echo "Current language: %s" ;;
        zh:language_option_zh) echo "中文" ;;
        en:language_option_zh) echo "Chinese" ;;
        zh:language_option_en) echo "英文" ;;
        en:language_option_en) echo "English" ;;
        zh:language_prompt) echo "请选择语言（仅对当前会话生效）: " ;;
        en:language_prompt) echo "Select language (session-only): " ;;
        zh:language_set_zh) echo "已切换为中文。" ;;
        en:language_set_zh) echo "Switched to Chinese." ;;
        zh:language_set_en) echo "已切换为英文。" ;;
        en:language_set_en) echo "Switched to English." ;;
        zh:language_cancel) echo "已取消。" ;;
        en:language_cancel) echo "Cancelled." ;;
        zh:language_invalid) echo "无效选项。" ;;
        en:language_invalid) echo "Invalid option." ;;

        zh:invalid_option) echo "无效选项，请重新选择。" ;;
        en:invalid_option) echo "Invalid option. Please select again." ;;
        zh:unknown_command) echo "未知命令: %s" ;;
        en:unknown_command) echo "Unknown command: %s" ;;
        *) echo "${key}" ;;
    esac
}

tf() {
    local key
    key="${1:?}"
    shift || true
    printf "$(t "${key}")" "$@"
}

detect_language

set_language_menu() {
    local choice current_label
    current_label="$(t language_option_en)"
    if [[ "${LANG_MODE}" == "zh" ]]; then
        current_label="$(t language_option_zh)"
    fi
    echo "=============================="
    echo "       $(t language_title)"
    echo "=============================="
    echo "$(tf language_current "${current_label}")"
    echo "1. $(t language_option_zh)"
    echo "2. $(t language_option_en)"
    echo "0. $(t menu_exit)"
    read -r -p "$(t language_prompt)" choice
    case "${choice}" in
        1)
            LANG_MODE="zh"
            export BBR_LANG="zh"
            log_info "$(t language_set_zh)"
            ;;
        2)
            LANG_MODE="en"
            export BBR_LANG="en"
            log_info "$(t language_set_en)"
            ;;
        0)
            log_info "$(t language_cancel)"
            ;;
        *)
            log_error "$(t language_invalid)"
            ;;
    esac
}

# 中文说明：输出信息日志。
log_info() {
    echo -e "${green}$1${plain}"
}

# 中文说明：输出警告日志。
log_warn() {
    echo -e "${yellow}$1${plain}"
}

# 中文说明：输出错误日志。
log_error() {
    echo -e "${red}$1${plain}" >&2
}

# 中文说明：确保脚本运行在 Linux 环境。
require_linux() {
    if [[ "$(uname -s)" != "Linux" ]]; then
        log_error "$(t only_linux)"
        exit 1
    fi
}

# 中文说明：确保使用 root 权限执行，因为需要修改内核网络参数。
require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        log_error "$(t require_root)"
        exit 1
    fi
}

# 中文说明：确保系统安装了 sysctl 命令。
require_sysctl() {
    if ! command -v sysctl >/dev/null 2>&1; then
        log_error "$(t no_sysctl)"
        exit 1
    fi
}

require_command() {
    local command_name
    command_name="${1:?}"
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

systemd_available() {
    if ! require_command systemctl; then
        return 1
    fi
    [[ -d /run/systemd/system ]]
}

get_self_path() {
    local self_path
    self_path="${INSTALL_PATH}"
    if [[ -x "${self_path}" ]]; then
        echo "${self_path}"
        return 0
    fi
    self_path="${BASH_SOURCE[0]}"
    if require_command readlink; then
        self_path="$(readlink -f "${self_path}" 2>/dev/null || true)"
    fi
    if [[ -n "${self_path}" ]]; then
        echo "${self_path}"
        return 0
    fi
    return 1
}

install_systemd_persistence() {
    local self_path

    if ! systemd_available; then
        log_warn "$(t systemd_not_available)"
        return 0
    fi

    self_path="$(get_self_path 2>/dev/null || true)"
    if [[ -z "${self_path}" ]]; then
        log_warn "$(t systemd_persist_enable_failed)"
        return 0
    fi

    mkdir -p "$(dirname "${SYSTEMD_SERVICE_PATH}")"

    cat > "${SYSTEMD_SERVICE_PATH}" <<EOF
[Unit]
Description=BBR qdisc persistence (set root fq on default interface)
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=${self_path} apply-qdisc

[Install]
WantedBy=multi-user.target
EOF

    if systemctl daemon-reload >/dev/null 2>&1 \
        && systemctl enable --now "${SYSTEMD_SERVICE_NAME}" >/dev/null 2>&1; then
        log_info "$(t systemd_persist_enabled)"
        return 0
    fi

    log_warn "$(t systemd_persist_enable_failed)"
    return 0
}

remove_systemd_persistence() {
    if ! systemd_available; then
        return 0
    fi

    systemctl disable --now "${SYSTEMD_SERVICE_NAME}" >/dev/null 2>&1 || true
    rm -f "${SYSTEMD_SERVICE_PATH}" >/dev/null 2>&1 || true
    systemctl daemon-reload >/dev/null 2>&1 || true

    if [[ ! -f "${SYSTEMD_SERVICE_PATH}" ]]; then
        log_info "$(t systemd_persist_removed)"
        return 0
    fi

    log_warn "$(t systemd_persist_remove_failed)"
    return 0
}

# 中文说明：读取当前队列调度算法，如果读取失败则返回默认值。
get_current_qdisc() {
    local value
    value="$(sysctl -n net.core.default_qdisc 2>/dev/null || true)"
    if [[ -z "${value}" ]]; then
        value="pfifo_fast"
    fi
    echo "${value}"
}

# 中文说明：读取当前拥塞控制算法，如果读取失败则返回默认值。
get_current_congestion() {
    local value
    value="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true)"
    if [[ -z "${value}" ]]; then
        value="cubic"
    fi
    echo "${value}"
}

get_primary_interface() {
    local line prev token
    if ! require_command ip; then
        return 1
    fi
    while IFS= read -r line; do
        [[ -z "${line}" ]] && continue
        set -- ${line}
        prev=""
        for token in "$@"; do
            if [[ "${prev}" == "dev" ]]; then
                echo "${token}"
                return 0
            fi
            prev="${token}"
        done
    done < <(ip route show default 2>/dev/null || true)
    return 1
}

get_interface_root_qdisc() {
    local iface first_line token prev
    iface="${1:?}"
    if ! require_command tc; then
        return 1
    fi
    first_line="$(tc qdisc show dev "${iface}" 2>/dev/null | head -n 1 || true)"
    [[ -z "${first_line}" ]] && return 1
    set -- ${first_line}
    prev=""
    for token in "$@"; do
        if [[ "${prev}" == "qdisc" ]]; then
            echo "${token}"
            return 0
        fi
        prev="${token}"
    done
    return 1
}

is_bbr_supported() {
    local algorithms
    algorithms="$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || true)"
    if [[ " ${algorithms} " == *" bbr "* ]]; then
        return 0
    fi
    if require_command modprobe; then
        modprobe tcp_bbr >/dev/null 2>&1 || true
    fi
    algorithms="$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || true)"
    [[ " ${algorithms} " == *" bbr "* ]]
}

# 中文说明：检查当前内核是否已经启用 BBR。
is_bbr_enabled() {
    [[ "$(get_current_congestion)" == "bbr" ]]
}

is_bbr_optimized() {
    local current_qdisc primary_iface iface_qdisc
    if ! is_bbr_enabled; then
        return 1
    fi
    current_qdisc="$(get_current_qdisc)"
    primary_iface="$(get_primary_interface 2>/dev/null || true)"
    if [[ -n "${primary_iface}" ]] && require_command tc; then
        iface_qdisc="$(get_interface_root_qdisc "${primary_iface}" 2>/dev/null || true)"
        [[ -n "${iface_qdisc}" ]] && [[ "${iface_qdisc}" =~ ^(fq|cake|fq_codel)$ ]]
        return $?
    fi
    [[ "${current_qdisc}" =~ ^(fq|cake|fq_codel)$ ]]
}

get_kernel_major_minor() {
    local release version major minor
    release="$(uname -r 2>/dev/null || true)"
    version="${release%%-*}"
    major="${version%%.*}"
    minor="${version#*.}"
    minor="${minor%%.*}"
    if [[ "${major}" =~ ^[0-9]+$ ]] && [[ "${minor}" =~ ^[0-9]+$ ]]; then
        echo "${major}.${minor}"
        return 0
    fi
    return 1
}

# 中文说明：应用 sysctl 配置，优先使用 --system，失败时退回 -p。
reload_sysctl() {
    if sysctl --system >/dev/null 2>&1; then
        return 0
    fi

    if [[ -f "${SYSCTL_CONF}" ]] && sysctl -p "${SYSCTL_CONF}" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

# 中文说明：显示当前 BBR 状态与关键内核参数。
show_status() {
    local current_qdisc current_congestion
    current_qdisc="$(get_current_qdisc)"
    current_congestion="$(get_current_congestion)"

    echo "$(tf status_current_qdisc "${current_qdisc}")"
    echo "$(tf status_current_cc "${current_congestion}")"

    if sysctl net.ipv4.tcp_available_congestion_control >/dev/null 2>&1; then
        echo "$(t available_cc)"
        sysctl -n net.ipv4.tcp_available_congestion_control
    fi

    if is_bbr_enabled; then
        log_info "$(t bbr_cc_enabled)"
        if is_bbr_optimized; then
            log_info "$(t bbr_qdisc_optimized)"
        else
            log_warn "$(t bbr_qdisc_not_optimized)"
        fi
    else
        log_warn "$(t bbr_cc_disabled)"
    fi

    if require_command ip; then
        local primary_iface iface_qdisc
        primary_iface="$(get_primary_interface 2>/dev/null || true)"
        if [[ -n "${primary_iface}" ]]; then
            echo "$(tf default_iface "${primary_iface}")"
            if require_command tc; then
                iface_qdisc="$(get_interface_root_qdisc "${primary_iface}" 2>/dev/null || true)"
                [[ -n "${iface_qdisc}" ]] && echo "$(tf iface_root_qdisc "${iface_qdisc}")"
            fi
        fi
    fi
}

diagnose() {
    local kernel_version primary_iface iface_qdisc rmem_max wmem_max
    kernel_version="$(get_kernel_major_minor 2>/dev/null || true)"
    [[ -n "${kernel_version}" ]] && echo "$(tf kernel_version "${kernel_version}")"

    echo "net.ipv4.tcp_congestion_control: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true)"
    echo "net.core.default_qdisc: $(sysctl -n net.core.default_qdisc 2>/dev/null || true)"
    echo "net.ipv4.tcp_window_scaling: $(sysctl -n net.ipv4.tcp_window_scaling 2>/dev/null || true)"
    echo "net.ipv4.tcp_mtu_probing: $(sysctl -n net.ipv4.tcp_mtu_probing 2>/dev/null || true)"
    echo "net.ipv4.tcp_rmem: $(sysctl -n net.ipv4.tcp_rmem 2>/dev/null || true)"
    echo "net.ipv4.tcp_wmem: $(sysctl -n net.ipv4.tcp_wmem 2>/dev/null || true)"
    echo "net.core.rmem_max: $(sysctl -n net.core.rmem_max 2>/dev/null || true)"
    echo "net.core.wmem_max: $(sysctl -n net.core.wmem_max 2>/dev/null || true)"

    primary_iface="$(get_primary_interface 2>/dev/null || true)"
    if [[ -n "${primary_iface}" ]]; then
        echo "$(tf default_iface "${primary_iface}")"
        if require_command tc; then
            iface_qdisc="$(get_interface_root_qdisc "${primary_iface}" 2>/dev/null || true)"
            [[ -n "${iface_qdisc}" ]] && echo "$(tf iface_root_qdisc "${iface_qdisc}")"
            tc -s qdisc show dev "${primary_iface}" 2>/dev/null || true
        fi
    fi

    rmem_max="$(sysctl -n net.core.rmem_max 2>/dev/null || true)"
    wmem_max="$(sysctl -n net.core.wmem_max 2>/dev/null || true)"
    if [[ "${rmem_max}" =~ ^[0-9]+$ ]] && [[ "${wmem_max}" =~ ^[0-9]+$ ]]; then
        if (( rmem_max < 4194304 || wmem_max < 4194304 )); then
            log_warn "$(t socket_buf_small)"
        fi
    fi
    if is_bbr_enabled && ! is_bbr_optimized; then
        log_warn "$(t bbr_not_optimized_warn)"
    fi

    if require_command ss; then
        echo "$(t ss_summary)"
        ss -tin state established 2>/dev/null | head -n 20 || true
    fi
}

show_ss_tin() {
    local port port_pattern line1 line2 printed
    if ! require_command ss; then
        log_error "$(t ss_not_found)"
        return 1
    fi

    read -r -p "$(t ss_port_prompt)" port
    if [[ -z "${port}" ]]; then
        ss -tin state established 2>/dev/null | head -n 60 || true
        return 0
    fi

    if ! [[ "${port}" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        log_error "$(t port_invalid)"
        return 1
    fi

    port_pattern=":${port}"
    printed=0
    ss -tin state established 2>/dev/null | awk -v p="${port_pattern}" '
        function print_pair(a, b) { print a; print b; }
        {
            line1=$0
            if (getline line2 <= 0) exit
            if (index(line1, p) || index(line2, p)) {
                print_pair(line1, line2)
                printed++
                if (printed >= 10) exit
            }
        }
        END { if (printed == 0) exit 2 }
    ' || true
}

pause_return() {
    read -r -p "$(t press_enter)" _
}

# 中文说明：启用 BBR，并记录启用前的原始设置，方便后续恢复。
enable_bbr() {
    local current_qdisc current_congestion primary_iface iface_qdisc

    if is_bbr_enabled && is_bbr_optimized && [[ -f "${CONFIG_FILE}" ]]; then
        log_info "$(t already_enabled)"
        return 0
    fi

    current_qdisc="$(get_current_qdisc)"
    current_congestion="$(get_current_congestion)"
    primary_iface="$(get_primary_interface 2>/dev/null || true)"
    iface_qdisc=""
    if [[ -n "${primary_iface}" ]] && require_command tc; then
        iface_qdisc="$(get_interface_root_qdisc "${primary_iface}" 2>/dev/null || true)"
    fi

    if ! is_bbr_supported; then
        log_error "$(t bbr_not_supported)"
        return 1
    fi

    mkdir -p "$(dirname "${CONFIG_FILE}")"
    {
        echo "#backup default_qdisc=${current_qdisc}"
        echo "#backup congestion=${current_congestion}"
        [[ -n "${primary_iface}" ]] && echo "#backup iface=${primary_iface}"
        [[ -n "${iface_qdisc}" ]] && echo "#backup iface_qdisc=${iface_qdisc}"
        echo "net.core.default_qdisc = fq"
        echo "net.ipv4.tcp_congestion_control = bbr"
    } > "${CONFIG_FILE}"

    if ! reload_sysctl; then
        log_error "$(t sysctl_reload_failed)"
        return 1
    fi

    sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1 || true
    sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1 || true

    if [[ -n "${primary_iface}" ]] && require_command tc; then
        if [[ "${iface_qdisc}" =~ ^(mq|noqueue)$ ]]; then
            log_warn "$(tf iface_mq_warn "${primary_iface}" "${iface_qdisc}")"
        else
            if ! tc qdisc replace dev "${primary_iface}" root fq >/dev/null 2>&1; then
                log_warn "$(tf iface_set_fq_warn "${primary_iface}")"
            fi
        fi
    fi

    install_systemd_persistence

    if [[ "$(get_current_congestion)" == "bbr" ]]; then
        log_info "$(t enable_success)"
        return 0
    fi

    log_error "$(t enable_failed)"
    return 1
}

# 中文说明：关闭 BBR，优先恢复脚本保存的原始值；如果没有备份，则回退到常见默认值。
disable_bbr() {
    local old_qdisc old_congestion old_iface old_iface_qdisc legacy_settings legacy_qdisc legacy_congestion current_congestion

    current_congestion="$(get_current_congestion)"

    if [[ -f "${CONFIG_FILE}" ]]; then
        old_qdisc="$(grep -E '^#backup default_qdisc=' "${CONFIG_FILE}" 2>/dev/null | head -n 1 | cut -d'=' -f2- || true)"
        old_congestion="$(grep -E '^#backup congestion=' "${CONFIG_FILE}" 2>/dev/null | head -n 1 | cut -d'=' -f2- || true)"
        old_iface="$(grep -E '^#backup iface=' "${CONFIG_FILE}" 2>/dev/null | head -n 1 | cut -d'=' -f2- || true)"
        old_iface_qdisc="$(grep -E '^#backup iface_qdisc=' "${CONFIG_FILE}" 2>/dev/null | head -n 1 | cut -d'=' -f2- || true)"

        if [[ -z "${old_qdisc}" || -z "${old_congestion}" ]]; then
            legacy_settings="$(head -n 1 "${CONFIG_FILE}" 2>/dev/null | tr -d '# ' || true)"
            if [[ -n "${legacy_settings}" && "${legacy_settings}" == *:* ]]; then
                legacy_qdisc="${legacy_settings%:*}"
                legacy_congestion="${legacy_settings#*:}"
                [[ -z "${old_qdisc}" ]] && old_qdisc="${legacy_qdisc}"
                [[ -z "${old_congestion}" ]] && old_congestion="${legacy_congestion}"
            fi
        fi

        [[ -z "${old_qdisc}" ]] && old_qdisc="pfifo_fast"
        [[ -z "${old_congestion}" ]] && old_congestion="cubic"
        [[ "${old_congestion}" == "bbr" ]] && old_congestion="cubic"

        rm -f "${CONFIG_FILE}"

        sysctl -w "net.core.default_qdisc=${old_qdisc}" >/dev/null 2>&1 || true
        sysctl -w "net.ipv4.tcp_congestion_control=${old_congestion}" >/dev/null 2>&1 || true

        if [[ -n "${old_iface}" && -n "${old_iface_qdisc}" ]] && require_command tc; then
            tc qdisc replace dev "${old_iface}" root "${old_iface_qdisc}" >/dev/null 2>&1 || true
        fi
    else
        if [[ "${current_congestion}" != "bbr" ]]; then
            log_warn "$(t no_need_disable)"
            return 0
        fi
        sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null 2>&1 || true
    fi

    remove_systemd_persistence

    if [[ "$(get_current_congestion)" != "bbr" ]]; then
        log_info "$(t disable_success)"
        return 0
    fi

    log_error "$(t disable_failed)"
    return 1
}

uninstall_bbr() {
    local current_congestion
    current_congestion="$(get_current_congestion)"
    if [[ -f "${CONFIG_FILE}" || "${current_congestion}" == "bbr" ]]; then
        disable_bbr || true
    fi
    rm -f "${CONFIG_FILE}" || true
    if [[ -f "${INSTALL_PATH}" ]]; then
        rm -f "${INSTALL_PATH}" || true
    fi
    log_info "$(t uninstall_done)"
}

apply_qdisc() {
    local primary_iface iface_qdisc

    primary_iface="$(get_primary_interface 2>/dev/null || true)"
    if [[ -z "${primary_iface}" ]]; then
        log_warn "$(t apply_qdisc_no_iface)"
        return 0
    fi
    if ! require_command tc; then
        log_warn "$(t apply_qdisc_tc_missing)"
        return 0
    fi

    iface_qdisc="$(get_interface_root_qdisc "${primary_iface}" 2>/dev/null || true)"
    if [[ -n "${iface_qdisc}" ]] && [[ "${iface_qdisc}" == "fq" ]]; then
        log_info "$(tf apply_qdisc_iface_ok "${primary_iface}" "${iface_qdisc}")"
        return 0
    fi
    if [[ -n "${iface_qdisc}" ]] && [[ "${iface_qdisc}" =~ ^(mq|noqueue)$ ]]; then
        log_warn "$(tf iface_mq_warn "${primary_iface}" "${iface_qdisc}")"
        return 0
    fi

    if tc qdisc replace dev "${primary_iface}" root fq >/dev/null 2>&1; then
        log_info "$(tf apply_qdisc_iface_set "${primary_iface}")"
        return 0
    fi

    log_warn "$(tf apply_qdisc_iface_set_failed "${primary_iface}")"
    return 0
}

# 中文说明：显示脚本帮助信息。
show_help() {
    echo "$(t help_header)"
    echo "  sudo bbr               $(t help_menu)"
    echo "  sudo bash bbr.sh enable    $(t help_enable)"
    echo "  sudo bash bbr.sh disable   $(t help_disable)"
    echo "  sudo bash bbr.sh uninstall $(t help_uninstall)"
    echo "  sudo bash bbr.sh status    $(t help_status)"
    echo "  sudo bash bbr.sh diagnose  $(t help_diagnose)"
    echo "  sudo bash bbr.sh ss        $(t help_ss)"
    echo "  sudo bash bbr.sh menu      $(t help_menu)"
    echo "  sudo bash bbr.sh help      $(t help_help)"
}

# 中文说明：提供简单的交互菜单，便于直接执行。
show_menu() {
    local choice
    while true; do
        echo "=============================="
        echo "       $(t menu_title)"
        echo "=============================="
        echo "1. $(t menu_enable)"
        echo "2. $(t menu_disable)"
        echo "3. $(t menu_status)"
        echo "4. $(t menu_diagnose)"
        echo "5. $(t menu_ss)"
        echo "6. $(t menu_uninstall)"
        echo "7. $(t menu_language)"
        echo "8. $(t menu_help)"
        echo "0. $(t menu_exit)"
        read -r -p "$(t menu_prompt)" choice

        case "${choice}" in
            1)
                enable_bbr || true
                pause_return
                ;;
            2)
                disable_bbr || true
                pause_return
                ;;
            3)
                show_status
                pause_return
                ;;
            4)
                diagnose
                pause_return
                ;;
            5)
                show_ss_tin
                pause_return
                ;;
            6)
                uninstall_bbr
                pause_return
                ;;
            7)
                set_language_menu
                pause_return
                ;;
            8)
                show_help
                pause_return
                ;;
            0)
                exit 0
                ;;
            *)
                log_error "$(t invalid_option)"
                pause_return
                ;;
        esac
    done
}

main() {
    require_linux
    require_sysctl

    case "${1:-menu}" in
        enable)
            require_root
            enable_bbr
            ;;
        disable)
            require_root
            disable_bbr
            ;;
        uninstall)
            require_root
            uninstall_bbr
            ;;
        apply-qdisc)
            require_root
            apply_qdisc
            ;;
        status)
            show_status
            ;;
        diagnose)
            diagnose
            ;;
        ss)
            show_ss_tin
            ;;
        menu)
            require_root
            show_menu
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            log_error "$(tf unknown_command "${1}")"
            show_help
            exit 1
            ;;
    esac
}

main "${@}"
