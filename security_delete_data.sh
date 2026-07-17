#!/bin/bash
set -euo pipefail

#-----------------------------------------------------------------------
# 批量删除脚本
# 1. 支持按 ID 或时间区间删除
# 2. 支持 DryRun 模式（默认）和 Run 模式（实际删除）
# 3. 支持中断后恢复进度
#-----------------------------------------------------------------------

# 脚本路径定义
SCRIPT_NAME="${0##*/}"
if [[ -L "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
else
    SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)/$(basename "${BASH_SOURCE[0]}")"
fi
CURRENT_DIR="$(dirname "$SCRIPT_PATH")"
PARENT_DIR="$(dirname "$CURRENT_DIR")"
LIB_DIR="${CURRENT_DIR}/lib"

# 全局默认配置，不需要修改
RUN_MODE="dryrun"
TOTAL_DELETED=0
CURRENT_POS=""
CONFIG_FILE=""
DB_PASS_CLI=""

# 加载依赖模块
source "${LIB_DIR}/helpers.sh"
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/args_parser.sh"
source "${LIB_DIR}/config_parser.sh"
source "${LIB_DIR}/validator.sh"
source "${LIB_DIR}/mysql_connector.sh"
source "${LIB_DIR}/progress.sh"
source "${LIB_DIR}/deleter.sh"

# 中断信号处理，保存进度并退出
trap 'log_warn "接收到中断信号，保存进度并退出"; save_progress; exit 1' INT TERM

# 入口函数
main() {
    # 1. 解析命令行参数
    parse_args "$@"

    # 2. 查找配置文件
    find_config_file

    # 3. 设置日志（CONFIG_FILE 已确定）
    local log_dir
    log_dir=$(get_config "log_dir" "log")
    LOG_DIR="${log_dir:-/tmp}"
    LOG_FILE="${LOG_DIR}/delete_$(date +%Y%m%d).log"
    mkdir -p "$LOG_DIR"

    log_info "-----------------------------------------------------------------------"
    log_info "批量安全删除脚本启动"
    log_info "脚本目录: ${CURRENT_DIR}"
    log_info "配置文件: ${CONFIG_FILE}"
    log_info "日志文件: ${LOG_FILE}"
    log_info "运行模式: ${RUN_MODE}"
    log_info "-----------------------------------------------------------------------"

    # 4. 加载配置
    load_config

    # 5. 构建 MySQL 连接（校验阶段需要用它查表/字段存在性）
    build_mysql_cmd

    # 6. 先测试 MySQL 连接是否可用，再去校验配置
    test_mysql_connection

    # 7. 校验配置（含表/字段存在性检查，依赖 MYSQL_CMD）
    validate_config

    # 8. 初始化进度
    init_progress

    # 9. 打印执行概要
    log_info "运行模式:   ${RUN_MODE}"
    log_info "数据库:     ${DB_HOST}:${DB_PORT}/${DB_NAME}"
    log_info "目标表:     ${TARGET_TABLE}"
    log_info "条件字段:   ${CONDITION_FIELD}"
    log_info "条件类型:   ${CONDITION_TYPE}"
    log_info "批次大小:   ${BATCH_SIZE}"
    log_info "批次间隔:   ${SLEEP_SEC}s"
    log_info "进度文件:   ${PROGRESS_FILE}"
    log_info "当前进度:   ${CURRENT_POS}"

    # 9. 执行删除
    if [[ "$CONDITION_TYPE" == "id" ]]; then
        delete_by_id
    else
        delete_by_time
    fi

    # 10. 清理进度文件
    cleanup_progress
    log_info "任务结束。总删除行数: ${TOTAL_DELETED}"

    # 11. 提示执行 ANALYZE TABLE 和 OPTIMIZE TABLE
    post_delete_optimization
}

main "$@"
