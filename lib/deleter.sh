#!/bin/bash
# 核心删除模块
# 批量删除核心实现
# 需要全局变量:
#   MYSQL_CMD[], TARGET_TABLE, CONDITION_FIELD, CONDITION_TYPE
#   BATCH_SIZE, SLEEP_SEC, END_ID, END_TIME, RUN_MODE
#   TOTAL_DELETED, CURRENT_POS
#
# 注意：日期计算使用 date -d，Linux 下 date -d 支持多种时间格式

[[ -n "${_DELETER_SH_LOADED:-}" ]] && return 0
_DELETER_SH_LOADED=1

# 运行删除核心逻辑，按条件类型分发到不同的删除函数
_run_delete() {
    local sql="$1"
    local context="$2"

    local output deleted

    # 分开 stdout 和 stderr —— stderr 用于捕获真正的 SQL 错误
    output=$("${MYSQL_CMD[@]}" -e "${sql} SELECT ROW_COUNT();" 2>/tmp/mysql_stderr.$$) || true
    deleted=$(echo "$output" | tail -1)

    if [[ -z "$deleted" ]]; then
        log_error "${context}: MySQL 执行异常（可能是字段/表不存在或连接中断）"
        if [[ -s /tmp/mysql_stderr.$$ ]]; then
            log_error "MySQL 错误: $(tr '\n' ' ' < /tmp/mysql_stderr.$$)"
        fi
        rm -f /tmp/mysql_stderr.$$
        exit 1
    fi

    rm -f /tmp/mysql_stderr.$$

    if [[ "$deleted" =~ ^[0-9]+$ ]]; then
        TOTAL_DELETED=$((TOTAL_DELETED + deleted))
        log_info "${context}: 本批 ${deleted} 行 | 累计 ${TOTAL_DELETED} 行"
    else
        log_error "${context}: 返回值异常 —— [${deleted}]"
        exit 1
    fi
}

# 按照ID的区间删除
delete_by_id() {
    while true; do
        NEXT_POS=$((CURRENT_POS + BATCH_SIZE))
        [[ "$NEXT_POS" -gt "$END_ID" ]] && NEXT_POS="$END_ID"

        if [[ "$CURRENT_POS" -ge "$END_ID" ]]; then
            log_info "ID 已达到终点 (${END_ID})，删除完成"
            break
        fi

        local SQL="DELETE FROM ${TARGET_TABLE} WHERE ${CONDITION_FIELD} >= ${CURRENT_POS} AND ${CONDITION_FIELD} < ${NEXT_POS};"

        if [[ "$RUN_MODE" == "run" ]]; then
            _run_delete "$SQL" "[${CURRENT_POS}, ${NEXT_POS})"
        else
            log_info "[DryRun] SQL: ${SQL}"
        fi

        CURRENT_POS="$NEXT_POS"
        save_progress
        sleep "$SLEEP_SEC"
    done
}

# 按照时间范围进行删除
delete_by_time() {
    while true; do
        local CUR_TS NEXT_TS END_TS NEXT_POS

        # Linux 下 date -d 支持多种时间格式
        CUR_TS=$(date -d "$CURRENT_POS" '+%s' 2>/dev/null) || true
        END_TS=$(date -d "$END_TIME"    '+%s' 2>/dev/null) || true
        NEXT_TS=$((CUR_TS + BATCH_SIZE))
        NEXT_POS=$(date -d "@${NEXT_TS}" '+%F %T' 2>/dev/null) || true

        # 如果任一时间戳转换失败则终止
        if [[ -z "$CUR_TS" || -z "$NEXT_TS" || -z "$END_TS" ]]; then
            log_error "日期转换异常：CUR=[$CURRENT_POS] NEXT=[$NEXT_POS] END=[$END_TIME]"
            log_error "CUR_TS=[$CUR_TS] NEXT_TS=[$NEXT_TS] END_TS=[$END_TS]"
            exit 1
        fi

        # 下界越界，用终点收尾
        if [[ "$NEXT_TS" -gt "$END_TS" ]]; then
            NEXT_POS="$END_TIME"
            NEXT_TS="$END_TS"
        fi

        # 结束判定
        if [[ "$CUR_TS" -ge "$END_TS" ]]; then
            log_info "时间已达到终点 (${END_TIME})，删除完成"
            break
        fi

        local SQL="DELETE FROM ${TARGET_TABLE} WHERE ${CONDITION_FIELD} >= '${CURRENT_POS}' AND ${CONDITION_FIELD} < '${NEXT_POS}';"

        if [[ "$RUN_MODE" == "run" ]]; then
            _run_delete "$SQL" "['${CURRENT_POS}', '${NEXT_POS}')"
        else
            log_info "[DryRun] SQL: ${SQL}"
        fi

        CURRENT_POS="$NEXT_POS"
        save_progress
        sleep "$SLEEP_SEC"

    done
}

# 删除完成后提示执行 ANALYZE TABLE 和 OPTIMIZE TABLE
post_delete_optimization() {
    log_info "-----------------------------------------------------------------------"
    log_info "删除完成，执行以下 SQL 以优化表性能和释放空间"
    log_info "ANALYZE TABLE ${DB_NAME}.${TARGET_TABLE};"
    log_info "OPTIMIZE TABLE ${DB_NAME}.${TARGET_TABLE};"
    log_info "-----------------------------------------------------------------------"

}