# 界面、帮助、诊断与构建

核对基线：2026-11-17 / +440。状态为源码入口核对，不等同真机通过。[目录](INDEX.md) · [更新规则](CHANGE_GUIDE.md)

## 入口与职责

| 入口 | 用途 |
| --- | --- |
| [app.dart](../../lib/app.dart) | 应用根与导航 |
| [capability_help_page.dart](../../lib/features/settings/capability_help_page.dart) | 用户帮助 |
| [agent_self_reader.dart](../../lib/core/agent/agent_self_reader.dart) | 模型能力自查 |
| [model_usage_telemetry.dart](../../lib/core/diagnostics/model_usage_telemetry.dart) | 调用诊断 |
| [preflight_diagnostics_page.dart](../../lib/features/system/preflight_diagnostics_page.dart) | 预检界面 |
| [validation_suite.txt](../../tools/validation_suite.txt) | 活动源码门禁清单 |
| [workflows](../../../.github/workflows) | 实际 CI 工作流 |

## 状态与边界

帮助 UI、Agent 自查、工具注册表与后台能力需分别核对，不能由其中一个自动代表全部能力。第四步已同步通道/图片/作品/QQ/记忆/房间/语音/备份说明，修正自主创作、Cedar和表情包状态。implemented只表示程序实现，不代表当前设备已启用或调用成功。诊断页面与帮助均说明完整预检中的JEV上下文例外。版本/源码/CI/APK/真机是不同证据层级；本轮纯文档不产生新 APK。

## 小改动如何落点

UI 小修覆盖窄屏、输入法、长文案及返回栈。新增能力在同一任务更新维护卡和帮助；若暂缓，写明缺口。构建按照活动清单运行，不扫描执行所有历史校验脚本。

## 回归入口

- [capability_help_page_test.dart](../../test/capability_help_page_test.dart)
- [agent_self_reader_v0416_test.dart](../../test/agent_self_reader_v0416_test.dart)
- [unhandled_error_recorder_test.dart](../../test/unhandled_error_recorder_test.dart)

上述为定位起点，不代表覆盖全部调用者。历史教训及证据见 [回归索引](REGRESSIONS.md)；执行方式见 [验证导航](VERIFICATION.md)。

人工/真机重点：帮助文案与真实开关一致、诊断导出范围核对（包括经授权的 JEV 文本例外）、界面恢复及签名升级安装。
