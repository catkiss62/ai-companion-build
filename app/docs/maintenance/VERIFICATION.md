# 验证导航

维护卡列出的测试是选择起点，不是完整覆盖承诺。以下命令从仓库 `app/` 执行，Flutter/Java/NDK 版本和构建步骤以 [BUILDING](../BUILDING.md)及实际工作流为准。

## 按变更选择

| 变更 | 必要核对 |
| --- | --- |
| 仅维护文档 | 相对链接/源码路径、git diff、历史正文保留及冻结哈希；运行读取受影响文档的活动门禁 |
| UI 文案/布局 | 对应组件测试（已有时）、窄屏/输入法/返回；不为常量文字另造镜像测试 |
| 提示词/路由/预算 | 对应卡测试，输入装配、截断/终止、停止、重试与费用边界；真实模型另验 |
| 数据库/存档/跨进程 | 事务身份、恢复、目录交换、并发与故障注入；再按当前工作流完整回归 |
| 原生语音/Live2D/悬浮 | 原生检查及 Android 构建、真机生命周期与声音/画面；Flutter 测试不能替代 |

```sh
# 只验证活动门禁清单完整性，不会执行所有门禁
python3 tools/run_validation_suite.py --check-only
# 当前源码身份/入口/维护链接，以及历史归档检查
python3 tools/validate_current_ledger_handoff.py
# 例：上下文相关定向测试；按实际修改再增补
flutter test test/local_semantic_index_test.dart test/final_reply_failure_policy_test.dart test/json_completion_limits_test.dart
# 例：作品工作区与交付
flutter test test/creative_workspace_test.dart test/creative_delivery_test.dart
```

需要完整源码门禁时执行 `python3 tools/run_validation_suite.py`；不要 glob 执行全部 `validate_*.py`，许多旧脚本只适用于历史版本。构建流程还有 Flutter、原生、资源、签名与产物校验，以当前工作流为准。

## 证据怎么记录

写清基线提交、命令、退出状态、通过数量、环境缺口、失败原因以及未覆盖范围。只运行 `--check-only` 不得写“167 门通过”。本地缺素材/编译器应记录为未完成，不等同代码通过，也不等同代码故障。修正测试夹具或验证配置后保留先前失败证据。

CI 通过、生成 APK、签名核验和用户真机反馈分别记录。纯文档提交运行 Documentation and handoff validation，检查当前身份、历史归档及负例；AI_START_HERE.md、根 AGENTS.md 已纳入 APK 工作流的文档范围。源码/工具/工作流混合修改仍走完整路径，不能将校验脚本放入免检名单。

## 当前身份与历史证据

`validate_current_ledger_handoff.py` 对照 v4 顶部 CURRENT_SOURCE_IDENTITY 块、pubspec、实际 schemaVersion 和 AgentSelfReader.buildLabel；忽略历史注释，并检查当前入口和维护卡本地链接。升级版本/schema 时同步工作源码身份块；已交付 APK 仍单独记录，不要求在开发期间假称新包已交付。

`validate_historical_ledgers.py` 只检查旧 v2 索引证据及两份冻结归档的字节/SHA，不再检查当前版本或 schema。前者调用后者，既有167门清单仍经原入口执行两层检查。

负例与实际工作流 shell 测试：

```sh
python3 -m unittest discover -s tools -p test_documentation_handoff.py -v
```

本地相对链接检查不验证外链可达性、Markdown anchor 或真实模型能力；文档检查不能代替功能测试。
