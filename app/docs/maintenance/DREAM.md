# 梦境、反思、愿望与关系

核对基线：2026-11-17 / +439。状态为源码入口核对，不等同真机通过。[目录](INDEX.md) · [更新规则](CHANGE_GUIDE.md)

## 入口与职责

| 入口 | 用途 |
| --- | --- |
| [dream_engine.dart](../../lib/core/self/dream_engine.dart) | 夜间整理 |
| [dream_contract.dart](../../lib/core/self/dream_contract.dart) | 材料与结果契约 |
| [dream_store.dart](../../lib/core/self/dream_store.dart) | 持久状态 |
| [deep_reflection_engine.dart](../../lib/core/reflection/deep_reflection_engine.dart) | 深度反思 |
| [wish_store.dart](../../lib/core/wishes/wish_store.dart) | 愿望记录 |
| [relationship_assimilator.dart](../../lib/core/relationship/relationship_assimilator.dart) | 关系资料吸收 |

## 状态与边界

这些机制依赖真实来源和可修订证据。梦境名称不授权凭空制造经历；学习偏置应有边界。后台恢复需区分已处理材料与未完成批次；愿望/反思提出意图不等于副作用已执行。

## 小改动如何落点

小改提示词需同时检查材料选择、用户与 AI 归属、反证、写回契约。不要以增加周期任务的方式强行提升产量。

## 回归入口

- [nightly_dream_test.dart](../../test/nightly_dream_test.dart)
- [nightly_dream_pipeline_test.dart](../../test/nightly_dream_pipeline_test.dart)
- [dream_source_continuity_test.dart](../../test/dream_source_continuity_test.dart)

上述为定位起点，不代表覆盖全部调用者。历史教训及证据见 [回归索引](REGRESSIONS.md)；执行方式见 [验证导航](VERIFICATION.md)。

人工/真机重点：跨夜未运行后补处理、退出恢复、事实被用户纠正后的更新。
