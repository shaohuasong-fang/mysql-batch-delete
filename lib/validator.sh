#!/bin/bash

# 配置参数校验模块

[[ -n "${_VALIDATOR_SH_LOADED:-}" ]] && return 0
_VALIDATOR_SH_LOADED=1

validate_config() {
    local errors=0

    # 数据库模块及待删除目标对象配置检查
    [[ -z "$DB_HOST" ]]      && { log_error "数据库主机(host)未配置";    ((errors++)); }
    [[ -z "$DB_NAME" ]]      && { log_error "数据库名(name)未配置";      ((errors++)); }
    [[ -z "$DB_USER" ]]      && { log_error "数据库用户(user)未配置";    ((errors++)); }
    [[ -z "$DB_PASS" ]]      && { log_error "数据库密码未设置（请通过 --password= 或环境变量 DBPASSWORD 提供）"; ((errors++)); }
    [[ -z "$TARGET_TABLE" ]] && { log_error "目标表(table)未配置";       ((errors++)); }

    # 端口校验，确保是数字
    if ! [[ "$DB_PORT" =~ ^[0-9]+$ ]]; then
        log_error "端口号(port)必须是数字"
        ((errors++))
    fi

    # 删除的条件类型校验，因为只能是id或time，该id仅表示待删除表的目标字段是一个整型类型，而不是表的主键id，time表示待删除表的目标字段是一个时间类型
    if [[ "$CONDITION_TYPE" != "id" && "$CONDITION_TYPE" != "time" ]]; then
        log_error "condition_type 只能是 'id' 或 'time'，当前值: $CONDITION_TYPE"
        ((errors++))
    fi

    # 与条件类型相关的配置校验
    # 删除类型为 ID 时，start_id 和 end_id 必须是数字，且 start_id <= end_id
    if [[ "$CONDITION_TYPE" == "id" ]]; then
        if ! [[ "$START_ID" =~ ^[0-9]+$ ]] || ! [[ "$END_ID" =~ ^[0-9]+$ ]]; then
            log_error "ID 模式下，start_id 和 end_id 必须是数字"
            ((errors++))
        fi
        if [[ "$START_ID" -gt "$END_ID" ]]; then
            log_error "start_id ($START_ID) 不能大于 end_id ($END_ID)"
            ((errors++))
        fi
    fi

    # 删除类型为 TIME 时，start_time 和 end_time 必须配置，且 start_time <= end_time
    if [[ "$CONDITION_TYPE" == "time" ]]; then
        if [[ -z "$START_TIME" || -z "$END_TIME" ]]; then
            log_error "TIME 模式下，start_time 和 end_time 必须配置"
            ((errors++))
        fi
    fi

    # 批次大小控制, 确保是正整数，CODITION_TYPE为ID时，表示一次删除多少行，
    # CODITION_TYPE为TIME时，表示一次删除间隔期间多长的数据，间隔时间的单位是秒，间隔周期计算已经在配置文件中的注释中提示，请按照实际情况调整即可

    if ! [[ "$BATCH_SIZE" =~ ^[0-9]+$ ]] || [[ "$BATCH_SIZE" -lt 1 ]]; then
        log_error "batch.size 必须是正整数，当前值: $BATCH_SIZE"
        ((errors++))
    fi

    # 待删除目标表存在性检查
    local table_exists
    table_exists=$("${MYSQL_CMD[@]}" -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}' AND table_name='${TARGET_TABLE}';" 2>/dev/null) || table_exists=0
    if [[ "$table_exists" != "1" ]]; then
        log_error "目标表 [${DB_NAME}.${TARGET_TABLE}] 不存在或不可访问"
        ((errors++))
    fi

    # 字段是否存在检查
    local col_exists
    col_exists=$("${MYSQL_CMD[@]}" -e "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='${DB_NAME}' AND table_name='${TARGET_TABLE}' AND column_name='${CONDITION_FIELD}';" 2>/dev/null) || col_exists=0
    if [[ "$col_exists" != "1" ]]; then
        log_error "目标表 [${DB_NAME}.${TARGET_TABLE}] 中不存在字段 [${CONDITION_FIELD}]"
        ((errors++))
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "配置验证失败，共 $errors 个错误"
        exit 1
    fi

    log_info "配置验证通过"
}
