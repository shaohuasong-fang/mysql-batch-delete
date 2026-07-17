#!/bin/bash
# 命令行解析模块定义
# 命令行参数解析模块
# 解析 --run, --config, --password, --help 等开关


[[ -n "${_ARGS_PARSER_SH_LOADED:-}" ]] && return 0
_ARGS_PARSER_SH_LOADED=1

parse_args() {
    # 重置来自命令行的变量
    CONFIG_FILE=""
    DB_PASS_CLI=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --run)
                RUN_MODE="run"
                shift
                ;;
            --config=*)
                CONFIG_FILE="${1#*=}"
                shift
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --password=*)
                DB_PASS_CLI="${1#*=}"
                shift
                ;;
            --password)
                DB_PASS_CLI="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "[WARN] 未知参数: $1（使用 --help 查看帮助）" >&2
                shift
                ;;
        esac
    done
}
