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


## 聊天挂件与切字（+449）

- [word_slice_bridge.dart](../../lib/features/chat/word_slice_bridge.dart)：聊天框顶部/气焰值中心/输入区边界的实际布局坐标，读取可见RenderParagraph作为动画副本；不写入聊天数据，不调用AI。
- [WordSliceHost.kt](../../android/app/src/main/kotlin/com/aicompanion/localfirst/WordSliceHost.kt)：本地透明WebView；空闲只拥有挂件手势，游戏时拦截底层操作。沿用MainActivity窗口观察保持两套Live2D注视，不派发摸头事件。
- 源码：`app/tools/word_slice/template.html`与`assets.json`为已实测v6原型；`app/tools/build_word_slice.py`生成Android bundle。改游戏后重跑构建器及两套Node回归，不直接修改生成HTML。
- 挂点=聊天面板上边缘，横向=气焰值中心；下拉66逻辑像素切换。正式版无下拉常驻文字、音效开关、试听按钮。奖励3秒，50条五字横排，音量保留v6。
- 后台/路由离开/键盘展开结束当前局并清理声音、显示真实聊天；不会自动恢复一局。渲染器退出/捕获超时/心跳丢失释放交互，避免透明层锁屏。未接陀螺仪、悬浮窗、Agent工具、存档新字段。
- 验证：`node app/tools/test_word_slice_host.cjs`、`app/test/word_slice_bridge_test.dart`；真机重点：面板调高调低、Live2D跟随、游戏结束/再次下拉/系统返回、打开侧栏/设置、前后台及输入法。
