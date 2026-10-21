# Live2D语音嘴形、悬浮聊天与悬浮球边界检查

日期：2026-10-21（Asia/Shanghai）。状态：只检查分析，未修改功能、版本或构建APK。

检查源：`bb157cbf199561621eeb2b6c0fa6ea287b724438`，应用仍为已交付的v0.42.121+365，构建源`c3bec538`。对照上一版+364的`993a4471`。原工作区再次恢复为+363并有原有总账修改，本次在独立只读检查工作树核对+365，未以旧本地覆盖远端。

## 1. 嘴形：新增语音情绪层仍会改变嘴部形状

| 路径 | 实际控制 | 本轮结论与后续边界 |
|---|---|---|
| `CaicaiPcmLipSync.kt` → `SenLive2DModel.registerLipSyncUpdater` | 实际AudioTrack播放头索引PCM幅度，经`ParamMouthOpenY`驱动张合 | 保留；此次问题不能用禁用音频口型解决 |
| `CaicaiMotionPlanner.channels['mouth']` → 原`parameterPlan` | `ParamMouthForm`笑/不高兴，`MOUTHX`歪嘴，`SHRUG`撅嘴，`OUT`吐舌 | 这是开场四拍；用户明确要求完整保留 |
| 新语音`SpeechPerformancePlan.frames` → `speechParameterPlan` | 目前只有头、视线、眉等轻动作，没有嘴部目标 | 只删这里的嘴参数无法修正现状，因为这里本来没有 |
| 新语音`emotion` → `SenLive2DModel.applyCaicaiIdle` → `CaicaiFaceMotion.update` | `ParamMouthForm`、`MOUTHX`、`SHRUG`，同时也写眉眼/倾头 | 是新增语音过程中需要隔离的嘴形来源；其他表情/动作应保留 |

例如`shy`会写嘴形0.55、横向嘴形-0.65、撅嘴0.2；`flustered`还会给撅嘴0.7。虽然嘴巴“张开多少”仍来自PCM，张开的嘴会叠加这些形变。因此“没有写MouthOpenY”不等于“没有干预嘴形”。

上一版也不是完全没有表情：+364和+365的`CaicaiFaceMotion.java`、`CaicaiEmotionLease.java`逐字未变。旧情绪事件在4.5秒内淡出，内置TTS合成等待常使这层在播放前结束；+365通过语音心跳持续保持`speechWeight`并切换分段情绪，嘴部形变会在声音期间持续出现。这是有源码依据的差异，不将未观察的真机情况当作已复现。

还有既有嘴部路径：原装表情/手动预设中的`PUCKER`、吐舌`OUT`及短暂闭嘴保护，缩小形态的`ParamMouthForm`混合，摸头的嘴形，以及Sen原有表演/可选实验引擎。这些在上一版已存在，不应为了本轮问题全部关闭。

建议后续最小修改：给语音情绪应用路径增加嘴部通道屏蔽，只让其继续控制眉眼、视线和头部等；语音专用参数层也保持不接管嘴部。不要改全局模型参数接受表，不删除原四拍mouth选项，也不把嘴部最终统一归零。若四拍与语音短暂重叠，仍按独立层保留四拍的嘴形。保留真实PCM口型、手动交互优先级、静音/停止/旧回调栅栏。JEV仍沿用原批次和题数，无需追加调用。

## 2. 悬浮聊天：有确定的防护缺口，未取得本次崩溃根因

`OverlayBubbleService.kt`在+364到+365没有变化。它是原生WindowManager聊天面板，新增Live2D语音协调器不直接创建或销毁这个窗口。不能只因同一版出现问题，就认定新增Live2D表演造成了悬浮窗退出。

| 优先级 | 位置与确定事实 | 风险及建议 |
|---|---|---|
| 高 | `onDestroy`只取消部分任务；`scheduleBackgroundEngineRestart`的延迟回调用companion object中的全局`running`判断存活，缺少当前Service实例失效标记 | 旧实例销毁、等待中的重建回调尚未执行，新实例把全局running重新设true后，旧回调仍可能为已销毁实例创建FlutterEngine。应加实例生命周期/代次检查并取消自己的延迟任务；仅全局running不够 |
| 高 | `enterChatInputMode`的`chatInput?.post`回调重新读取可变全局`chatInput`，没有窗口代次、同一View或attached检查；`onImeBack`还会延迟80ms退出输入模式 | 快速关闭/重开时，旧回调可对空View或新窗口操作。应捕获原View和窗口身份，执行前验证存活/attached/输入状态。不能未经手机堆栈就断言所有Android版本都必抛空指针 |
| 高 | `removeChatWindow`忽略removeViewImmediate异常，随后直接清空全部窗口引用；`createChatWindow`仅看引用非空就认为可用；`ensureOverlayHealth`在chatExpanded时只记录健康状态即返回 | 无法确认旧窗口已真正移除，也不恢复已脱离的展开窗口；更新布局异常又多处被静默吞掉，可能表现为消失、失焦或再点打不开。可参照悬浮入口已有的`removeOwnedEntryWindow`保留所有权、确认detach并做有界恢复，同时记录失败阶段 |
| 中 | `GENERATION_POLL_MS=140`；`applyGenerationSnapshot`即使内容不变也删除/重建流式行、notifyDataSetChanged并滚到底部；`NativeChatAdapter.getView`忽略convertView | 生成期间约每秒7次整列表刷新、重建View/长文本布局。应保留状态轮询，只在可见内容/阶段变化时更新，避免无意义重绘；不要修改生成提交或取消语义 |
| 中 | `NativeChatAdapter.getView`在主线程每次重新decodeFile图片，无缓存 | 与高频重绘叠加会增加UI及内存压力。附件并非未经限制的原图：存储缩略图最长边1000，当前inSampleSize=2。仍适合做有界缓存/复用及必要的后台解码，但不能据此宣称这次已发生OOM |

刷新、加载旧记录等异步回调也未统一绑定窗口代次，存在旧结果覆盖新窗口显示的竞态；后续可与同一窗口身份修复合并处理，避免另建一套生成协议。

已核实的兼容措施包括按API选择悬浮窗类型、前台服务specialUse声明及相应版本分支、系统悬浮权限检查、API33接收器分支。没有发现一个足以直接认定“某Android版本一律无法运行”的简单权限/窗口类型遗漏。键盘布局主要依赖ADJUST_RESIZE和现有窗口flag，尚未做具体OEM/系统的真机对照，不能将布局风险当作已证实的闪退根因。

以上是代码缺口和风险，不是本次手机闪退堆栈。需区分进程crash/ANR/系统回收、Service停止、系统临时隐藏以及代码主动收起窗口。现有状态/事件可用来定位，宜记录窗口add/update/remove及实例/窗口代次；不额外持久化聊天正文。已有原生CI主要检查Live2D等构造/生命周期，并未覆盖这里完整的Service浮窗与输入法快速开合场景。

## 3. 圆形悬浮球：已有边界检测与自动吸边，旋转适配仍可补齐

普通圆球入口使用独立的`bubbleSafeArea`等方法：

- Android11/API30及以上：读取currentWindowMetrics及systemBars/displayCutout，留6dp安全边距，按62dp窗口尺寸限制坐标；头像本身50dp。
- 更早版本：按displayMetrics宽高限制，没有单独计算系统栏/刘海insets，复杂机型的安全区处理较弱。
- 拖动MOVE调用updateBubbleLayout，内部已夹紧坐标；UP按中心位置自动吸到左/右边，CANCEL也夹紧。不能误报为“拖动过程中完全不限制”。
- “缩进左侧”是明确功能，允许窗口部分移出屏幕，保留24dp窗口可见；不应当作普通越界Bug。
- 获取的是系统提供的矩形可用区域，不识别实体机壳或曲面屏形状；没有额外单列systemGestures安全区。

确定的不足：普通球只保存绝对像素X/Y；`onConfigurationChanged`仅夹紧，不保存/恢复原来的左/右贴边和纵向比例。例：density=3、窗口186px，1080px宽竖屏右边X为876；转到2400px宽横屏，夹紧仍为876，而新左右边X为18/2196，球会落在屏幕中间。此为按现有公式计算的例子，不是真机复现。

桌宠另有`PetOverlayWindow`，已保存贴边方向并在配置变化时按比例重映射；不要把桌宠的负坐标/overscan规则直接套到圆球。建议圆球借用相同的“贴边方向+纵向比例”思路，在旋转/折叠/分辨率变化时重新定位；旧系统insets做窄范围兼容增强即可。

## 4. 建议实施顺序与验证边界

后续若进入实现，优先：语音层嘴形隔离；窗口/Service实例失效栅栏及移除确认、错误记录；不变快照去重和图片缓存；普通球旋转贴边。无需重写对话链路、世界书、TTS推理或悬浮界面架构。

针对性验证应包括：同一份语音情绪计划下嘴部不被新语音层写入而四拍仍可写；长语音/静音恢复/晚到与手动交互；点输入立即关闭重开、旋转时输入法正在显示、后台服务销毁再启动、移除失败及展开窗口detach；长回复和多图；圆球左右贴边后旋转/折叠、缩入模式及旧系统安全区。

本轮只进行了源码阅读、+364差异核对和旋转边界算例。未修改应用、未运行新功能回归、未新增CI/APK、未调用真实付费模型，未取得用户手机崩溃堆栈。

Android官方依据：

- https://developer.android.com/reference/android/os/Handler （延迟任务的取消/失效处理）
- https://developer.android.com/reference/android/view/inputmethod/InputMethodManager （showSoftInput需对应当前输入View）
- https://developer.android.com/develop/ui/views/graphics （UI线程位图加载与缓存的性能风险）
- https://developer.android.com/reference/android/view/WindowInsets.Type （系统栏、刘海与系统手势insets的区别）
