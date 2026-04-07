#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="/etc/sysctl.d/99-bbr-standalone.conf"
SYSCTL_CONF="/etc/sysctl.conf"

green="\033[0;32m"
yellow="\033[0;33m"
red="\033[0;31m"
plain="\033[0m"

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
        log_error "此脚本仅支持 Linux 系统。"
        exit 1
    fi
}

# 中文说明：确保使用 root 权限执行，因为需要修改内核网络参数。
require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        log_error "请使用 root 用户或 sudo 执行此脚本。"
        exit 1
    fi
}

# 中文说明：确保系统安装了 sysctl 命令。
require_sysctl() {
    if ! command -v sysctl >/dev/null 2>&1; then
        log_error "未找到 sysctl 命令，无法继续。"
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
    local current_qdisc current_congestion primary_iface iface_qdisc
    current_congestion="$(get_current_congestion)"
    current_qdisc="$(get_current_qdisc)"

    if [[ "${current_congestion}" != "bbr" ]]; then
        return 1
    fi
    primary_iface="$(get_primary_interface 2>/dev/null || true)"
    if [[ -n "${primary_iface}" ]] && require_command tc; then
        iface_qdisc="$(get_interface_root_qdisc "${primary_iface}" 2>/dev/null || true)"
        if [[ -n "${iface_qdisc}" ]] && [[ "${iface_qdisc}" =~ ^(fq|cake|fq_codel)$ ]]; then
            return 0
        fi
        return 1
    fi
    if [[ "${current_qdisc}" =~ ^(fq|cake|fq_codel)$ ]]; then
        return 0
    fi
    return 0
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

    echo "当前队列调度算法: ${current_qdisc}"
    echo "当前拥塞控制算法: ${current_congestion}"

    if sysctl net.ipv4.tcp_available_congestion_control >/dev/null 2>&1; then
        echo "系统支持的拥塞控制算法:"
        sysctl -n net.ipv4.tcp_available_congestion_control
    fi

    if is_bbr_enabled; then
        log_info "BBR 当前已启用。"
    else
        log_warn "BBR 当前未启用。"
    fi

    if require_command ip; then
        local primary_iface iface_qdisc
        primary_iface="$(get_primary_interface 2>/dev/null || true)"
        if [[ -n "${primary_iface}" ]]; then
            echo "默认路由网卡: ${primary_iface}"
            if require_command tc; then
                iface_qdisc="$(get_interface_root_qdisc "${primary_iface}" 2>/dev/null || true)"
                [[ -n "${iface_qdisc}" ]] && echo "网卡根队列调度: ${iface_qdisc}"
            fi
        fi
    fi
}

# 中文说明：启用 BBR，并记录启用前的原始设置，方便后续恢复。
enable_bbr() {
    local current_qdisc current_congestion primary_iface iface_qdisc

    if is_bbr_enabled; then
        log_info "BBR 已经处于启用状态。"
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
        log_error "当前系统未检测到 bbr 支持，请确认内核版本 ≥ 4.9 且已启用 tcp_bbr。"
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
        log_error "系统参数重载失败，请手动检查 sysctl 配置。"
        return 1
    fi

    sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1 || true
    sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1 || true

    if [[ -n "${primary_iface}" ]] && require_command tc; then
        if [[ "${iface_qdisc}" =~ ^(mq|noqueue)$ ]]; then
            log_warn "检测到网卡 ${primary_iface} 根队列为 ${iface_qdisc}，脚本不会强制替换。请手动确认队列调度是否适配 BBR。"
        else
            if ! tc qdisc replace dev "${primary_iface}" root fq >/dev/null 2>&1; then
                log_warn "未能为网卡 ${primary_iface} 设置 root fq，BBR 可能无法获得最佳效果。"
            fi
        fi
    fi

    if [[ "$(get_current_congestion)" == "bbr" ]]; then
        log_info "BBR 已成功启用。"
        return 0
    fi

    log_error "BBR 启用失败，请检查内核是否支持 tcp_bbr。"
    return 1
}

# 中文说明：关闭 BBR，优先恢复脚本保存的原始值；如果没有备份，则回退到常见默认值。
disable_bbr() {
    local old_qdisc old_congestion old_iface old_iface_qdisc

    if ! is_bbr_enabled; then
        log_warn "BBR 当前未启用，无需关闭。"
        return 0
    fi

    if [[ -f "${CONFIG_FILE}" ]]; then
        old_qdisc="$(grep -E '^#backup default_qdisc=' "${CONFIG_FILE}" 2>/dev/null | head -n 1 | cut -d'=' -f2- || true)"
        old_congestion="$(grep -E '^#backup congestion=' "${CONFIG_FILE}" 2>/dev/null | head -n 1 | cut -d'=' -f2- || true)"
        old_iface="$(grep -E '^#backup iface=' "${CONFIG_FILE}" 2>/dev/null | head -n 1 | cut -d'=' -f2- || true)"
        old_iface_qdisc="$(grep -E '^#backup iface_qdisc=' "${CONFIG_FILE}" 2>/dev/null | head -n 1 | cut -d'=' -f2- || true)"

        rm -f "${CONFIG_FILE}"
        reload_sysctl || true

        [[ -n "${old_qdisc}" ]] && sysctl -w "net.core.default_qdisc=${old_qdisc}" >/dev/null 2>&1 || true
        [[ -n "${old_congestion}" ]] && sysctl -w "net.ipv4.tcp_congestion_control=${old_congestion}" >/dev/null 2>&1 || true

        if [[ -n "${old_iface}" && -n "${old_iface_qdisc}" ]] && require_command tc; then
            tc qdisc replace dev "${old_iface}" root "${old_iface_qdisc}" >/dev/null 2>&1 || true
        fi
    else
        reload_sysctl || true
    fi

    if [[ "$(get_current_congestion)" != "bbr" ]]; then
        log_info "BBR 已关闭，并恢复为非 BBR 拥塞控制。"
        return 0
    fi

    log_error "关闭 BBR 失败，请手动检查系统配置。"
    return 1
}

# 中文说明：显示脚本帮助信息。
show_help() {
    cat <<'EOF'
用法:
  sudo bash bbr.sh enable    启用 BBR
  sudo bash bbr.sh disable   关闭 BBR
  sudo bash bbr.sh status    查看状态
  sudo bash bbr.sh menu      打开交互菜单
  sudo bash bbr.sh help      查看帮助
EOF
}

# 中文说明：提供简单的交互菜单，便于直接执行。
show_menu() {
    echo "=============================="
    echo "       BBR 管理脚本"
    echo "=============================="
    echo "1. 启用 BBR"
    echo "2. 关闭 BBR"
    echo "3. 查看状态"
    echo "0. 退出"
    read -r -p "请选择操作: " choice

    case "${choice}" in
        1)
            enable_bbr
            ;;
        2)
            disable_bbr
            ;;
        3)
            show_status
            ;;
        0)
            exit 0
            ;;
        *)
            log_error "无效选项，请重新执行脚本。"
            exit 1
            ;;
    esac
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
        status)
            show_status
            ;;
        menu)
            require_root
            show_menu
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            log_error "未知命令: ${1}"
            show_help
            exit 1
            ;;
    esac
}

main "${@}"
