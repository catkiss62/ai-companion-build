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
