# 主动消息、欲望与感知

核对基线：2026-11-17 / +439。状态为源码入口核对，不等同真机通过。[目录](INDEX.md) · [更新规则](CHANGE_GUIDE.md)

## 入口与职责

| 入口 | 用途 |
| --- | --- |
| [desire_engine.dart](../../lib/core/desire/desire_engine.dart) | 欲望状态 |
| [desire_core_policy.dart](../../lib/core/desire/desire_core_policy.dart) | 驱动与策略 |
| [perception_engine.dart](../../lib/core/perception/perception_engine.dart) | 感知事件入口 |
| [phone_activity_evidence.dart](../../lib/core/presence/phone_activity_evidence.dart) | 手机活动证据 |
| [daily_continuity_engine.dart](../../lib/core/continuity/daily_continuity_engine.dart) | 日常连续性 |
| [grounding_engine.dart](../../lib/core/grounding/grounding_engine.dart) | 现实状态依据 |
| [proactive_engine.dart](../../lib/core/desire/proactive_engine.dart) | 主动候选及后台创作调度入口 |

## 状态与边界

驱动、Thought、Intent、Outcome 与实际发送须分开看。手机活动是证据，不能把长期闲置累计直接当作刚拿起手机的强刺激。普通主动额度、夜间约束、游戏分享各有规则。历史欲望备份不能替代当前策略。

白天近况核对近 4 小时最多 6 条合格用户原话，超过 1 小时的原话只作历史。[话题证据读取](../../lib/core/desire/proactive_topic_evidence.dart) 在三通道共同上下文组装前核对所选话题的真实更新时间。本地向量只提名候选，按对象、角色及关系验证。没证据时状态标为最后已知。游戏、公开网页、夜间和独立 QQ 分享沿用自己的资料。

## 小改动如何落点

调整频率先查资格、冷却、配额、去重及当前上下文，避免只改一个概率。新的感知字段需检查来源时间及是否意外触发新想法。

## 回归入口

- [desire_core_policy_v031_test.dart](../../test/desire_core_policy_v031_test.dart)
- [perception_snapshot_test.dart](../../test/perception_snapshot_test.dart)
- [proactive_topic_evidence_test.dart](../../test/proactive_topic_evidence_test.dart)
- [proactive_final_reply_retry_test.dart](../../test/proactive_final_reply_retry_test.dart)

上述为定位起点，不代表覆盖全部调用者。历史教训及证据见 [回归索引](REGRESSIONS.md)；执行方式见 [验证导航](VERIFICATION.md)。

人工/真机重点：闲置后拿起手机、夜间与跨日、已下班场景，以及失败重试是否重复发送。

愿望评审按来源指纹去重。仅审查已有愿望的结果不能消耗同份材料在下次允许生成时的机会。曾允许提案且材料相同则跳过。活跃上限 4 个，不设共同愿望配额。
