# Cedar 游戏厅与定时陪玩

核对基线：2026-11-17 / +439。状态为源码入口核对，不等同真机通过。[目录](INDEX.md) · [更新规则](CHANGE_GUIDE.md)

## 入口与职责

| 入口 | 用途 |
| --- | --- |
| [cedar_toy_activity.dart](../../lib/core/mcp/cedar_toy_activity.dart) | 活动调度 |
| [cedar_game_protocol.dart](../../lib/core/mcp/cedar_game_protocol.dart) | 通用协议 |
| [cedar_toy_autonomy_engine.dart](../../lib/core/mcp/cedar_toy_autonomy_engine.dart) | 自主游戏 |
| [cedar_timed_play_task.dart](../../lib/core/mcp/cedar_timed_play_task.dart) | 定时任务 |

## 状态与边界

读取观察与有副作用的操作顺序不同。游戏服务返回任务后，需追 Agent 接收、执行、核验与恢复，不只改某个游戏提示词。显式停止、等待对手、定时等待和失败是不同状态；自主游戏已接入，帮助和自查已同步条件与分享边界。

## 小改动如何落点

按通用协议定位，不为单个棋局堆特判。保留恢复时“不确定已执行”的处理与回执去重；用户恢复的 3 次/30 分钟设计见历史证据，勿凭旧候选覆盖。

## 回归入口

- [cedar_end_to_end_state_machine_v04182_test.dart](../../test/cedar_end_to_end_state_machine_v04182_test.dart)
- [cedar_request_recovery_v042129_test.dart](../../test/cedar_request_recovery_v042129_test.dart)
- [cedar_control_commit_v042151_test.dart](../../test/cedar_control_commit_v042151_test.dart)
- [cedar_timed_recovery_v04261_test.dart](../../test/cedar_timed_recovery_v04261_test.dart)

上述为定位起点，不代表覆盖全部调用者。历史教训及证据见 [回归索引](REGRESSIONS.md)；执行方式见 [验证导航](VERIFICATION.md)。

人工/真机重点：用户先手、换游戏、等待恢复、停止后不重启与长时游玩。

## +445 游戏规则纠正

- [cedar_game_correction.dart](../../lib/core/mcp/cedar_game_correction.dart) 识别明确纠正，复用 `CedarGameSession.ruleCorrections` JSON；不新建数据库、不改分享记忆、不新增模型调用。每游戏最多6条，每条500字符，超长不截断后硬存。属于轻量规则识别，问句/假设/转述等保守跳过，不保证所有自然语言都能识别。
- 明确单一目录游戏优先，否则仅允许无目录歧义时绑定活动游戏；未知游戏/未有会话时不回退到其他游戏。重复文本更新来源，后来的明确更正按顺序核对旧说法；无自动语义合并。可用“撤回游戏规则纠正”或“撤回街机厅的规则纠正”清空对应游戏的纠正，短期玩法建议保留。
- `promptContext(includeRuleCorrections:true)` 仅用于用户游戏对话/游戏执行规划。默认关闭，分享、房间表达不新增该输入。来源为用户消息ID和时间，只记录用户纠正过；当前指南/最新工具状态核对优先，不把用户推断升级成平台事实或权限。
- 沿用现有最多8个游戏会话的保留策略，纠正随会话保存/导出/恢复，指南刷新不会抹除；不承诺被淘汰会话仍永久保留。继续使用 source fence 与三方合并，恢复存档后旧提交不得覆盖。
- 回归：[cedar_rule_corrections_v042201_test.dart](../../test/cedar_rule_corrections_v042201_test.dart)。CI及真机状态查唯一总账本批记录；真机观察纠正后继续游戏、切换与重启，不以分享正文作为此批记忆输入的验证。
