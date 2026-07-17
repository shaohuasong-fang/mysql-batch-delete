# MySQL BatchDelete (批量删除脚本)

项目用于安全、可配置地在 MySQL 中批量删除数据，适用于需要按规则清理历史数据或敏感数据的运维场景。

**主要脚本与目录**
- `security_delete_data.sh`: 项目主入口，负责解析参数并调用删除逻辑。
- `config/`: 存放配置文件（数据库连接、删除条件等）。
- `lib/`: 脚本库，包含 `args_parser.sh`、`config_parser.sh`、`deleter.sh`、`helpers.sh`、`logger.sh`、`mysql_connector.sh`、`progress.sh`、`validator.sh` 等模块化脚本。
- `README.md`: 本文件，包含使用说明与安全注意事项。

**功能**
- 可配置的删除条件
- 日志与进度反馈，方便审计与排查。
- 模块化的设计，便于扩展与复用。

**先决条件**
- 已安装 MySQL 客户端（`mysql`），并能通过命令行连接目标数据库

**配置说明**
1. 编辑 `config` 配置文件，填写目标数据库连接信息、要删除的表/条件等。


**运行示例**
在做好配置并做好备份后，默认）：

```bash
# 查看帮助/用法
./security_delete_data.sh --help

# 默认执行 `dryrun`模式，即不实际删除
./security_delete_data.sh --password=xxxxxx

# 执行删除
./security_delete_data.sh --password=xxxxxx --run
```


**安全与注意事项**
- 建议在执行删除前做好数据库备份。
- 先在测试或预发布环境验证删除规则，确认无误后再在生产执行。
- 可用`dryrun`模式验证输出的`DELETE`范围是否符合删除条件


