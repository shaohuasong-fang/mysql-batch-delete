#!/bin/bash

# MySQL 连接模块
_MYSQL_CONNECTOR_SH_LOADED=1

# MySQL 客户端命令构建函数
build_mysql_cmd() {
    # 通过环境变量 MYSQL_PWD 传密码，避免命令行密码泄露和 stderr 警告
    export MYSQL_PWD="${DB_PASS}"
    MYSQL_CMD=(
        mysql
        -h"${DB_HOST}"
        -P"${DB_PORT}"
        -u"${DB_USER}"
        --default-character-set=utf8mb4
        --connect-timeout=10
        --batch --raw -s -N
        "${DB_NAME}"
    )
}

# 测试 MySQL 连接是否成功
# 返回 0 表示连接成功，非 0 表示失败
test_mysql_connection() {
    local result
    result=$("${MYSQL_CMD[@]}" -e "SELECT 1;" 2>&1) || {
        log_error "无法连接到 MySQL: ${DB_HOST}:${DB_PORT}/${DB_NAME}"
        log_error "错误详情: $result"
        return 1
    }

    log_info "数据库连接成功: ${DB_HOST}:${DB_PORT}/${DB_NAME}"
    return 0
}
