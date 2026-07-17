#!/bin/bash
# 日志输出控制函数
[[ -n "${_LOGGER_SH_LOADED:-}" ]] && return 0
_LOGGER_SH_LOADED=1

# 日志级别颜色定义
COLOR_RESET="\033[0m"
COLOR_INFO="\033[32m"    # 绿色
COLOR_WARN="\033[33m"    # 黄色
COLOR_ERROR="\033[31m"   # 红色

# 格式化输出函数
_format_log() {
    local level="$1"
    local color="$2"
    local timestamp=$(date '+%F %T')
    
    # 使用printf格式化：级别固定5字符，时间戳固定19字符，自动换行
    # %-5s: 左对齐，宽度5字符
    # %-19s: 左对齐，宽度19字符
    # %b: 处理转义字符（用于颜色）
    printf "%b%-5s %-19s %s%b\n" \
        "$color" \
        "[$level]" \
        "$timestamp" \
        "$3" \
        "$COLOR_RESET" | tee -a "$LOG_FILE"
}

log_info() {
    _format_log "INFO" "$COLOR_INFO" "$1"
}

log_warn() {
    _format_log "WARN" "$COLOR_WARN" "$1"
}

log_error() {
    _format_log "ERROR" "$COLOR_ERROR" "$1"
}
