# 聊天、模型路由与上下文

核对基线：2026-11-17 / +439。状态为源码入口核对，不等同真机通过。[目录](INDEX.md) · [更新规则](CHANGE_GUIDE.md)

## 入口与职责

| 入口 | 用途 |
| --- | --- |
| [chat_controller.dart](../../lib/features/chat/chat_controller.dart) | 普通聊天生成与提交入口 |
| [prompt_builder.dart](../../lib/core/ai/prompt_builder.dart) | 组装人设、世界书、记忆与当前状态 |
| [first_channel_model.dart](../../lib/core/ai/first_channel_model.dart) | 第一通道模型及力度读取 |
| [final_reply_route.dart](../../lib/core/ai/final_reply_route.dart) | 正文通道路由 |
| [final_reply_failure_policy.dart](../../lib/core/ai/final_reply_failure_policy.dart) | 终止原因与失败分类 |
| [reference_library.dart](../../lib/core/reference/reference_library.dart) | 按启用、作用域、模式和概率选取规则 |

## 状态与边界

内部系统调用与正文调用有不同职责和费用边界。改提示词前查装配位置与调用者；字符裁剪不是准确 token 计数，模型输出额度也不是上下文总容量。length 或缺终止标记不能当成功正文。普通、沉浸、QQ、模型对谈分别核对；对谈不采用普通聊天的跨模型兜底。

## 小改动如何落点

文案改对应提示词来源；预算改动同时检查输入选片、游标推进、输出终止判定及重试。不要通过扩大每轮规划次数解决单一工具漏触发。第一通道统一力度与部分旧直接读取路径仍需专项核对，不能直接视为已修复。

## 回归入口

- [model_routing_v042123_test.dart](../../test/model_routing_v042123_test.dart)
- [final_reply_failure_policy_test.dart](../../test/final_reply_failure_policy_test.dart)
- [json_completion_limits_test.dart](../../test/json_completion_limits_test.dart)
- [generation_cancellation_test.dart](../../test/generation_cancellation_test.dart)

上述为定位起点，不代表覆盖全部调用者。历史教训及证据见 [回归索引](REGRESSIONS.md)；执行方式见 [验证导航](VERIFICATION.md)。

人工/真机重点：多轮长资料尾部问题、停止/重生成、服务商截断与第三通道失败提示。
