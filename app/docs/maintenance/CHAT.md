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

普通聊天遇到换档或重生成，识图结果依赖当前租约与存档代次；配图任务和结果卡依赖本次回复修订；外语译文还须对应实际提交的正文、段落及目标语种。旧气泡撤下时保留相册已经收藏的原图。待确认草稿只在同一次等待确认期间接收翻译。回归入口见 [回复修订与写入归属](../../test/reply_revision_ownership_test.dart)。

## 小改动如何落点

文案改对应提示词来源；预算改动同时检查输入选片、游标推进、输出终止判定及重试。不要通过扩大每轮规划次数解决单一工具漏触发。第一通道统一力度与部分旧直接读取路径仍需专项核对，不能直接视为已修复。

## 回归入口

- [model_routing_v042123_test.dart](../../test/model_routing_v042123_test.dart)
- [final_reply_failure_policy_test.dart](../../test/final_reply_failure_policy_test.dart)
- [json_completion_limits_test.dart](../../test/json_completion_limits_test.dart)
- [generation_cancellation_test.dart](../../test/generation_cancellation_test.dart)

上述为定位起点，不代表覆盖全部调用者。历史教训及证据见 [回归索引](REGRESSIONS.md)；执行方式见 [验证导航](VERIFICATION.md)。

人工/真机重点：多轮长资料尾部问题、停止/重生成、服务商截断与第三通道失败提示。


## 聊天挂件与切字（+454）

- [word_slice_bridge.dart](../../lib/features/chat/word_slice_bridge.dart)：聊天框顶部/气焰值中心/输入区边界的实际布局坐标，仅在WordSliceText正文边界内读取可见RenderEditable/RenderParagraph，按字素复制实际坐标，排除时间/图标/工具详情；不写入聊天数据，不调用AI。
- [WordSliceHost.kt](../../android/app/src/main/kotlin/com/aicompanion/localfirst/WordSliceHost.kt)：本地透明WebView；空闲只拥有挂件手势，游戏时拦截底层操作。沿用MainActivity窗口观察保持两套Live2D注视，不派发摸头事件。
- 源码：`app/tools/word_slice/template.html`与`assets.json`为已实测v6原型；`app/tools/build_word_slice.py`生成Android bundle。改游戏后重跑构建器及两套Node回归，不直接修改生成HTML。
- 挂点=聊天面板上边缘，横向=气焰值中心；下拉66逻辑像素切换。正式版无下拉常驻文字、音效开关、试听按钮。奖励3秒，50条五字横排，游戏音效总线增益为 0.975（+452 的 1.5 倍）。
- 后台/路由离开/键盘展开静默结束当前局并停止音效，显示真实聊天；下拉主动退出才播放退出音。不会自动恢复一局。渲染器退出/捕获超时/心跳丢失释放交互，避免透明层锁屏。复用 RoomDepthMotionBridge 传感器，挂点随聊天框，挂件响应屏幕平面重力并可整圈旋转及摆出画面，命中区跟随挂件中心。隐藏时解绑，独立于背景立体开关。未接悬浮窗、Agent工具、存档新字段。
- 开场和游戏中的字采用细描边，左上角 HUD 无文字阴影。炸弹飞出时轻转，沿划动方向受击弹飞，首次落地即结算，哭泣继续播，结算卡保留分数和再来一次。受击红字保留上浮与淡出并平滑放大，连切、受击提示和爱字连切提示使用纯色，爱意连切状态行显示标题和倒计时。
- 开场为有界分帧字形贴图预热及约 0.2 秒原位放大，准备期间原聊天可见，飞行复用贴图；原刀声仅起划及明显转向时播放。返回聊天时等路由位移动画结束后再配置原生挂点。
- 验证：`node app/tools/word_slice/test.cjs`、`node app/tools/test_word_slice_host.cjs`、`app/test/word_slice_bridge_test.dart`；真机重点：面板调高调低、Live2D跟随、游戏结束/再次下拉/系统返回、打开侧栏/设置、前后台及输入法。
