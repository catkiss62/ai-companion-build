# 人格、双形态、情绪与感官

核对基线：2026-11-17 / +439。状态为源码入口核对，不等同真机通过。[目录](INDEX.md) · [更新规则](CHANGE_GUIDE.md)

## 入口与职责

| 入口 | 用途 |
| --- | --- |
| [playful_form_state.dart](../../lib/core/personality/playful_form_state.dart) | 调皮形态状态 |
| [form_context_snapshot.dart](../../lib/core/personality/form_context_snapshot.dart) | 本轮形态快照 |
| [emotion_episode_engine.dart](../../lib/core/emotion/emotion_episode_engine.dart) | 情绪事件 |
| [mood_service.dart](../../lib/core/mood/mood_service.dart) | 持续心情 |
| [somatic_engine.dart](../../lib/core/somatic/somatic_engine.dart) | 用户触碰与助手事件 |
| [moe_shadow_coordinator.dart](../../lib/core/integration/moe_shadow_coordinator.dart) | 萌属性协调 |

## 状态与边界

气焰/形态、即时情绪、持续心情与萌属性不是一个数值。somatic 已有双向触碰事件，参考感官设计的全部设想并未因此实现。口吻、立绘、TTS 和入库描述应取同一轮正确状态。

## 小改动如何落点

调阈值前跟踪本轮开始→判定→提交→播放→退出；停止不能留下已取消轮的变化。不要全局替换人设中的“我”，其可能指用户。

## 回归入口

- [playful_integrity_v04265_test.dart](../../test/playful_integrity_v04265_test.dart)
- [form_context_continuity_test.dart](../../test/form_context_continuity_test.dart)
- [somatic_policy_test.dart](../../test/somatic_policy_test.dart)
- [small_form_presentation_test.dart](../../test/small_form_presentation_test.dart)

上述为定位起点，不代表覆盖全部调用者。历史教训及证据见 [回归索引](REGRESSIONS.md)；执行方式见 [验证导航](VERIFICATION.md)。

人工/真机重点：变身/回落最后一轮、停止、重生成，以及两套 Live2D 与语音同步。
