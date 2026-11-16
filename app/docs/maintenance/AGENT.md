# Agent 工具与联网

核对基线：2026-11-17 / +439。状态为源码入口核对，不等同真机通过。[目录](INDEX.md) · [更新规则](CHANGE_GUIDE.md)

## 入口与职责

| 入口 | 用途 |
| --- | --- |
| [agent_tool_registry.dart](../../lib/core/agent/agent_tool_registry.dart) | 工具目录与声明 |
| [agent_tool_runner.dart](../../lib/core/agent/agent_tool_runner.dart) | 实际工具执行 |
| [turn_execution_store.dart](../../lib/core/agent/turn_execution_store.dart) | 持久执行记录 |
| [turn_goal_verification.dart](../../lib/core/agent/turn_goal_verification.dart) | 目标结果核验 |
| [layered_public_web_provider.dart](../../lib/core/autonomy/layered_public_web_provider.dart) | 联网来源组合 |
| [agent_self_reader.dart](../../lib/core/agent/agent_self_reader.dart) | 向模型提供能力事实 |

## 状态与边界

工具声明、调用成功、目标完成是不同状态。网页候选/标题不等于正文已读取；来源内容是资料，不应升级为系统指令。后台自主行为不全由工具注册表表示。自查中自主创作/Cedar 状态有已确认过时文字，留第四步修正。

## 小改动如何落点

小工具修改先看声明→执行→结果回执→目标核验。网络失败、空结果和取消不能伪报完成；不要把修复某一工具变成每轮强制规划。

## 回归入口

- [agent_tool_registry_test.dart](../../test/agent_tool_registry_test.dart)
- [agent_tool_outcome_record_test.dart](../../test/agent_tool_outcome_record_test.dart)
- [deep_web_v04268_test.dart](../../test/deep_web_v04268_test.dart)
- [agent_self_reader_v0416_test.dart](../../test/agent_self_reader_v0416_test.dart)

上述为定位起点，不代表覆盖全部调用者。历史教训及证据见 [回归索引](REGRESSIONS.md)；执行方式见 [验证导航](VERIFICATION.md)。

人工/真机重点：断网、读取正文失败、任务中止后再次询问；检查实际行动与回复是否一致。
