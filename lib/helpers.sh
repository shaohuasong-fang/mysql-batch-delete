#!/bin/bash
# 命令帮助函数

[[ -n "${_HELPERS_SH_LOADED:-}" ]] && return 0
_HELPERS_SH_LOADED=1

# 显示详细帮助信息函数
show_help() {
    local script_name="${SCRIPT_NAME:-${0##*/}}"
    cat <<EOF
用法: ${script_name} [选项]

选项:
  --run                 实际执行删除（默认 DryRun 模式，仅打印 SQL）
  --config=PATH         指定配置文件路径
  --password=PASS       指定数据库密码（优先级最高）
  --help                显示此帮助信息

支持的条件类型:
  id   - 按 ID 区间批量删除（默认）
  time - 按时间区间批量删除

配置文件查找顺序（优先级从高到低）:
  1. --config=PATH 命令行指定
  2. 脚本所在目录下的 config
  3. 脚本父目录下的 config
  4. 脚本所在目录 config/ 子目录下的 config
  5. /etc/delete_tool/config
  6. ~/.delete_tool/config

密码优先级:
  1. --password=PASS 命令行参数（最高）
  2. 环境变量 DBPASSWORD
  3. 配置文件 [database] 段中的 password 字段（最低，不推荐）

示例:
  # DryRun 模式，查看将执行的 SQL
  bash ${script_name}

  # DryRun + 指定配置
  bash ${script_name} --config=/path/to/config

  # 实际执行删除
  bash ${script_name} --run

  # 实际执行 + 指定密码
  bash ${script_name} --run --password=Bigdata_123

安全提示:
  - 默认运行在 DryRun 模式，必须显式加 --run 才会真删
  - 支持 Ctrl+C 中断，自动保存进度
  - 密码不建议写在配置文件中，推荐使用环境变量 DBPASSWORD
EOF
}

# 简化帮助写法
show_usage() {
    local script_name="${SCRIPT_NAME:-${0##*/}}"
    echo "用法: ${script_name} [--run] [--config=PATH] [--password=PASS] [--help]"
    echo "详细帮助: ${script_name} --help"
}

# 脚本路径解析
resolve_script_path() {
    if [[ -L "${BASH_SOURCE[0]}" ]]; then
        SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
    else
        SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)/$(basename "${BASH_SOURCE[0]}")"
    fi
    CURRENT_DIR="$(dirname "$SCRIPT_PATH")"
    PARENT_DIR="$(dirname "$CURRENT_DIR")"
}
