# Live2D、桌宠与悬浮窗口

核对基线：2026-11-17 / +439。状态为源码入口核对，不等同真机通过。[目录](INDEX.md) · [更新规则](CHANGE_GUIDE.md)

## 入口与职责

| 入口 | 用途 |
| --- | --- |
| [caicai_live2d_stage.dart](../../lib/widgets/caicai_live2d_stage.dart) | 菜菜舞台 |
| [chat_portrait_stage.dart](../../lib/widgets/chat_portrait_stage.dart) | 聊天立绘舞台 |
| [OverlayBubbleService.kt](../../android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt) | 悬浮窗口生命周期 |
| [OverlaySubmissionState.kt](../../android/app/src/main/kotlin/com/aicompanion/localfirst/OverlaySubmissionState.kt) | 悬浮提交状态 |
| [senlive2dcompanion](../../android/app/src/main/kotlin/com/catkiss/senlive2dcompanion) | 原生模型/动作接入 |

## 状态与边界

菜菜与 DeepSeek 两套模型参数、动作、中心点、保存及口型策略须隔离。悬浮窗口、桌宠、App 舞台生命周期不同；UI 可见不代表生成已提交。大素材和 Cubism 接入不为小修顺带重构。

## 小改动如何落点

位置问题先看预览/正式窗口坐标与缩放；动作问题检查参数所有者、持续时间与恢复。语音只移交嘴部时不能关闭其他表情。悬浮发送保留完整文字及提交回执。

## 回归入口

- [caicai_live2d_stage_test.dart](../../test/caicai_live2d_stage_test.dart)
- [portable_live2d_refresh_v04258_test.dart](../../test/portable_live2d_refresh_v04258_test.dart)
- [overlay_generation_snapshot_test.dart](../../test/overlay_generation_snapshot_test.dart)
- [live2d_settings_page_test.dart](../../test/live2d_settings_page_test.dart)

上述为定位起点，不代表覆盖全部调用者。历史教训及证据见 [回归索引](REGRESSIONS.md)；执行方式见 [验证导航](VERIFICATION.md)。

人工/真机重点：边缘拖动、输入法、回前台、导入导出后立绘、双形态与两模型语音口型。

## 悬浮只读请求恢复（+441）

历史加载、TTS/桌宠状态轮询、思考翻译使用有界只读桥调用：同步异常转换为失败，超时释放等待状态，每个请求只接收一个终态，迟到/重复结果不再更新界面。原有窗口epoch继续生效，后台通道更换不接受旧返回；历史分页还核对原列表起点，避免清空后旧页回灌。发送/停止等有副作用操作不使用这条超时路径。

回归：[OverlayServiceRecoveryTest.kt](../../android/app/src/test/kotlin/com/aicompanion/localfirst/OverlayServiceRecoveryTest.kt)。此修复证明异常与无回调可恢复，不能单凭源码归因某次真机闪退。日常使用仍观察服务退出/窗口关闭/进程崩溃的区别。
