#!/bin/bash
# ==================== config_parser.sh ====================
# 配置文件查找 & INI 解析模块
# 需要全局变量: CURRENT_DIR, PARENT_DIR
# 导出: CONFIG_FILE, 以及 get_config() 函数

[[ -n "${_CONFIG_PARSER_SH_LOADED:-}" ]] && return 0
_CONFIG_PARSER_SH_LOADED=1

# ==================== 配置文件查找 ====================
# 调用方可在调用前设置 CONFIG_FILE 来跳过自动查找
find_config_file() {
    # 如果已经指定了 CONFIG_FILE（例如来自命令行 --config），则直接校验
    if [[ -n "${CONFIG_FILE:-}" ]]; then
        if [[ -f "$CONFIG_FILE" ]]; then
            return 0
        else
            echo "[ERROR] 指定的配置文件不存在: $CONFIG_FILE"
            exit 1
        fi
    fi

    local candidates=(
        "${CURRENT_DIR}/config"
        "${CURRENT_DIR}/../config"
        "${CURRENT_DIR}/config/config"
        "${CURRENT_DIR}/delete_config.ini"
        "${PARENT_DIR}/delete_config.ini"
        "/etc/delete_tool/config"
        "${HOME}/.delete_tool/config"
    )

    for candidate in "${candidates[@]}"; do
        if [[ -f "$candidate" ]]; then
            CONFIG_FILE="$candidate"
            return 0
        fi
    done

    # 未找到配置文件
    echo "[ERROR] 未找到配置文件！"
    echo ""
    echo "已按以下顺序查找："
    echo "  1. --config=PATH (命令行指定)"
    echo "  2. ${CURRENT_DIR}/config"
    echo "  3. ${CURRENT_DIR}/../config"
    echo "  4. ${CURRENT_DIR}/config/config"
    echo "  5. ${CURRENT_DIR}/delete_config.ini"
    echo "  6. ${PARENT_DIR}/delete_config.ini"
    echo "  7. /etc/delete_tool/config"
    echo "  8. ${HOME}/.delete_tool/config"
    echo ""
    echo "请任选其一："
    echo "  - 将 config 放置于脚本目录: ${CURRENT_DIR}"
    echo "  - 或指定配置文件路径: $0 --config=/path/to/config"
    exit 1
}

# 获取配置KV
# 通过读取配置文件中的 [section] 下的 key=value 来获取配置值
# 用法: get_config <key> <section> [default]
get_config() {
    local key="$1"
    local section="$2"
    local default="${3:-}"

    local value
    # 用 index() 做字面字符串匹配，避免 [ ] 被当作正则字符类
    value=$(awk -F '=' -v sec="[$section]" -v key="$key" '
        BEGIN {found=0; sec_str=sec}
        index($0, sec_str) == 1 {found=1; next}
        found && /^[[:space:]]*\[/ {exit}
        found && $1 ~ /^[[:space:]]*'"$key"'[[:space:]]*$/ {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
            sub(/[[:space:]]*;.*$/, "", $2)
            print $2
            exit
        }
    ' "$CONFIG_FILE")

    # 变量替换
    value="${value//\$\{CURRENT_DIR\}/$CURRENT_DIR}"
    value="${value//\$\{PARENT_DIR\}/$PARENT_DIR}"

    echo "${value:-$default}"
}

# 将 get_config 函数获取的配置文件中的所有配置项加载到 shell 变量中

load_config() {
    log_info "加载配置文件: $CONFIG_FILE"

    # 数据库配置模块解析
    DB_HOST=$(get_config "host"     "database")
    DB_PORT=$(get_config "port"     "database" "3306")
    DB_NAME=$(get_config "name"     "database")
    DB_USER=$(get_config "user"     "database")
    # 密码通过命令行参数或环境变量传入，配置文件中的 password 仅作参考
    DB_PASS="${DB_PASS_CLI:-${DBPASSWORD:-}}"

    # 待删除的目标对象模块解析
    TARGET_TABLE=$(get_config   "table"           "target")
    CONDITION_FIELD=$(get_config "condition_field" "target" "id")
    CONDITION_TYPE=$(get_config  "condition_type"  "target" "id")

    # 待删除的范围模块解析
    START_ID=$(get_config    "start_id"    "range" "1")
    END_ID=$(get_config      "end_id"      "range" "100")
    START_TIME=$(get_config  "start_time"  "range")
    END_TIME=$(get_config    "end_time"    "range")

    # 每批删除数量和系统休眠时间模块解析
    BATCH_SIZE=$(get_config  "size"          "batch" "100")
    SLEEP_SEC=$(get_config   "sleep_sec"     "batch" "0.1")
    local tmpl
    tmpl=$(get_config "progress_file" "batch")
    PROGRESS_FILE="${tmpl//\$\{table\}/$TARGET_TABLE}"
    PROGRESS_FILE="${PROGRESS_FILE//\$\{CURRENT_DIR\}/$CURRENT_DIR}"
    PROGRESS_FILE="${PROGRESS_FILE//\$\{PARENT_DIR\}/$PARENT_DIR}"
}
