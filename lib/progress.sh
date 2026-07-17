#!/bin/bash
# 进度初始化，保存和清理函数

[[ -n "${_PROGRESS_SH_LOADED:-}" ]] && return 0
_PROGRESS_SH_LOADED=1

# 初始化进度函数
init_progress() {
    mkdir -p "$(dirname "$PROGRESS_FILE")"

    if [[ -f "$PROGRESS_FILE" && -s "$PROGRESS_FILE" ]]; then
        CURRENT_POS=$(cat "$PROGRESS_FILE")
        log_info "检测到进度文件，从位置 [${CURRENT_POS}] 继续删除"
    else
        if [[ "$CONDITION_TYPE" == "time" ]]; then
            CURRENT_POS="$START_TIME"
        else
            CURRENT_POS="$START_ID"
        fi
        log_info "未检测到进度文件，从初始位置 [${CURRENT_POS}] 开始"
    fi
}

# 保存进度函数
save_progress() {
    echo "${CURRENT_POS}" > "${PROGRESS_FILE}"
}

# 执行完成后清理进度文件
cleanup_progress() {
    if [[ "$RUN_MODE" == "run" && -f "$PROGRESS_FILE" ]]; then
        rm -f "$PROGRESS_FILE"
        log_info "进度文件已清理"
    fi
}
