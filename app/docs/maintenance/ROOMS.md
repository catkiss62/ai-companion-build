# 沉浸房间与模型对谈

核对基线：2026-11-17 / +439。状态为源码入口核对，不等同真机通过。[目录](INDEX.md) · [更新规则](CHANGE_GUIDE.md)

## 入口与职责

| 入口 | 用途 |
| --- | --- |
| [immersive_room_page.dart](../../lib/features/immersive/immersive_room_page.dart) | 沉浸 UI 与会话 |
| [immersive_room_repository.dart](../../lib/core/immersive/immersive_room_repository.dart) | 房间记录 |
| [immersive_archive_worker.dart](../../lib/core/immersive/immersive_archive_worker.dart) | 归档处理 |
| [model_dialogue_repository.dart](../../lib/core/model_dialogue/model_dialogue_repository.dart) | 模型对谈记录 |
| [model_dialogue_time.dart](../../lib/core/model_dialogue/model_dialogue_time.dart) | 对谈时间 |

## 状态与边界

两类房间的记录、总结与结束归档不能混入普通聊天进度。沉浸摘要从最早未处理完整消息推进；结束归档按原文分批，不能信任旧摘要已覆盖全部。模型对谈重试固定对应模型，不跨服务商兜底。

## 小改动如何落点

改上下文或整理限制须核对实际发送消息与游标增量；单条超大消息、批次累计时间和失败重试仍需关注。布局改动检查输入法、窄屏和房间状态持久化。

## 回归入口

- [immersive_stop_commit_v042104_test.dart](../../test/immersive_stop_commit_v042104_test.dart)
- [model_dialogue_recovery_v042117_test.dart](../../test/model_dialogue_recovery_v042117_test.dart)
- [model_dialogue_memory_v042114_test.dart](../../test/model_dialogue_memory_v042114_test.dart)
- [room_history_v042115_test.dart](../../test/room_history_v042115_test.dart)

上述为定位起点，不代表覆盖全部调用者。历史教训及证据见 [回归索引](REGRESSIONS.md)；执行方式见 [验证导航](VERIFICATION.md)。

人工/真机重点：长房间结束、离开多日再结束、停止归档重试、固定模型失败。
