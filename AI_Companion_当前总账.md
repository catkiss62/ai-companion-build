# AI Companion · 当前总账

更新时间：2026-10-01（+301 IMPLEMENTATION IN PROGRESS / CI PENDING / APK PENDING / TRUE DEVICE PENDING；+300 CI PASSED / APK READY / TRUE DEVICE PENDING；+299 CI PASSED / APK READY / TRUE DEVICE PENDING；+298 CI PASSED / APK READY / TRUE DEVICE PENDING；+297 CI PASSED / APK READY / TRUE DEVICE PENDING；+295 恢复真机成功、背景回归 PARTIAL；+293 DEVICE VISUAL BASELINE）

> 本文件是唯一的当前接班入口，继续采用“总账 v2”。顶部是快速接班索引；标记后的正式记录按版本持续追加，不设总容量上限。
>
> 判断优先级：用户最新明确决定 > 当前 GitHub 源码与 Actions > 同时刻脱敏真机诊断/备份 > 本文件 > 冻结归档与 Git 历史。`DESIGNED`、`IMPLEMENTED`、`CI PASSED`、`APK READY`、`TRUE DEVICE PASSED`、`PENDING` 必须严格区分。


## 当前任务 · v0.42.57+301 只读记忆星谷、星空入口与四角吸附（IMPLEMENTATION IN PROGRESS / CI PENDING / APK PENDING / TRUE DEVICE PENDING）

用户2026-10-01 05:15批准实施上一轮方案并追加“她”页按钮替换；基线+300功能620e0885、总账18edbf64（本地d696987e同tree dcc5c3d6）；分支agent/v04257-memory-galaxy-corner-dock，版本0.42.57+301，schema61/存档protocol7保持。授权推送构建延续。

- 记忆星谷：沿用用户HTML模板的星海、粒子、Bloom、流星与文案，独立原生WebView Activity，离线资源随APK打包；读取全部active主记忆，未随机抽样、无300条上限，归档/旧版本不显示，记住事项不加入。空库和错误不回退虚构示例。
- 只读路径：专用分页快照，不走AI relevantMemories；浏览/搜索/点击/临时“心动”均不写数据库，不增加召回或表达次数，不改重要度/钉选/冷却，不调用模型。模板连线仍按记忆类别作视觉提示，不声称是新知识图谱；列表详情另加精确已存topicKey的同话题条目，折叠查看、只读切换，不新增关系表。
- 入口：记忆库页+“她”页；原“去找她”位置替换为“记忆星谷”，紫靛渐变、缓慢星点、偶发流星；离开首页、后台、减少动画时停止。原其它聊天入口保留。
- 桌宠：同时进入水平/垂直吸附范围的四角优先上/下，保持原阈值；普通边缘、抛掷、重力、半屏、沿边行走不改。Jev Live2D不增加兜底；旧桌宠图片清理暂缓，七大规则删除放弃。
- 回归保留+299白天背景及大settings无损读取、+300游戏分享/自制旋转/2.8秒摸头彩蛋/记住事项/完整存档。新增数据库只读、投影、动画生命周期、原生路径和四角测试，APK离线资源逐个哈希核对；当前尚待CI与真机，不提前宣称通过。

## 当前交付 · v0.42.56+300 游戏分享间隔、旋转、持续摸头与存档完整性（CI PASSED / APK READY / TRUE DEVICE PENDING）

用户2026-09-30 23:22批准以下修改；基线+299功能a2341425、总账526e1bb4，本地同tree df232243；独立分支agent/v04256-game-share-portable-state。授权推送/构建延续，不再重复确认。

- [x] 游戏厅三按钮改成“10轮回复 / 5轮回复 / 1轮回复”，等宽、默认5轮，选择持久化且后台同样生效。普通单人自主推进固定至少2分钟；已承诺的多人事件监听/轮到用户/服务器定时协议不靠UI按钮加速，也不把轮询算推进。
- [x] 5/10/1为两次过程分享之间的最少成功游戏推进轮数；指定时长任务、自主半小时竞争和普通自主推进共用门。无值得分享的进展不发，到轮数不强制播报。默认5轮约10分钟而非严格定时器；失败、查询、等待不计。
- [x] 一次正文可概括多轮尚未分享的已保存结果；消除旧最近6条导致10轮信息不足，保留事件身份、排队合并、用户聊天/沉浸/Brain/写入围栏。分享判断仍合并现有DeepSeek下一步规划，Gemini一次最终正文；不增加逐步判断调用。任务终止结果回报仍独立必达，不再等待攒满轮数。
- [x] 只调整自制@rootTilt、小腿支点整体左右旋转：Jev目标速度接近自主待机、略快；检查接管、反向、退出和回到待机，保留身体XYZ及头/表情/平移原效果。
- [x] 2026-10-01 00:31追加、02:04最终修订：Live2D自制摸头在有效手势按住期间持续表情，UP/CANCEL才恢复；头部自身移动导致触点暂离区域不应提前松开。彩蛋采用原总时长2.8秒（2.2秒开始淡出、0.6秒淡出），期间新普通摸头或重复彩蛋不能抢占/重置计时；保留原10%概率与平滑恢复。参考Sen按住/松开机制，勿改模型自带表情；不改其它4.5秒临时表情。
- [x] 左栏代办提醒上方增加记住事项入口，复用原页面和同一数据源，不改重要性/提醒逻辑。
- [x] 完整存档审计并补齐可迁移的Live2D当前模型/配件及舞台偏好、SecureConfig非密钥配置、表情包及桌宠显示/位置偏好；API Key/Token/密码仍排除，设备身份/进程lease/旧游玩授权不复制。普通备份与接管包均核验，旧包兼容；新机导入无模型、哈希损坏、部分失败保持事务回滚，实际模型不提交公开仓。
- [x] 专项行为、134项源码门、Kotlin/Android单元测试、Flutter analyze及1033项测试、Android15原生9/9、arm64签名APK均通过；真机仍待验收。保留+299大settings无损读取和已批准白天图。

最终CI：[36756872531](https://github.com/catkiss62/ai-companion-build/actions/runs/36756872531) conclusion=success；功能源码620e08852283d6a5389d307e161d02166443785d/tree85471e6f48418947e81b3ca225d0b801c4fdfe94，与本地fe10a850同tree。摸头彩蛋为原2.8秒，其余本轮任务完整保留。失败/替代的前三轮记录见正文，不作为最终交付。

[未发布+300测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-509ccfd78b2217c9fdc2)，Draft400290010/asset601559245，727767998bytes，SHA-256 c6049f59ccaec150d26d71bcdaf1ff5b28272a025aee1f8658832a7ec851fcbf；稳定签名与+299一致，可覆盖安装。Release target、CI head、ci-monitor-v0345/.ci/v04256-monitor.txt及GitHub计算的APK digest一致，代码和安装包都采用2.8秒。真机尚待游戏分享节奏、连续摸头、旋转观感与实际设备存档往返验收；不宣称TRUE DEVICE PASSED。

旧桌宠图片任务暂缓，且用户纠正大肥鱼/小小鲸是立绘而非旧桌宠；原六项方案中的素材路径仅是立绘路径，不能据此替换旧桌宠。七大规则删除任务明确放弃，其页面与共享导入导出均保留。


## +299 存档大值读取与白天背景（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 已完成加急两项，基线功能a2341425/tree dbd8558e、总账526e1bb4/tree df232243；[Actions36731605271](https://github.com/catkiss62/ai-companion-build/actions/runs/36731605271)全绿，133项门、Flutter1018项、原生6项通过。完整实施与回归证据在正文“+299完整接班记录”。
- [未发布+299测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-96970c13c85e77efbdd1)，Draft400107673/asset601202681，SHA-256 8f848e1ceeaf992a3f54fb2bd1a5721d2316a478515906cf8be4f19302c242d3；签名沿用稳定签名，可覆盖安装。真机仍待备份和白天图验收。
- +300保留settings无损分段读取及已批准day.webp（SHA-256 6b4296044fd5b882f459e3f66cb586f67d59949a3a49a786a343619149781fb7）；不重新生成图片，不清空/截断存档。

## +298 指定时长游戏与过程分享（已构建）

完整实施、CI与APK证据保留在正文“+298完整接班记录”；+300在此基线上统一轮数分享间隔。

## 当前试验 · +295 菜菜原生直接合成，绕开最近任务返回时的 Virtual Display 重置（CI PASSED / APK READY / TRUE DEVICE PARTIAL：恢复成功，背景回归）

- 用户同意继续下一步。+294 真机确认最近任务返回仍卡顿、消失、再出现；其诊断显示 Activity 恢复后 Surface 被拆装，EGL context 增加、7 张 PNG 重载。Flutter 3.44.9 普通 `AndroidView` 对 `GLSurfaceView` 落入 Virtual Display，每次 `onPostResume` 重置该 Surface。本试验在 `CaicaiLive2DStage` 用 `PlatformViewLink`、`AndroidViewSurface` 和 `initExpensiveAndroidView` 强制直接 Hybrid Composition；保留原生 `GLSurfaceView`、外层触摸归一化、舞台尺寸、IME 和 renderer。`setVisible(false)` 对原生 root 设 alpha=0 避免真实 Surface 把上一帧盖在其它标签页上，不额外拆除视图；返回时 alpha=1。原生新增 attach/detach 时的 view_id、context、display 和 detach 调用栈诊断，便于验证是否仍被重新挂载。
- 曾经 +278～+281 直接合成出现黑底、切标签残影和键盘拉长，+282 退回普通 AndroidView；此版并非照搬旧时的整体布局和生命周期，而是在 +294 当前舞台/原生宿主基础上单独替换承载方式。+284 TextureView 不显示也禁止复用。历史问题须逐项真机验证，CI 不能证明屏幕合成画面。
- 分支 `agent/v04251-caicai-direct-hybrid`，版本 `0.42.51+295`；+293 用户已认可画面作为视觉回退基线（远端 `b548cf37`、Draft `399274286`、APK SHA-256 `4c108da236e0c47e0b2d20647659c2157371be3cc18ebd5a8dd9c43bf246b094`），+294 仍有直接前一源码回退点（远端 `b631f2a`、Draft `399415602`）。不合并 main、不发布正式 Release。
- 功能提交本地 `d808fb17f0a7ba76266e70dfa38d775b10a9798b`、远端同源码树 `c08bfd7a908f1e594ac60ab75327d4ce20fa6bd5`，tree `728f774cd279d3f8558da5328afdfe93a8f8e6fb`。本地专项源码门通过；完整套件本地在第 29/130 项因未恢复的私有桌宠素材停止，Actions 恢复素材后全套通过。[Actions 36632620687](https://github.com/catkiss62/ai-companion-build/actions/runs/36632620687) `success`：原生模拟器烟测、源码门、Kotlin、Flutter analyze/test、arm64 Release 和资源/签名校验全绿；失败报告任务跳过。
- 未发布 Draft `399549119`：[+295 测试 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-31bb487d183a055036d9)，target=`c08bfd7`，asset `599287961`，文件 `AI-Companion-v0.42.51-295-Caicai-Direct-Hybrid-APK.apk`，726110402 字节，SHA-256 `41ce939487189b7f6078a8071b80dfa84baf6824be2ea5a3eddbc44232f9d5b6`；Artifact `11063573671`。仍是同一持久测试签名，覆盖安装可保留数据；未正式发布。
- 真机回报 2026-09-30 09:40：恢复卡顿已成功，背景黑色或显示前一标签页；状态改为 PARTIAL，具体证据与 +296 修复见顶部。旧验收清单仅为当时计划，不能继续把实际结果记为 PENDING。
- 真机验收：同一聊天画面连续三次“≡→直接返回”，观察人物是否仍卡住/消失及画面透明度；再切 App 后返回；切换其它标签页再回来，确认无残影、黑底或重新加载；开合键盘确认输入区尺寸和触摸；导出诊断核对 `view_detaching`、`surface_destroyed`、context 计数及 model frame。若任一视觉回归，标记本试验 `TRUE DEVICE FAILED` 并按 +293 覆盖安装回退。**构建成功仅写 `CI PASSED / APK READY`，手机未验不得写 `TRUE DEVICE PASSED`。**

## 当前试验 · +294 系统最近任务返回时的菜菜画面恢复（CI PASSED / APK READY / TRUE DEVICE FAILED）

- 用户确认 +293 人物效果已经达标，是本轮可覆盖安装及回退基线；仅剩切出切回时固定出现“卡约一秒、消失约一秒、恢复”。最小复现：在聊天的 Live2D 画面按手机“≡”进入最近任务，**不切换其他 App**，直接点回；几乎每次复现。不需要先索取视频才开始排查。第二套 Live2D 的通用切换待有模型后再做。
- 同版专用诊断 `live2d_diagnostics_2026-09-29T17-08-30.929748Z.json.txt` 有两次完整恢复：从 `host_resume` 至 `first_model_frame` 约 2.95/3.05 秒；其中 surfaceChanged/reload 约 2.72 秒、七张 PNG 解码约 2.20 秒、上传约 0.19 秒；均有 `surface_destroyed`→`surface_created`，view_id 保持 1，Cubism owner 等待 0。一次没有 stage_visibility 变化，故不能把每次现象归于切标签。原生首帧不等于屏幕实际合成帧。
- +293 源码的 `MainActivity.onPause` 总会调用 `CaicaiLive2DBridge.onPause`→`CaicaiRuntime.onHostPause`→`GLSurfaceView.onPause`；返回 `onResume` 即恢复。+294 将宿主 GL 暂停/恢复分别改为 `onStop`/`onStart`；`onPause`/`onResume` 仅记录诊断，继续保留悬浮窗恢复逻辑；`setVisible` 和 host 调用只在真实状态改变时对 GL 线程执行，避免重复恢复重置首帧计时。不改 Flutter AndroidView、已验证 GLSurfaceView、Cubism 渲染器、模型 ZIP、配件几何、输入法布局、桌宠或 Jev。
- 诊断增加 `activity_pause/stop/start/resume` 与当前 view/surface 状态。同一版需反复“≡→点回”三次，并按一次较长停留和一次真正切 App 对照：比对是否出现 `activity_stop`、`host_pause`、`surface_destroyed`，看 context 计数是否增长及实际肉眼空白是否消失。**CI 只验证代码/构建；真正视觉成功须用户手机回报。** 若没有 `activity_stop` 仍重建 Surface，应调查 Flutter/厂商 Surface 附着与合成；若有 `activity_stop`，该方案本就会暂停，下一试验再依据实测选保活/重载优化，不能称 +294 修复成功。
- 回退基线：+293 已验收的当前效果，Draft `399274286`，APK SHA-256 `4c108da236e0c47e0b2d20647659c2157371be3cc18ebd5a8dd9c43bf246b094`，远端源码 `b548cf37`；本试验独立分支 `agent/v04250-caicai-recents-pause`，版本 `0.42.50+294`。不合并 main、不正式发布。
- 实施与构建：本地功能提交 `1dbba1c`、工作流标签修正 `6c2b0d5`，远端分别为同源码树的 `372cc5a`、`b631f2a12369d3f032a51b5fe3bd19c53546e8df`；最终 tree `6f9c477175fd60784faf37320d62a0bab6eec22b` 与本地一致。初次运行 `36609065282` 因补正失败诊断的 Draft 标签而主动取消，不算源代码回归失败。最终 [Actions 36609270446](https://github.com/catkiss62/ai-companion-build/actions/runs/36609270446) success：原生 Live2D 模拟器烟测、130 项源码门、Kotlin、Flutter analyze/test、arm64 Release、稳定签名和资源核验通过。
- 未发布 Draft `399415602`：[+294 测试 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-7d3c66f7eb520f70d808)，target=`b631f2a`，asset `598907556`，文件 `AI-Companion-v0.42.50-294-Caicai-Recents-Pause-APK.apk`，726108946 字节，SHA-256 `0b42e4f342f56546ab6b02b9bcf6ea0216cea50ba9c9adba90f0e0034f6c83f4`。CI 签名摘要与 +293 相同，可覆盖安装保留数据；未合并 main、未发布正式 Release。后续真机确认恢复问题仍存在，分析见下节。

| 尝试 | 成功或失败证据 | 后续约束 |
|---|---|---|
| +281 缩短视图离页存活 | 用户真机：后台返回 Live2D 变黑，切页重新加载、键盘拉长；`TRUE DEVICE FAILED` | 不为此问题重启/重建 Flutter 舞台 |
| +284 自定义 TextureView 宿主 | 构造异常、模型未显示；+285 改回 GLSurfaceView | 不以 TextureView 或重写原生渲染宿主冒险 |
| +285 恢复 GLSurfaceView/导入事务 | 原生生命周期门与构建通过，后续模型已能显示；仍未解决最近任务的秒级空白 | 保持可见模型和导入路径基线 |
| +293 当前真机效果 | 用户确认人物效果非常好；最近任务返回稳定出现卡住→消失→恢复，诊断见上 | 本轮仅动生命周期并逐项记录 CI/真机结果 |
| +294 暂停时机试验 | 2026-09-30 05:07 用户及 +294 诊断确认仍卡住→消失→重现；`TRUE DEVICE FAILED` | 仅移动 onPause/onStop 无效，转查 Flutter Virtual Display 恢复拆装 |
| +295 直接 Hybrid 试验 | 2026-09-30 09:40 用户确认恢复成功，同版 context 始终 1；背景黑色/旧页面透出失败。Draft `399549119`；`TRUE DEVICE PARTIAL` | 保留直接 HC 与恢复成功，+296 单独修复 Surface 背景 |
| +296 原生背景合成 | Actions `36657791150` 全绿、原生 5/5（含两项 ES2 像素测试），Draft `399666814`；`CI PASSED / APK READY / TRUE DEVICE PENDING` | 不能牺牲 +295 恢复结果；检查昼夜、切页、聊天覆盖与键盘裁剪 |

### +294 真机失败分析 · Flutter 恢复路径（2026-09-30 05:07 后，调查完成／下一实现待定）

- 附件 `live2d_diagnostics_2026-09-29T21-05-56.330261Z.json.txt` 全部保留事件均为 `0.42.50+294`。可见两次返回：05:05:39.902→42.742 为 2840 ms；05:05:49.514→52.264 为 2750 ms。后一次完整记录 `activity_pause` 48.630、`activity_stop` 49.296、`activity_start` 49.514、`activity_resume` 49.519，之后 49.521 Surface 才销毁，49.613 重建。context 3→4→5，view_id 恒为 1；owner 等待、context 初始化均为 0 ms。
- 贴图重载两次 2655/2614 ms，PNG 解码 2161/2135 ms、GPU 上传 194/183 ms，均为 7 张。约 82% 重载时间花在 PNG 解码。用户的卡住/空白有实质的 GL 绘制中断，不能归因于大肥鱼立绘；精确屏幕合成帧尚无录屏/合成追踪证据。
- 已读取构建所固定 Flutter **3.44.9** 的官方源码：普通 `AndroidView`→`PlatformViewsService.initAndroidView`→`TextureAndroidViewController`（hybrid=false、hybridFallback 默认为 false）；`PlatformViewsController` 检测到子树中 `SurfaceView`，走 `configureForVirtualDisplay`。`FlutterActivityAndFragmentDelegate.onPostResume` 调用 `PlatformViewsController.onResume`，后者**每次恢复无条件遍历 VD 调用 resetSurface**，并不先检查是否发生内存回收。
- `VirtualDisplayController.resetSurface()` 会 `presentation.detachState()`、释放旧 VirtualDisplay，再建 Display/Presentation 挂回同一个 View。项目 `CaicaiCompanionView.onDetachedFromWindow` 调用 Android `GLSurfaceView` 的父实现；Android 15 父实现 `requestExitAndWait()` 结束 GL 线程，其退出清理释放 EGL。`setPreserveEGLContextOnPause(true)` 仅解决暂停，挡不住 detach。此源码路径与“先 activity_resume、再 Surface 销毁、view_id 不变但 context 增长”的真机事件一致；诊断尚未记录实际 detach 调用栈，下一版需补该直接证据与 display ID。
- 首帧字段还存在口径问题：`resume_first_model_frame_ms=36/2` 捕捉到的可能是拆装前旧 context 一帧，或后续舞台显示时的新计时；不能代表完整恢复 2.75 秒。下一实现按恢复/context generation 记录后续重建和首个新 context 模型帧，区分 draw 与合成呈现。
- 菜菜独立项目直接把 GLSurfaceView 挂在 Activity 中，没有 Flutter 的 Virtual Display/Presentation 重建层，故这个差异能解释相同模型在独立项目恢复正常。下一方向是以现有 GLSurfaceView 试验直接 Hybrid Composition，绕开 VD；此前 +278～+281 用过 HC，有背景残影/黑底等真机失败，+282 `6e38280` 改回 AndroidView，因此不能原样回退旧实现或宣称 HC 已验证。要保留当前透明层级、稳定画布/IME、舞台可见性及 dispose 修复，先覆盖这些旧失败项，再交设备验证。自定义 TextureView 仍为已知失败路线。
- 官方源码依据：[AndroidView 创建](https://github.com/flutter/flutter/blob/3.44.9/packages/flutter/lib/src/widgets/platform_view.dart#L787-L801)、[VD 选择](https://github.com/flutter/flutter/blob/3.44.9/engine/src/flutter/shell/platform/android/io/flutter/plugin/platform/PlatformViewsController.java#L223-L241)、[恢复无条件重置](https://github.com/flutter/flutter/blob/3.44.9/engine/src/flutter/shell/platform/android/io/flutter/plugin/platform/PlatformViewsController.java#L1124-L1129)、[VD 拆装](https://github.com/flutter/flutter/blob/3.44.9/engine/src/flutter/shell/platform/android/io/flutter/plugin/platform/VirtualDisplayController.java#L291-L330)、[Android 15 GLSurfaceView detach](https://github.com/aosp-mirror/platform_frameworks_base/blob/android-15.0.0_r1/opengl/java/android/opengl/GLSurfaceView.java#L629-L639)。本轮仅读取诊断/查源码/回填记录，未改产品代码、未构建新 APK。

## 当前任务 · +293 Cedar 目标核对、菜菜动作与模型联网配置迁移（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 用户最新决定：Jev 提示词、选项、概率接近时的本地中性改写、气焰值计分均暂不调整；须用后续明显错误再评估。诊断 2026-09-29 22:50:47 “好啊，走，去玩白房间游戏”：Jev `accept=.89` 且 `applied=accept`，但距上条助手消息约 39 分钟，本地 `recentAssistant<=15分钟` 否决，工具入口关闭，规划 0 轮、Cedar 0 次。移除有效 Jev `accept` 后的时间否决；不可用时窄候选仍有原边界。22:11 的另一问题是 Agent 确实调用了旧钓鱼游戏，这两条因果分别修。
- Cedar：从本轮与近期用户真实游戏名称取目标线索给按需 DeepSeek Agent，旧活动状态保留以供自主续玩；若本轮目标与旧活动不同，首轮不注入旧游戏完整指南。拟调用不同目标游戏的 `get_guide/play` 时，在 MCP 执行前最多重规划一次；仍不一致则不执行并如实说明，普通聊天不新增 DS 工具调用。游戏名称仅来自真实目录；多游戏歧义由 Agent 判断，不按固定关键词直接调用游戏。
- 菜菜：仅说话表演的横向整模平移、身体 X/Z 缩小目标和减慢原生过渡；身体 X 不再每拍强制释放，头、身体 Y、视线、嘴、眉、既有动作照旧。原装 `wink`、`wink吐舌`、`比耶wink吐舌` 进入 Jev 可选短时表情，原生 4.5 秒租期/冲突规则生效；装扮保持手动。需要真机观察实际幅度和速度。
- 模型与联网页右上角导入/导出：仅当前已保存的本页配置，版本化 JSON 包含 API Key，导出前提示妥善保管；导入先完整校验，再写安全存储与原子 DB，失败尽量恢复旧设置、成功刷新并唤醒待重试任务。不包含聊天、记忆、Cedar Token、模型 ZIP。检测无本地 Flutter SDK，依赖 Actions Flutter analyze/test 与 APK 构建。
- 多 Live2D 收口：当前已是菜菜专有的文件目录 `caicai-live2d`、私有 `caicai_stage` 舞台偏好、MethodChannel/PlatformView、`CaicaiMotionPlanner` 参数映射和单 active native runtime。此批保持既有独立边界；第二模型接入时再增加 modelId/profile、独立存储及 modelId+generation 异步结果防串，不能把菜菜 ID 强加给新模型。未声称已实现双模型切换。
- 版本 `0.42.49+293`，分支 `agent/v04249-cedar-target-caicai-config`。最终功能提交远端 `b548cf37375ba6b577c85d12e3214579fa19982b`，tree `ff555e3e6c2a19e796d838606bd69fb13dcf1bad` 与本地源码树一致。早期 Actions 分别由历史版本白名单、旧平移收尾测试容差、目录短名称提取测试拦截；逐项修复后最终 [Actions 36595936006](https://github.com/catkiss62/ai-companion-build/actions/runs/36595936006) conclusion=success：原生烟测、130 项源码回归、Kotlin 测试、Flutter analyze、Dart 测试、release APK、资源和持久测试签名检查通过。
- 未发布 Draft Release `399274286`：[+293 测试 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-b372f5486ed637a4230c)，target=`b548cf37`，asset `598685345`，文件名 `AI-Companion-v0.42.49-293-Cedar-Caicai-Config-APK.apk`，726108578 字节，SHA-256 `4c108da236e0c47e0b2d20647659c2157371be3cc18ebd5a8dd9c43bf246b094`；Release 另附 `.sha256` 与 CI Monitor。未合并 main，未正式发布。
- 待真机验收：Jev `accept` 隔 39 分钟能进入按需 Agent；白房间目标不会执行钓鱼；明确续钓旧存档仍可用；普通聊天仍无额外 DS；三轴和三个 Wink 观感；配置 JSON 往返及错误文件不覆盖。自动测试和 APK 可用不等于实际设备语义与视觉已通过。

## 当前任务 · +292 Jev 游戏语义入口与 Live2D 回前台计时（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 用户在 2026-09-29 切换至 6sol 后批准开始此批并要求复核上下文；本批包含 Jev 语义游戏入口与 Live2D 回前台耗时诊断。菜菜现有模型与未来第二模型的隔离/切换收口仍为后续批次；用户暂缓 Live2D 真机观感验收。
- Jev 游戏意图加入回复前现有 `chat_intimacy_route` 合批问题，无每轮额外 Jev/DeepSeek 调用；`act_now` 或有近期助手回合承接的 `accept` 打开按需 Cedar 规划，`chat/defer` 阻止显式正则误触发，接近概率时归 `chat`。Jev 不可用时仅原显式/窄候选进入 DeepSeek 规划；普通聊天不新增工具请求。唯一 Cedar owner、真实 Outcome 守卫与预算继续有效。诊断新增语义选择及门状态，不写正文。语义准确率仍需独立改写样本和设备实测，不把单元测试当自然语言准确率。
- Live2D 现有 surface 诊断增加 view 身份、Cubism owner 等待、context 初始化、surfaceChanged（含 renderer/纹理重载）耗时、最近 context 的贴图解码/上传累计及恢复后首次有效模型帧耗时。保留当前 EGL、模型加载和桌宠行为；这些本地耗时不能单独证明屏幕合成呈现时间。用户可在诊断导出中比较 context/surface/首帧事件。
- 版本 `0.42.48+292`，分支 `agent/v04248-jev-cedar-live2d-trace` 基于远端 +291 总账 `fb6177f`。首轮功能提交本地 `3e6b100` 与远端 `195da8e` 同 tree `712b753`；Actions `36564832663` 原生冒烟通过，但源码门第 1 项还要求旧版候选轮单独 Jev 调用，未进 Flutter 阶段便失败。已更新该历史门以验证新合批路线，并把 NativeTextureManager/SenRenderer 的受审计源树摘要重钉。本地源码门跑至 28/130 项通过，第 29 项因缺 CI 构建时恢复的 417 个私有桌宠帧而停；后续第二轮 CI 结果见下一条。
- 修复提交本地 `4893b96` 与远端 `8fbbad51e4486c096d4bdb26d5492b18d588f83f` 同 tree `066fc71c00bd3848d3b72dc56e716cb0746a49e9`。第二轮 Actions [36566315566](https://github.com/catkiss62/ai-companion-build/actions/runs/36566315566) conclusion=success：原生冒烟、130 项源码门、Kotlin 桌宠/悬浮窗测试、Flutter analyze 与测试、arm64 Release、资源及稳定签名校验通过。Draft Release `399109401`：[+292 未发布测试 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-0646b808f36e63198f97)，target=`8fbbad51`，asset `598175410`，文件名 `AI-Companion-v0.42.48-292-Jev-Cedar-Live2D-Trace-APK.apk`，726106342 字节，SHA-256 `e64b827c9726476d97d2d516a7c6ea0596bb9de62ba492340763cf6a9818a510`。签名验证步骤成功，同一持久私有测试签名身份；未发布正式 Release。
- 真机待验：邀请的改写/反问/否定/延期/话题切换和“走着”“开始吧”后是否出现正确 Cedar Outcome，普通聊天不触发工具规划；统计 Jev 的实际选择、误触发/漏触发与费用。Live2D 回前台导出 `surface` 的 view_id、owner_wait_ms、context_init_ms、surface_changed_ms、texture_decode_ms、texture_upload_ms、resume_first_model_frame_ms，结合 GL context 和 frame trace 判断空白阶段；当前 CI 与耗时指标不等于真机可见观感通过。+290 Jev 动作真机验收仍独立待定。

## 2026-09-29 后续检查 · Jev 路由与多 Live2D 收口（DISCUSSION / NOT IMPLEMENTED）

- 用户暂缓Live2D真机观感验收，要求检查+291游戏入口、DeepSeek附件建议及未来第二套Live2D切换；本轮仅检查及方案，未改产品代码/未构建新APK。
- 路由事实：9月25日`4171c67`已有按需DeepSeek工具规划；近期`a6d08fa`已有Jev上下文判断；+291新加用户邀请短时续接，非整段回退。显式正则直接开规划；候选续话只有第二通道模式才先问Jev，单DeepSeek模式交同次工具请求判断。续接先受24字/固定开头、原始用户邀请、15分钟/6条消息/最多两次确认约束；未进入候选者Jev看不到。Jev两类概率差≤0.10时本地归chat；Jev无效才候选轮交DeepSeek。985项CI通过不构成自然语言准确率评测。
- 建议待批准：将“现在执行/接受邀请/讨论/拒绝延期”等语义交回复前Jev，优先与同阶段短判断合批；后置表演Jev不能用于提前路由。避免继续增加固定口令作为必要入口。需用未参与提示词设计的改写/否定/反问/延后/话题切换样例量误触发、漏触发、Jev与DS调用数和费用，不宣称已有准确率。
- 附件定点核查：NativeTextureManager确实decodeFile后recycle；上下文恢复reloadRenderer重建渲染器/贴图而保留CPU模型，hostResume已requestRender。contexts计数onSurfaceCreated，surfaces计数onSurfaceChanged（尺寸事件也加），不能单凭计数断言耗时原因。CaicaiRuntime.attach会dispose旧owner，不能由IndexedStack断言永久双owner争抢；信号量等待仍需owner/等待时长证据。优先补context/surface/view身份与decode/upload/首帧耗时。CPU缓存需实测收益与内存预算；RGB565无alpha不适合透明贴图；直接draw不能保证交换缓冲与合成显示，不将其承诺为消除秒级空白。自管EGL/不onPause/改composition均暂不采纳为默认修复。
- 多模型收口建议：共用宿主+单活动renderer+每模型adapter/capability profile；菜菜现有已验证渲染与配件数学封装保留。素材与舞台/摸头/衣装/幅度设置按modelId隔离；模型档案提供语义动作、实际参数ID/方向/范围/中性值、物理后写入及混合优先级、预设与可用能力。Jev根据活动档案取得选项。每次切换递增session generation，Jev/动作/异步回调都校验modelId+generation，防旧模型结果落到新模型；保留两套磁盘资源，默认只驻留一套渲染实例，失败恢复旧模型。以上尚未实施，第二套模型具体参数需拿到后标定。

## 当前任务 · +291 Cedar 邀请路由与诊断导出（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 2026-09-29 用户明确授权修改、推送与构建；基于 +290 总账 `48d1e0e` 开始。+290 Jev 动作真机验收继续独立待定。原调查与失败路线见下节。
- 实现：`陪你/跟你/和你 + 钓鱼/下棋/打牌/游戏` 纳入显式邀请，延期表达不视为立即进入；最近15分钟且最多6条消息、两次简短同意内的原始用户邀请成为候选。若期间拒绝/延后、话题转移或已有实际 Cedar Outcome，候选撤销。含糊确认由 Jev 判断，Jev 失效时仅候选轮开放原 DeepSeek 工具规划；普通聊天不增加 DeepSeek 调用。保留现有 Cedar 工具 owner、预算、Stop 及运营声明守卫。
- 路由诊断保存最近12条时间、候选原因、规划轮数、Cedar Outcome 数及 Jev 门状态，不保存正文/参数。Android 报告保存上限2→16 MiB，流式复制保持；缺失/超限错误区分并在页面显示类别与大小，完整 Jev 报告不截断。
- 2026-09-29 用户再次明确批准将本地 `4f6ab85` 推往指定公开仓库的现有分支并触发未发布测试 APK。Git HTTPS 因本机无凭据失败；用已连接的 GitHub 仓库接口上传同一 tree `37f4f27e4bf175b7f7893abfa1c32ca6f1d16642`，与本地提交 tree 完全一致，远端功能提交 `964483e6c63ff13ef0021195e393744c7f155106`，父提交 `48d1e0e`。两次早期自动审批拒绝及无凭据失败仅是交付路径，不是代码 CI 失败。
- Actions [36553832513](https://github.com/catkiss62/ai-companion-build/actions/runs/36553832513) conclusion=success：原生模拟器、源码门、Kotlin、Flutter analyze、985项 Flutter 测试、arm64 Release、资源与签名校验通过。Draft Release `399039624`：[本次 +291 测试 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-cccaadca93c93fd4c7d9)，target=`964483e`，asset `597938006`，文件名 `AI-Companion-v0.42.47-291-Cedar-Diagnostic-APK.apk`，726099994 字节，SHA-256 `dfe11685cdc81f2dcf0744171c5349f1e7465544d6b65ef42a70aeff8ed927a4`；Release digest 与 CI 一致。签名 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48` 与 +290 相同，可覆盖安装保留数据。仓库另有同版本号 +291 的不同草稿，务必以本段目标提交与 asset 识别本次包。
- 真机待验：用“陪你钓鱼？看你今天都没钓鱼”直接邀请，及“走着”“开始吧”续话，确认 Cedar 真实工具调用、结果与对白一致；再试普通闲聊、拒绝/改天、15分钟过期与已有 Outcome 后无多余 DeepSeek 规划。导出超过2 MiB的完整脱敏诊断报告，并查看 `cedarRealtime.recentUserRoutes`。CI 不能替代真机语义和系统文件选择器验收。+290 Jev 可见动作仍单独待验。
- 新版本 `0.42.47+291`，已补单元测试和历史版本门；本地7项历史版本门、Cedar相关源码门与差异格式检查通过；本环境没有Flutter SDK，Dart/Android测试待CI。推送至 `catkiss62/ai-companion-build` 的现有分支两次被自动审批拒绝，远端仍为 `48d1e0e`，因此当前尚无 CI、APK 或真机证据。自动审批认为上传仓库源码/历史到该目的地有外传风险，需用户对具体目标再明确批准；不得通过其他通道绕过。

## 当前接班调查 · Cedar 跨轮漏触发与脱敏诊断导出（DESIGNED / NOT IMPLEMENTED）

- 2026-09-29 接班调查已完成，承接用户“先出方案”的要求；本节仅记录证据与拟实施方案，没有修改产品代码、运行新 CI 或生成新 APK。基线仍为 +290；+290 真机动作验收独立待定。
- 用户私有备份仅在本地分析，没有上传仓库。末尾三轮含一次共同钓鱼邀请和两次简短确认，均有正常模型正文，却没有新增 Cedar 工具 Outcome；不得把拟开始的对白算作游戏实际推进。存档当时活动游戏为另一款、会话 mode=unknown / phase=guide_ready。当前 `CedarToyArcadeSkill.isRelevant` 未覆盖“陪你+钓鱼”句式；续话候选要求可续玩的 solo 会话，`hasUserTurnContinuation` 对 guide_ready 不开放；因此这三轮都可能在 DeepSeek 工具规划之前被挡住。已核对相关源码，最终真机路由仍需新诊断证据。
- 历史入口：`4171c67856`（2026-09-25）在 `durable_generation_runner.dart` 通过显式意图或用户回合续接决定 `cedarSkillActive`，普通聊天不因此调用 DeepSeek。后来 `98f42ac9cf` 和 `be9bbf5f35` 扩展上下文入口，`a6d08fad9a` 收窄并加入 Jev 决策。应保留按需门控结构，不直接回退旧代码；旧规则同样不完整覆盖这次跨轮邀请。
- 方案：显式“陪你/和你+游玩动作”仅作为窄候选，普通提及游戏、筹码、摸鱼不触发；根据最近少量用户/助手轮次维护有时限、可取消的未完成游戏邀请，短句同意只在有用户原始邀请且尚无真实 Outcome 时成为候选。候选有歧义时一次 Jev 判断；Jev 不可用才在这个候选回合交给既有 DeepSeek 工具规划。真正确认后仍由唯一 Cedar Agent owner 读实时目录/指南并执行，遵守预算、Stop、切换与服务端事实；不得从助手自行承诺开启游戏。正文若无真实 Outcome，不能声称已开始、已落子或已下潜。新增每轮有界路由诊断：候选原因、是否 Jev/DeepSeek、工具规划与 Outcome 数、零调用原因；不记录私密正文。
- 诊断导出根因：`SystemBridge.startDiagnosticReportSave` 在打开系统文件选择器前拒绝大于 2 MiB 的报告，错误为 `diagnostic_source_invalid`；`PreflightDiagnosticsService.run` 完整纳入最多120条 Jev 问题、上下文、概率及费用。此备份 `jev_short_usage_v1` 原始 1,645,590 字节，按双空格缩进的 UTF-8 JSON 单独约 2,103,848 字节，已超过 2,097,152 字节上限，尚未计入报告其他字段。方案是在原生保存入口采用明确更高且有界的本地报告上限（建议 16 MiB）并保留流式复制、完整 Jev 证据与脱敏约束；页面显示具体错误类别/体积，避免只有异常类型。不得截断 Jev 历史掩盖问题。
- 实施时验证：用末轮三回合语义重放，确认只开一次按需工具规划、真实 Outcome 才能支持完成声明；普通游戏闲聊、无关短句、拒绝/延后、旧会话不同游戏及 Stop 不误触发；诊断报告超过2 MiB可保存且内容完整，取消和超上限显示明确原因。实现、CI/APK、真机三项分别登记，不提前勾选。下一步从本节进入上述两项修复，随后返回 +290 Jev 动作真机验收。

## 当前任务 · +290 Jev 四拍可见动作恢复与适中调节（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 用户真机确认 +289 桌宠尺寸已经修好，但 Jev 对话动作偏小且与待机难区分；随后明确发现可见动作次数变少，要求恢复此前 Jev 每拍的可见动作，只在幅度与速度上按已讨论的适中方案调整。+289 功能及 APK 是回退基准；无需改桌宠、待机、摸头、视线、输入法画布和双通道正文。
- 代码差异：+289 把四拍的“夸张”选择本地压为仅一拍，整模探身压为最多一次，同方向身体 X 取消了拍内释放；Jev 文案也引导保持同一姿势。上述改变减少可见姿势变化，叠加较小目标值和较慢过渡，不能单凭提高参数目标修复。用户当前没有提供这版逐轮 Jev 原始选择，不能冒称模型实际选择次数已确认。
- +290 恢复四拍各自强度/整模选择和身体 X 每拍释放；Jev 文案鼓励有语义的多次姿势变化，但不强制机械左右交替。头部侧头 ±25（强调 ±28）、俯仰 ±24、歪头 ±23；身体 X/Z 常用约 ±6、强调约 ±6.72，整模探身 5.5% 模型宽，腿支点约 5°；同时选整模和身体 X/Z 时保留 0.75 混合限幅。节奏每拍 .82/.95/1.10 秒，空间插值 3.4（+289 为 2.7），过渡 34% 拍长；人脸、口型及自主待机不变。四拍仍严格最多八个原生 keyframe；任何实际行为/手感待真机验收。
- 开发分支 `agent/v04246-jev-visible-motion`，版本 `0.42.46+290`。本地功能提交 `3943d4b01c895a0fdf840934acc69b1f9bd058a3` 与公开分支功能提交 `dd3347faa279468d88cedaed0d8fe06d96b1915f` 共享完全相同的 tree `fdc9b086ec4090ca371adf7ad466f302222eeea0`，均基于 +289 总账提交 `8d318c6f`。只推公开源码、测试、总账；无用户存档/诊断/模型素材；未合并 main、未正式发布。
- Actions [36527469120](https://github.com/catkiss62/ai-companion-build/actions/runs/36527469120) conclusion=success：原生模拟器、源码回归、Kotlin 桌宠/悬浮窗测试、Flutter analyze 与测试、Release 编译、签名身份和包内资源校验通过。未发布 Draft Release `398862838`：[+290 测试 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-fdf0e1749b6a7d2d8112)，target=`dd3347f`，asset `597420421`，文件名 `AI-Companion-v0.42.46-290-Jev-Visible-Motion-APK.apk`，726100546 字节，SHA-256 `f36a463e844d0cbb3f6a009137880c1bb57b5f466a14253dbf5ab8d2c27ff863`，Release digest 与 CI 日志一致。签名 SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48` 与 +289 相同，可以覆盖安装保留数据。
- 真机待测：同一类对话比较 +289 和 +290 的动作次数、头身幅度、左右位移与节奏，看是否恢复可见变化且没有回到 +288 的“到处乱撞”。四拍可自主选择，不保证每次对话一定四次大动作；以具体 Jev 选择和最终画面复验。用户已确认 +289 桌宠修好，+290 没有改桌宠代码；输入法保持 +288 的固定画布。

## 当前任务 · +289 Jev 动作贴近待机、桌宠重装后尺寸（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 用户确认输入法打开时 Live2D 不再错误缩小，要求维持这一版为回退基准；但 2026-09-29 09:00 中国时间三份实测文件标为 `0.42.43+287`，不是 +288，故不把 +288 标记为设备正式通过。用户明确批准本轮实施上一轮与本轮讨论的幅度、速度调整；待机效果满意，应保留。
- 存档最后两轮 Jev 说话计划：均用 0.62 秒的“俏皮快拍”，末轮四拍全选 120%“夸张”并重复“右侧头＋俏皮侧身”；身体 X/Z 和头 X 被截到各自模型边界，整模左移达到模型宽度 12%。旧计划每 .341 秒中途释放身体 X，即便下一拍仍是同一姿势也会反复回弹。
- +289 实施：Jev 说话专用预设头部常用约 ±20～22、强调最高约 24～25；身体 X/Z 基准约 ±5、强调不超过约 ±6，身体 Y 约 ±6～7；整模水平探身基准 4%、腿支点约 4°。强拍全选四次时本地只保留一次强拍，整模动作至多一次；整模与身体 X/Z 同时选中时后者降低 25%。节奏每拍 .86/.98/1.15 秒，过渡 42% 拍长；原生仅减缓空间参数插值，嘴、眼等短反应保持原速。重复同方向身体 X 保持，不在中途释放；末拍回待机。`CaicaiIdleMotion` 自主待机与视线、摸头不改，全局用户调节数值也不改。需在真机看是否仍偏快或偏弱。
- 桌宠代码证据：`PetOverlayWindow.attach()` 在无障碍窗口管理器暂未连接时以普通悬浮窗挂载，只分配旧正方形宽度；新版 16:9 帧由 `PetFrameView.displayScale()` 的宽度适配缩小，旧动画影响不明显。打开系统文件选择器会触发悬浮窗移除/重建；若无障碍服务此时已经连接，重建为宽窗口便恢复原尺寸。+289 在无障碍 `onServiceConnected()` 通知悬浮服务，仅在桌宠仍挂在旧窄窗且无系统遮盖/聊天展开时进行一次受控宽窗重绑，不更改现有透明触摸区域或桌宠校准默认值。诊断尚缺缩小当时的 `attach trusted=false` 记录，机理与复现匹配，标记为待真机验收，不能冒称已证明设备因果。
- 开发分支 `agent/v04245-jev-motion-pet-scale` 基于 +288 head `3bd5fc0dd25c760e7d4ca9760e45b47e1da1f1e3`，版本 `0.42.45+289`。用户在当前对话明确授权公开分支推送和未发布测试 APK 构建；本机 Git HTTPS 无凭据，使用仓库所有者连接创建远端功能提交 `f853ef397f972d552f2517f0aff670556100fc35`，tree `269a3350a8b1d98b498314a03c7cb0971a7cc018` 与本地已检查工作区逐字节一致。没有将用户存档、私有分片或诊断加入提交；保留 +288/+287 回退，不合并 main，不正式发布。
- Actions [36517195317](https://github.com/catkiss62/ai-companion-build/actions/runs/36517195317) conclusion=success：菜菜原生冒烟、130 项源码门、Kotlin 桌宠/菜菜单测、Flutter analyze、983 项 Flutter 测试、arm64 Release、资源与签名核对通过。本地源码回归因缺少 417 个构建时恢复的私有桌宠帧，在第 29 项停止；CI 在恢复帧包后完整通过，不能把本地暂停误记为 CI 失败。
- 未发布 Draft Release `398808965`：[测试 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-43632f0cf8e06a13f5d5)，tag `v0.42.45-jev-pet-scale-test`，target=`f853ef3`。APK `AI-Companion-v0.42.45-289-Jev-Pet-Scale-APK.apk` asset `597176654`，726101222 字节，SHA-256 `07b3686022ce40ad0177dfaeb612548bd7866f695e0a4aa1b18e82768cf83085`，与构建日志和 Release digest 一致。签名 SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48` 与 +288 相同；可覆盖安装，不卸载数据。
- 真机待测：最近两轮相同语境观察 Jev 是否仍过快/过大，同时确认待机没有被压小；重装或覆盖安装后立即看新版桌宠动画与点击动画，不能先打开系统文件页面，随后可打开文件页面对照是否还发生尺寸跳变。无障碍服务完全未授权时仍走普通窄窗回退，不能宣称该路径已与宽窗同尺寸；若变小，立即导出普通脱敏诊断对照 `attach trusted` 与 `fit` 轨迹。输入法尺寸问题沿用 +288 的固定画布，未在 +289 改动。

## 当前任务 · +288 输入法固定画布与桌宠尺寸追踪（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 事实：用户确认 +287 头部动作已灵动、总体效果很好，但打开输入法 Live2D 仍会缩小。2026-09-29 05:48 中国时间导出的 Live2D 诊断在同一进程记录到 surface/view 由 1280×2052 缩到 1280×1322，sceneHeight 同时到 1321.5；关闭输入法期间 surface 一度达 2205。+287 的“IME仅遮挡”没有在真机成立，不能标作已验收。
- 修复：Flutter CaicaiStageViewport 以已知完整高度为基准，忽略输入法动画里零 inset 但窗口仍短、以及 inset 与布局临时超额的中间帧；聊天舞台的 AndroidView 本身保持完整高度，外层布局遮住下半截，原生缓冲不再随可见聊天高度重新适配。背景既有完整高度保留。新增时序测试，更新旧源码门检查固定画布。
- 桌宠：用户报告仅新版动画（含点击）偶发缩小，旧动画正常，导出后恢复。之前诊断可证明文件选择器导致悬浮窗脱离并成功重建，但不能证明变小那一刻具体原因。本版不猜测性调高已有正确视觉的默认数值；脱敏诊断新增最近24条桌宠渲染轨迹，含动作ID、bitmap尺寸、视图/逻辑窗口、留白、适配比例、实验动画开关和校准值，并记录挂载时可信悬浮窗状态。再复现时应在异常发生后立即导出普通脱敏诊断，对比相邻记录。
- 回退主基准：+287 功能提交 `3582ff0ce6399aa0eeb5998e38acfe0ada852907`，APK SHA256 `21cd6c313ccca3091e6d1e76914a4650775b2a4b468cb57e71d1cc47b5707aca`；+286、+285 也仍可追溯。覆盖安装须用更高 versionCode 的恢复包，不卸载用户数据。
- +288 功能与版本最终提交 `e4655ea8357897052c7e8b72d5b18ee03b78f91f`，Actions `36492157673` conclusion=success。原生3项模拟器测试、130源码回归、Kotlin桌宠/悬浮窗测试、Flutter analyze与982项Flutter测试、release打包、资源校验与签名均通过。前两轮构建 `36489492272`、`36490815159` 分别由历史固定画布断言和历史版本白名单拒绝，均已更新后重跑通过。
- Draft Release `398665497`，tag `v0.42.44-caicai-ime-pet-trace-test`，target_commitish=上述功能提交，未正式发布：[测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-21985d5229af921530dc)。APK `AI-Companion-v0.42.44-288-Caicai-IME-Pet-Trace-APK.apk` asset `596598655`，726099246字节，SHA256 `c0457e8d92d0157689546f01f39cad21db7ad6981500f8d813a79310fcaf0b42`，构建日志与release digest一致。sidecar `596598654`，CI monitor `596598670`。签名SHA256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48` 与 +287 相同，可覆盖安装，无需重新导入模型。
- 真机验收：反复开关输入法，观察头宽/人物大小与背景位置保持，键盘只遮住下半截；如仍改变，在键盘保持打开时导出Live2D专用诊断。桌宠若再次变小，当场导出普通脱敏诊断。桌宠缩小仍为待定因，不能称此版已修好。没有将私有存档/诊断/模型上传仓库；未合并main。

## 上一版 · +287 固定场景与菜菜交互收口（CI PASSED / APK READY / TRUE DEVICE PENDING）

用户 2026-09-29 04:19 中国时间批准上一轮八项方案全部实施；查询进度/网页卡住导致的打断不取消任务。禁止遗漏或将“命令发出”算作视觉通过。

- [ ] 1. IME 仅遮挡下半身、模型大小/锚点不变：+287 真机仍缩小，+288 代码重修，待实机复验；背景和渲染目标同步保留。
- [x] 2. 以菜菜实验室“左右大幅/上下大幅”按钮的成功执行顺序为基准，统一 Jev/待机/视线的头部控制，记录写入/物理后/最终参数。
- [x] 3. 保留 +286 满意的动作基础，增加动作族/参数变体/近期去重/连续衔接。
- [x] 4. 参考 Sen 完整摸头（按住/释放/彩蛋/从当前表情渐变），与待机及视线混合，映射使用菜菜参数。
- [x] 5. 消失重现尚未定因；补有限容量可导出诊断、成功绘制/上下文/可见性/画面边界和 FPS，摘要并入脱敏诊断。
- [x] 6. 情绪及临时表情/按钮总时长4.5秒含淡出；事件去重避免重建续期；衣装持续。
- [x] 7. 对应白袜/白丝按钮显示“丝袜”，内部预设 ID 不变。
- [x] 8. 目标60FPS，保持已存在的512px高精度蒙版，实测FPS不冒称设备稳定60。

回退：+286 功能 `0627376f4f787a072cdabe94c8f25ab78da8b445` / APK SHA256 `2838c8967924de7144b892c73915f9f283725659909210cb35af9f75943c7da6`，用户确认比+285更好；+285仍保留。+286遗留以上缺陷，不标整版真机全通过。
保护：GLSurfaceView导入/生命周期、配件原始标定、TTS口型、双形态、第二通道正文/修正及400失败兜底、桌宠默认；私有资源及既有脏part-075.bin排除提交。开发分支持续推送/Actions/Draft APK已授权，不合并main不正式发布。
下一步：实施并逐项验证；版本 `0.42.43+287`。完整构建与手机观感分别报告。交付必须包含修复清单、未证实项、总账更新确认。

实施说明：八项实现已落地，勾选仅表示代码完成，不表示真机通过。头部复用实验室X3/Y2的物理后最终写入，三个生产入口共用CaicaiHeadPose；捕捉X/Y同时进入诊断，未盲目改名。裁切放在原配件标定完成后的共用最终矩阵，原标定源码哈希保持通过。摸头状态独立混合，普通按住/释放、10%彩蛋及手动彩蛋预览；待机8类动作及参数变体、最近3类去重。所有情绪按回复事件计时、同事件Jev修订不续期、界面重建不重播。细诊断180条/每秒一条内存缓冲；60FPS目标/512px蒙版。

本地验证：纯Java实际算法检查通过（相机像素不变、物理后目标恢复、4.5秒事件租约、摸头持续/释放、待机去重与连续性），原生基线/资源哈希通过；完整source suite因本地未物化417张旧桌宠帧在资源门停止，将在CI物化后验证，不删门禁。Flutter/Android完整测试和APK尚未完成；消失重现仍属于待诊断项。

构建进行中：功能首提交 `2cb8d94ccf8e601cbb710abc0e7ec846d81c3da0`；补齐当前脸部渐变、编辑场景坐标及可见性诊断后，最新功能提交 `3582ff0ce6399aa0eeb5998e38acfe0ada852907`。当前 Actions `36480742163`；较早 `36480332751` 因同分支新提交自动取消，不是测试失败。工作区无功能修改待推送；原有私密分片脏文件保留未提交。最新 Actions 全绿：原生冒烟 job `109125728718` 的3项测试成功（视图创建/生命周期/resize/导入事务）；主构建 job `109127573579` 的130项源回归、Android/Kotlin单元测试、Flutter analyze、982项Flutter测试、release打包、签名和资源校验全部通过。

### +287 交付核验 · 2026-09-29 05:02 中国时间

- 功能提交：`3582ff0ce6399aa0eeb5998e38acfe0ada852907`；Actions `36480742163` conclusion=success。APK Artifact `10998290387`；原生测试 Artifact `10997007849`。
- Draft Release `398607461`，tag `v0.42.43-caicai-interaction-test`，target_commitish已核对为上述功能提交；仍为未发布草稿：[测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-a70c7a69b15ad2fc6c12)。
- APK `AI-Companion-v0.42.43-287-Caicai-Interaction-APK.apk`，asset `596404892`，726,098,462字节。SHA256 `21cd6c313ccca3091e6d1e76914a4650775b2a4b468cb57e71d1cc47b5707aca`，已核对构建日志与Release asset digest一致；sha256 sidecar `596404894`，CI monitor `596404896`。
- 签名与+285/+286一致：`30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。无需卸载；未将APK下载回工作区，未合并main、未正式发布。
- 八项代码与自动化已交付，真实手机上的固定视觉尺寸、明显头部运动、连续摸头观感、4.5秒表情以及实际FPS仍待用户验收。模型消失重现未宣称修复：若复现从Live2D设置单独导出诊断。
- 测试顺序：开关键盘看人物头宽/位置不变；左右大幅/上下大幅对照生产待机、跟随和Jev；连续摸头/松手/彩蛋；情绪按钮4.5秒淡出；观察待机丰富度及诊断实际FPS。不要求重新导入模型。

## 上一批 · +286 菜菜表演调节与输入法几何修复（CI PASSED / APK READY）

- 用户明确确认：+285 头部各轴已有效，现阶段是幅度/速度调节；+285 功能成功，作为可回退基准。已授权直接实施，无需继续方案确认。
- 回退基准：`0.42.41+285` / 功能 `6cfca5ae303f384283a653d1627ff4a548150322`；Actions `36455411205`；Draft APK SHA256 `0f28b4dd43a2b5ffe00bedcd21878984c086cbe077d22d3433199f6b454968c6`。已知缺陷：输入法拉伸；动作偏小偏慢、摸头/视线优先级待修。不以整体 TRUE DEVICE PENDING 覆盖用户已确认的功能成功。
- 范围：稳定输入法期间舞台与 Cubism 渲染尺寸；明显的头眼跟随、摸头；更快且夸张的待机/Jev；统一整模水平位移和小腿支点倾斜，由 Jev 选择方向、幅度和节奏。本地逐帧执行，仍只有每条回复一个批量 Jev 请求，不新增循环所有者。
- 证据：当前窗口变化仅更新 glViewport，未同步 Cubism render target；摸头参数计划后执行的 applyAttention 会覆盖其头部 Y。两者是代码问题，尚不冒称已证明真机拉伸/卡顿全部原因。头部参数按用户确认有效处理。
- 保护：+285 GLSurfaceView/导入事务、原 renderer/三配件标定数学、TTS 口型、19 情绪/衣装/4.5 秒预设、第二通道正文及 400 兜底、桌宠默认不回退。已有脏二进制 part-075.bin 排除提交；不上传私密模型/诊断，不合并 main、不正式发布。
- 验证：位移支点/逆变换、参数上下界和优先级、Jev 请求及本地动作、窗口尺寸与生命周期；现有源/资源/路由门禁和 Flutter/Android 测试，Draft APK。私有模型视觉、键盘延迟与夸张程度仍需用户设备调节，不用空场景GL测试代替。
- 交付：`0.42.42+286` / 功能 `0627376f4f787a072cdabe94c8f25ab78da8b445`，Actions `36468439975` 全绿（129源门、3原生冒烟、Android单元测试、Flutter analyze、982 Flutter测试、release与签名/资源门）。Draft `398534068`：[测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-6536c4ec9e8814a55b44)，SHA256 `2838c8967924de7144b892c73915f9f283725659909210cb35af9f75943c7da6`。默认幅度100%/速度100%/支点88%；先原样实测再调节，尚不标 TRUE DEVICE PASSED。

## 上一批 · +285 恢复 Live2D 并核对全部正文入口（CI 通过，测试 APK 已交付）

- 用户 22:46 明确批准：先修 Live2D，保留 +284 的大动作/表情、4.5 秒释放、按钮回聊天、同屏舞台/摸头框编辑、全界面视线、气焰修正；同时核对所有正文与真实性修正优先第二通道（400 可 DeepSeek 兜底），桌宠只改截图可见默认值。网页卡住暂不处理。
- 基线：`1a08a2d` / 功能 `b7b578a` / `v0.42.40+284`，分支 `agent/v04232-caicai-import-pet-touch`。+284 状态更正为 **CI PASSED / APK READY / TRUE DEVICE FAILED**。
- 已定位：TextureView 构造函数沿用 setBackgroundColor 导致原生视图创建异常；导入路径混用 canonicalFile 与未规范化根目录，目录别名下可复现移动后读回失败；主动回复存档记录第二通道 HTTP 400，最近主动 prompt 只有 system 消息。设备实际路径与 400 响应细节未保存，不能冒称两者均已真机定因。
- 计划：恢复已验证 GLSurfaceView 宿主、统一规范路径和导入事务、捕获创建及首帧失败；审计普通/主动/分享/悬浮/沉浸/游戏房间正文及修正分支，统一请求适配和路由；默认缩放151%、宽91%、x0/y1dp、色阶0/0.86/230、输出0/255、饱和度100%。
- 保护：原菜菜 renderer/三配件数学及资源哈希、TTS 口型、衣装、19 情绪、已实现的交互和大动作不丢；桌宠偶发缩小仍无证据，不猜修；不上传私密存档/诊断/模型；不合并 main、不发布正式 Release。
- 验证要求：路径别名/重导/回滚、真实 Android View 创建与生命周期、各正文入口路由/修正/400 兜底回归；CI 与真机分开。真机画面、键盘延迟和触摸观感须用户设备验收，不用测试数量代替。

### +285 实施与 CI 记录

- 状态：IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。最终功能提交 `6cfca5a`，Actions `36455411205` 全绿，979 项 Flutter 测试及原生回归通过；最终包和证据见本文件末尾 +285 交付核验。恢复 GLSurfaceView 原生宿主，保留 30 FPS 节奏与 +284 全部表演接口；释放事件在原 GL 线程退出前完成，进程级 Cubism 所有权串行交接。原始 renderer/三配件数学哈希未动。
- 修复导入 root/file canonical 混用：所有索引都相对于规范化目录；staging 提升 current、backup 回滚和索引恢复使用同一规范。构造异常纳入错误通道；素材存在不再显示为画面就绪，30 秒加载看门狗仅在前台活跃舞台计时。诊断增加 build/首模型绘制帧，旧记录标 legacy_unknown。
- 第二通道：普通/后台聊天与桌宠共用 runner；主动所有 intent（含网页/游戏分享）共用 proactive；另核对 Cedar 房间、沉浸、日历。各正文入口显式使用 FinalReplyRoute，真实性/重复修正不改变路由，实际失败（含400）才兜底。系统消息专用任务增加“内部表达任务，不是真实用户发言”封装，不写聊天历史；400根因仍未证实，只修复已发现的system-only请求兼容风险。内部规划/Jev继续保留原通道。
- 桌宠默认：151% / 宽91% / x0dp / y1dp / RGB输入0、0.86、230 / 输出0、255 / 饱和100%；已有用户设置保留，截图外配置不改。
- 继续审计发现工具规划的 DeepSeek 前言会拼接到最终正文；双通道模式禁止拼接该内部前言，Gemini 截断待确认候选的即时展示也标记实际通道；手动保留旧截断草稿时的历史 model 元数据不可作为正文实际供应商证据。
- 宿主生命周期补强：临时 detach/reparent 只让 GLSurfaceView 重建 EGL，不把模型标成永久释放；真正 dispose 在原线程仍在时排队释放，若 Flutter 先 detach 再 dispose，则在旧 EGL 已销毁后清理剩余 Cubism CPU 状态并移交所有权。测试增加临时重挂和先 detach 后 dispose。
- 新增真实 Android emulator 门禁：直接编译生产宿主与仓库，测试 View 构造、空场景GL帧、暂停恢复、已暂停旧实例释放/新实例接手；导入测试覆盖别名目录、嵌套中文路径、提升读回、损坏包保留旧包、回滚、索引恢复、删除后重导。结构假模型不用于绘制，不构成私有模型真机成功证据。
- 首轮原生门禁运行 `36441861951` 在编译 smoke 时失败：Kotlin 未继承 Java SourceSet 的 exclude，误编入依赖 Flutter 的 PlatformView 适配器。改为 Sync 精确选入生产导入仓库/路径/诊断三文件；宿主/renderer 仍直接编译生产 Java 源码。没有删除测试或降低门禁。
- 后续 smoke 配置失败 `36442598138`：SourceSet 不接受 Sync Task 作为目录 notation，改为明确 generated 目录并保留 preBuild 依赖。`36447749140` 已完成编译并执行2项 Android 测试，导入事务通过；渲染初始化失败指出测试包漏装 Cubism shader assets，补齐生产 shader/profile 资源（生产 APK 已有独立资源门）。CI 失败监视器另改为文件输入，避免大日志触发命令参数长度上限。
- `8dc7cc0` / Actions `36448394737` 的 Android 原生门禁于2026-09-29 00:08中国时间通过：2项 instrumentation 测试，涵盖别名导入事务和宿主 EGL 绘制/暂停恢复/重挂/释放交接。仍未使用用户私有模型进行设备画面验收；完整 APK 检查与构建继续执行。
- `36448394737` 后续完整检查：128源回归、Android/Kotlin单元测试、Flutter静态分析通过。Flutter为973通过/6失败，失败全部是新HTTP夹具在http.Response中用默认Latin-1编码中文，未进入路由断言；显式改UTF-8响应夹具后重跑，不删除失败用例或放宽断言。
- `36450788936` 原生复跑出现进程 SIGSEGV。已下载 instrumentation 原始 logcat：崩溃线程是 Android10/API29 x86_64 的 Jit thread pool；栈为 libartbase Hc4_MatchFinder_GetMatches → LZMA/XZ → PackElfFileForJIT/GenerateJitDebugInfo，无应用/Live2D栈帧。API29前次通过仍保留，但不凭一次通过声称稳定。门禁改用API35 google_apis镜像保持JIT/断言启用，生命周期重复从2增至4；产品代码未据此猜改。API29真机兼容性仍未验证。
- `058288d` / Actions `36451634195`：API35原生门禁通过；同一生命周期测试连续4轮（包含临时重挂、暂停后替换、先detach后dispose）全部完成，导入事务通过。仍保持真机画面与输入延迟待用户设备确认。
- 最后核对后台/桌宠重连显示：生成检查点曾把 agent_tool_planning 的 DeepSeek content 写入 partialContent，虽然实时回调不发正文，重连读检查点仍可能短暂显示。规划检查点现只保留独立推理，正文为空，直到最终回复通道生成正文；源门新增断言。
- `053ceb4` / Actions `36452994727`：API35原生门、128源回归、Android/Kotlin单元测试通过；Flutter静态分析发现新路由测试的`http.Response(encoding:)`参数不存在（2处）。前一轮修复中文夹具时错误假设了构造签名，现按http1.6.0实际API改为`Response.bytes(utf8.encode(...))`，显式UTF-8事件流头；保留所有请求与路由断言。此次失败属于新增测试代码错误，继续重跑全部门禁。
- 本地原菜菜渲染/资源哈希门、路由连线门已通过；全源门初跑识别到旧版版本白名单/旧路由断言，已按本次新合同更新。环境缺Flutter/Kotlin编译器和部分CI恢复资源，完整编译/自动测试交给既有CI恢复环境；不降低资源门。

## 上一批 · +284 菜菜专项动作与舞台体验（真机失败，待 +285 修复）

用户已明确批准实施，并补充：以菜菜标注的真实可动参数专项设计；以 anai-1.1.53 APK 的幅度、速度作主要参考；Jev 驱动丰富头身表演；视线覆盖输入框、聊天记录及其他界面触摸。

- 基线：0fd3cfc（+283 CI/APK 成功后的总账记录）。所有上一轮未经汇报的试改已撤销，本轮重新实施。
- 证据：菜菜捕捉轴 X/Y 显动弱，应使用 X3/Y2；现有键盘逻辑停止连续渲染；手动预设永久 toggle；诊断有重复 surface/context 重建；普通形态 19 条气焰记录被固定扣 18。
- 本轮代码已实现：模型专用待机与 Jev 大动作；4.5 秒手动释放；按钮回聊天；聊天内舞台/摸头框编辑；全界面 gaze 与真实摸头；稳定 EGL 生命周期/键盘尺寸；普通形态不扣 18；针对性测试和 APK。
- 桌宠缩小：报告只有 small 与当时命中区域，没有尺寸变化因果证据，按用户要求不改。
- 保护边界：菜菜原 renderer/三配件投影、衣装、PCM 口型、独立情绪保持；私有附件不上传；不改模型路由/游戏/人格；不合并 main、不发布正式 Release。
- 验收：实现、自动测试、APK、真机分开记录；必须实机观察大动作、触摸、键盘和切前后台，不能用静态检查代替。

## 1. 接班协议

1. 新窗口先读本文件顶部至 `END QUICK HANDOFF INDEX`，再读取当前任务对应的正式记录、`app/docs/DOCUMENTATION_MAP.md`、当前分支/版本、最近提交和直接涉及的源码/测试；旧问题按索引定点查正文、归档或 Git 历史。
2. 每次正式修改前在“当前任务”登记目标、证据、保护边界与验证；完成后回填实现、提交、CI/APK、真机状态和下一步。
3. 容量约束只用于保持顶部快速索引简洁；标记后的正式内容没有字节上限，不因文件增长强制删减或滚动。自然阶段边界、操作性能明显下降或需要不可变证据快照时才建立只读归档。
4. 已有冻结归档：
   - `app/docs/ledger/archive/AI_Companion_总账归档_截至_v0.41.74+218.md`：1,587,679 bytes；SHA-256 `602c712f0fb06e70c054c2d54fe0e280f312923864040a3a177ee8e7da67ed70`。
   - `app/docs/ledger/archive/AI_Companion_总账归档_截至_v0.41.84+228.md`：98,372 bytes；SHA-256 `47d053d842a73e3ff8107dabe867bd503e8a7e77daaecc2afb1867068faa952c`。它是压缩前当前总账的逐字节快照，包含 +219～+228 的完整诊断、设计、实现与 Actions 证据。

## 2. 永久产品与工程边界

- **主体性优先**：事实与安全 Gate 约束虚假完成、越权、凭据泄漏和不可逆损坏，但不把她训练成处处等待批准的被动工具。
- **模型/API 双通道**：内部判断、维护、工具规划与 Outcome 核验走 DeepSeek；双模型模式只在收齐整轮上下文和真实工具结果后调用一次独立的 OpenAI-compatible 第二通道形成可见回复。第二通道地址和模型可由用户配置，默认仍是原玩游 Gemini 地址与模型；非 Gemini 模型不得收到 Gemini 专属 `google.thinking_config`。MCP 网络请求不是模型调用。
- **Jev 决策层（修改模型路由前必看；持续观察）**：已有 OpenRouter `typesafe/jev-1.13` 的可选短判断入口，默认关闭；普通聊天互动/主动玩笑与沉浸房间模式/事件各用一次批量 Choice 判断。有效 Jev 答案选最高概率；气焰相关选项前两名差距不超过 0.10 时记中性，不加额外气焰，但小豆丁每完成一轮固定减 18（用户 2026-09-28 更正）。`confidence` 不是本地 0.55 门槛，低 confidence 的有效答案不重调 DeepSeek。仅 Jev 关闭、无 Key、传输/额度/超时或无效结构时保留原 DeepSeek 兜底；取消不重复调用，不将 Jev 结果当工具执行事实。**下次及以后每份存档和诊断报告都必须逐轮核对 Jev 原始选项概率、实际采用值、DeepSeek 兜底原因、气焰前后账与真实语义，记录误判、延迟及费用，直到用真机样本明确验证成功；未验证前不得标成完成。**本机导出诊断包含 Jev 的有界原始对话上下文，属用户私密数据，不上传公开仓。详见 +277 和 +260。
- **真实工具事实**：只有成功的真实 Outcome 能支持“已进入、已落子、已发送、已保存、已完成”。失败、blocked、no_result、超时或零调用不能由对白补写。
- **唯一循环所有权（未来功能开工前必查）**：每个会连续推进的能力必须只有一个 continuation owner，并在设计时写清 `execution_id`、唯一触发源、一次唤醒最多规划轮数/工具调用数/真实 mutation 数、终止条件、Stop、崩溃/主后台切换后的恢复规则。用户回合、后台 cadence、工具 Outcome、UI 轮询和平台 callback 可以提供事件，但不得各自继续同一 execution；`next_call / continuation / resume_after` 是权威事实，不是再启动一条循环的许可。Cedar 曾经让前台 Agent 循环、后台游戏循环和 Outcome 续接同时推进，造成重复调用、Token 暴涨、终局丢失与 Stop 不彻底；此事故模式是永久踩雷样本。
- **循环能力首版诊断（随功能一起交付）**：任何新的 MCP、工作区、视频、提醒、Live2D 长任务或其他可续接能力，第一版就必须以脱敏方式记录 `feature / execution_id / trigger_source / continuation_owner / phase / planning_rounds / tool_calls / committed_mutations / continuation_requested / terminal / preempt / late_write / usage_lane`。诊断不得保存 Prompt、Thought 私密正文、密钥、房间凭据或用户文件内容；没有这组证据，不允许靠继续加 retry/delay 猜修循环。
- **Cortico 低风险参考（未来功能设计索引）**：参考项目为 `https://github.com/Pal-AI-Lab/Cortico`。只吸收两个边界思想：一是外部环境通过“可观察事实 + 可执行工具”接入，World/事件事实不直接等于聊天、记忆或成功声明；二是把 `preempt / flush / debounce / piggyback` 当作按功能选择的投递语义词汇。当前项目不移植 Cortico 的中央 Event Stream、World 容器、完整队列/状态机或记忆连续性取舍，不推倒现有自主逻辑。新增能力逐项建立小型隔离适配层即可：输入只形成验证过的观察，执行只经现有 Agent/Outcome 真值链，是否进入对话、短期桥或长期记忆仍由本项目现有策略决定。
- **Cedar 信任优先**：实时 catalog、玩家指南、合法动作、`next_actor / next_call / revision / legal_actions / resume_after`、防沉迷和终局以服务端为权威；APK 不以本地猜测覆盖。
- **Cedar 盲玩隔离**：运行时只使用 Cedar 玩家接口、当前聊天、正常存档与玩家可见 Outcome；`playerSafeGuide` 不得泄露仓库、源码、隐藏状态、题库答案、攻略、剧透或外部网页。游玩链不暴露 `public_web.search`。
- **自然语义 Agent**：允许“陪我下五子棋”等自然表达触发模型自主发现；普通“看看”不是联网授权。Cedar 的账号级 `allow_self_reset` 服从网站设置。用户已决定暂不增加 Agent 确认弹窗，直到未来加入修改/破坏性能力再设计确认。
- **媒体 Agent**：她能发送的媒体必须同时具备自读能力、可执行工具、真实附件 Outcome、来源 provenance 与发送后第一人称历史；只在 UI 或 Prompt 声称不算完成。
- **隐私与发布**：Token、绑定码、私密房间正文、用户附件、诊断、备份、模型权重和参考音频不得进入公开 Git/Prompt/公开诊断。用户持续授权推送明确开发分支并运行常规 Actions/Draft APK；不含合并 `main`、正式 Release、删除分支/用户数据、改变仓库权限。
- **冻结范围**：旧 Sen 产品适配器继续冻结；+275 以菜菜测试项目的原生渲染实现单独接入 Live2D 自主待机，后续 Jev/语音/双形态需分批验证。+249 的 Decoder 零新语义防护继续保留；+250 将日常持续会话计时移为手动 TTS 专项对照，并实现双形态气焰值。普通回复表情包已真机重新出现，未发现概率数值漏洞时不强改。

## 3. 当前基线

| 项目 | 当前事实 |
|---|---|
| 仓库 | `catkiss62/ai-companion-build`；Flutter/Android 工程位于 `app/` |
| 功能基线 | `agent/v04184-agent-loop-autonomy-closure`，`v0.41.84+228 / schema 61 / Snapshot protocol 6` |
| 功能状态 | `CI PASSED / APK READY / TRUE DEVICE PENDING` |
| +228 远端 | head `29e87d016c8bd81f52f89f95191bd1a1a01a5b57`；tree `c4a112a56d8b634cf3a1a66636979a0833538b7d`；Actions `35440359036`；Artifact `10583263879`；APK SHA-256 `159e283173e49da2924d25b37ba7647893cdafdcc31b63f0e31b7c64e086849b` |
| 仓库维护基线 | `maintenance/repository-governance-20260919`；远端文档 head `123e272196e8ae93f3518157917d76f6af4f1784`；完整构建 head `fa99f32012fa1a0716b746d36b958a8e777ef9b8`；Actions `35446649873` 全绿；文档-only run `35447342921` 正确跳过 APK |
| 当前功能分支 | `agent/v04224-pet-opaque-fullframes`，从 +267 总账 head `224e832` 分出；构建候选 `v0.42.24+268` |
| +269 当前任务 | `agent/v04225-pet-full-clips-heat` 从 +268 head `27dc991` 分出，构建 head `b9f854e960bca401c861b769cda2576b79ef9d9c`。原始 ZIP 在 Draft Release `397377805`、asset `591363139`，SHA-256 `ad94e2aa8829ddb5b8f0640e383b29bbccfbb5a77d9a957559e34cff17aea489`。排除 move/drag/balance 后 96 段、23,013 帧；五段点击、三段睡眠仅预览、自主池不稀释走路、桌面不透明、特效随尺寸、预览布局及回复后整轮气焰结算已实现。Actions `36271743353` 全绿，APK 722,612,227 字节，SHA-256 `0830c3e6d36a9ac0d5b94628cf6fac9564e02d8d8d6d0b4ae784d7f8d2dd9453`，未发布 Draft Release `397385083`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`；真机视觉、透传触摸与性能未验。素材由固定 Draft asset 获取并校验，不逐帧上传对话。|
| +270 当前任务 | `agent/v04226-pet-opaque-ambient-preview` 从 +269 远端 `f57acba` 分出。用户真机发现同一段新动画在“实验动画”关闭后继续播放却立即变实，证据指向独立实验 WindowManager 绘制层。改为单窗口不透明播放，保留原触摸/基础动作；“新版动画”默认开，旧模式保持原逻辑，新模式移出旧的非基础待机、纳入三段睡眠与工作/思考短片待机（深度思考碎碎念若裁切不宜修则排除），聊天思考与说话仍用旧动作；校准入口移至播放器首位，两个 Activity 修复上下裁切。旧 APK Draft `<=+265` 由维护 Actions `36275881299` 删除 191 个，人工删除 3 个；保留两份无 APK 草稿及构建输入。构建 head `4b205aee8f8e27a50ee4a87f5f1060fbf1dc4b7d`；Actions `36276798640` 全绿，未发布 Draft `untagged-c838b8c01ac127dd5d71`，APK SHA-256 `8e8a0b3c2809bb53efa9bd9e53e3d058ec0126231a736213fe69d395623cb85b`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。|
| +271 当前任务 | 用户报告 +269 昨晚到今午无自主聊天。旧版 2026-09-27 16:03（中国时间）存档/诊断：最后主动消息 09-26 11:14；过去 24 小时 `autonomousBehaviors=0`；Active Brain=true、无传输锁、无当前阻塞生成/租约，后台错误累计 677、最近错误 `MissingPluginException(pendingStoppedReminders)`。`RecoveryOrchestrator.runOnce` 在自主心跳前调用日历提醒读取，后台 `BackgroundSystemBridge` 缺少该方法，导致整轮退出。+271 补齐后台日历读取/确认，并让提醒独立失败只记错误分类、不拖停自主心跳。分支 `agent/v04227-proactive-background-bridge`，构建 head `5860cd54238e77ec65e6b911decee71020ae5316`；Actions `36305352339` 全绿，APK SHA-256 `a2236878e9234570ee6e90f6e288cb25b4f9186653b2b09ef54a147f3b49e879`，未发布 Draft `untagged-fb80911e6438a3a7d7d3`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。|
| +274 当前任务 | `agent/v04230-game-resume-pet-collapse`：用户真机观察自主游戏断续；源码证实检查点到期先延期 8 分钟、再触发意愿竞争，使 `resume_game` 因时钟未到期被排除。改为先竞争、未选中再延期，保留每次一步、3 次变动/25 分钟检查点、投入度/疲劳竞争和防沉迷；新动画默认缩放 147%（旧 121% 仍作显示基准），工具活动正文出现后自动折叠。另根据 20:13 诊断修补 Cedar 动作清理失败时租约未释放，并澄清备份占用提示；街机厅首次错误随后正常游玩，无确证协议故障，不改玩法。素材管线不改。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`，详见末尾 +274。|
| +275 当前任务 | `agent/v04231-caicai-native-idle-pet-speech`：菜菜双模型原生渲染／自主待机与桌宠说话心跳。HEAD `968ca7c`，Actions `36329874552` 全绿，Artifact `10935547935`，Draft `397702273`；状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE FAILED（导入重试）`，详见末尾 +275。|
| +276 当前任务 | `agent/v04232-caicai-import-pet-touch`，候选 `v0.42.32+276`：导入后未渲染导致 pending 拦重试；新版 16:9 桌宠窗口使可操作范围过大。保留菜菜原生渲染及宽动画；修复二次导入事务并收紧桌宠手势到旧方形。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`，详见末尾 +276。|
| +277 当前任务／Jev 持续观察 | 用户真机反馈 +276 桌宠范围无变化、菜菜导入无反应、Live2D 令输入法卡顿；Jev 低 confidence 回退频繁且旧诊断无法审计。重新按 +222 旧方窗及菜菜实验室 `fb04512` 验证源码：恢复真实 152×152dp 中号窗口与旧坐标迁移；导入/渲染阶段及 IME 降载；Jev 用最高概率、近似平局不加气焰、小豆丁固定 -18（用户更正），导出完整 Jev/气焰账。`v0.42.33+277`，Actions `36342200023` 全绿、测试 Draft 已有；状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE FAILED（用户回归反馈，见 +278） / JEV ACCURACY PENDING`。每份后续诊断与存档都分析 Jev 准确度，直到真机明确成功。详见末尾 +277。|
| +278 当前任务 | `v0.42.34+278` / 同 `agent/v04232-caicai-import-pet-touch`。+277 用户已报告动画缩小、导入未显示、空模型开关卡输入法，不能沿用 TRUE DEVICE PENDING 掩盖失败。恢复批准的宽动画尺寸，系统输入区域独立；无模型不创建原生视图，渲染失败保留导入包，Hybrid Composition/焦点隔离；Live2D 独立设置与确认删除；Jev 稀疏动作/原装预设/小豆丁/PCM 口型。构建 head `cf69e61`，Actions `36348468407` 全绿，961 项 Flutter 测试，Draft `397797809`。`IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。Jev 持续观察，最高概率/近似平局中性/-18 不改；详见末尾 +278 和专项文档。|
| +279 真机回归 | 用户 `2026-09-28T00:57:57Z` 脱敏诊断：六次导入均有 `manifest_validated → import_staged`，最终 `available=false / pending=true / render=not_open`；桌宠 `overlayPetTouchRegion=unavailable:NoSuchFieldException`。+279 的绿色 CI 和 Draft 不能视为效果成功，状态改为 `TRUE DEVICE FAILED`。|
| +280 当前任务 | `agent/v04232-caicai-import-pet-touch`，`v0.42.36+280`。导入后正式目录模型/索引读回与恢复、明确错误；桌宠 112/152/200dp 真实触摸窗口与独立可信宽绘制层，移除失败的隐藏 insets；普通闲聊话题词不额外触发 Agent DeepSeek 规划。Actions `36370446031` 全绿，Draft APK 已就绪；用户后续复现层残影、尺寸回退和 Live2D 背景穿透，状态更正为 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE FAILED / JEV ACCURACY PENDING`；见末尾 +280。|
| +281 当前任务 | `agent/v04232-caicai-import-pet-touch` / `v0.42.37+281`：用户真机确认 +280 Live2D 导入成功，但聊天页透明背景显示上一次页面，桌宠变小，更多页出现两、三层持续增加的静止桌宠假图片且不接收触摸；+280 真机状态改为 `TRUE DEVICE FAILED`。固定旧待机正面原帧为小／中／大尺寸的唯一触摸 alpha 范围，动作变化不改范围；恢复原宽动画绘制比例，一个 WindowManager 桌宠窗口，失去系统 alpha mask 时禁用整窗触摸；移除反复重挂载，聊天页不可见时销毁 Live2D 原生 Surface。`IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`，Actions `36376305397` 全绿；详见末尾 +281。|
| 当前任务状态 | `+265～+267` 已有构建与真机反馈；`+268 IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`：不透明桌面播放、独立宽度与饱和度、24 fps 全帧与播放器时钟；`+269 IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`：96 段完整动作及整轮气焰结算，见末尾 +269。|
| +267 远端 | 功能 head `07142df2f01f15b5e4770fb6d17b48150770f422`；tree `aa16c6405f87967191dcb5b99662c53302983c52`；Actions `36232295089` 全绿；Artifact `10903136887`；APK SHA-256 `956812613c1fb00123e2ab2e6a3f5f3ccc1d320743c7bd6b866c4e0365b09ab2`；未发布 Draft Release `397169363` |
| +250 当前任务 | 本体／小豆丁形态共用成年角色、记忆与能力；同一形态状态驱动角色提示与静态立绘，虚拟弹额头／安抚改变气焰值后继续自然衰减，心形液面与锁定入口；常驻世界书定点柔化并仅迁移未编辑原文；两档 TTS 共用冻结的真实回复与分段，无声生成并复制专项脱敏报告 |
| +250 最终构建 | 功能 head `b5cd2d1070fb237bc72ab66b1867a75da9bbe6e8`；tree `4e0dbbd531aea408ab0face6d46a323f441c7eeb`；Actions `35943607609` 全绿；Artifact `10785922926`；APK SHA-256 `f148f2eb303017ad5f6f689628f230979c24ba16831fdc0181e58bc5e1d73a`；未发布 Draft Release `v0.42.6-dual-form-tts-comparison-test` |
| +249 当前任务 | `loopIndex=0` 时明确判定“零个新语义 token”，在 VITS 前拒绝本段；最后两次会话记录生成时 profile、冷/热状态、各阶段耗时、RTF、播放首帧、队列余量、迟到段、失败/停止与脱敏文本哈希 |
| +249 保护边界 | 不播放参考 prompt、不添加固定语音/固定台词/System TTS 兜底；失败段独立跳过，其他段继续；仅同一文本、音色、语言且分别为 `legacy_fixed_8` / `auto_affinity_v084` 才计算性能对比；schema 61 / Snapshot protocol 6 不变 |
| +249 远端 | head `fb7f77f85d882f99530ab829df9a82eaa604e559`；tree `28e4fbafb5adb2bfaa58aa9ab6e1b1256f0c4b99`；Actions `35900627244` 全绿；Artifact `10770090214`；APK SHA-256 `546dd718d447b0987bf47aaba08089fefb0badffbc076ba38e695fb3e05263c5`；未发布 Draft Release `untagged-3a02088d4968fd7ab603` |
| +248 远端 | 远端 head `33647c7bff15084d6fd3cbc7b817e9b0b216f75c`，tree `80f49d8e93bcfe2a03737a6b8610fbd94d10c255`；Actions `35878106718` 全绿；APK SHA-256 `04a588d2d4628ccaacd1b0b9aaf3759430b46ba33ad69715cb388098c178f0be`；未发布 Draft Release `untagged-2b371d8cd86b365121b0` |
| +248 当前任务 | TTS 默认关闭的“自动核亲和加速”开关；四个声学会话与 Chinese RoBERTa 同用 `AUTO_AFFINITY`。生成中展开全部工具活动，完成后以脱敏卡片绑定回复，中止后绑定中断标记 |
| +248 保护边界 | 保留现有分段首段预填充、串行生成与连续 AudioTrack；不移植测试档、动态分块、FTZ/DAZ、输入映射复用或 memory-pattern 实验；工具卡不保存/展示参数、搜索词、URL、结果正文、Prompt 或隐藏推理；schema 61 / Snapshot protocol 6 不变 |
| +247 当前任务 | `nativeToolDefinitionsFor` 在路由结果的可变边界先建立防御性 `Set` 副本；覆盖纯图片与原生表情包 `content=''`、`promptContent` 非空且 Cedar 已配置的回归，不改千问视觉、`sticker_index`、模型策略或最终回复内容 |
| +247 保护边界 | 只修共同崩溃点与回归门；不把表情包接入识图，不改变 Cedar 阶段选择、工具权限、schema 61、Snapshot protocol 6、人格、欲望、TTS 或 Live2D；不合并 `main`，不发布正式 Release |
| +247 远端 | 功能 head `8fabae5016a7d457b58a581a7a2b609bc0ab69c8`；tree `fc7ca8d84dadabf33dc1f151895f52c42b62ce72`；Actions `35855141996` 全绿；Artifact `10747841131`；APK SHA-256 `6a5d04b79fba46139b16bb185f955fb87431e1b30c4f75f89a09788054b89bab`；未发布 Draft Release `untagged-376e1bf8ac7aac97af25` |
| +246 当前任务 | 识别中的图片允许立即删除，迟到的千问结果不得复活消息或报错；`403 Free quota exhausted` 明确归类为额度耗尽；`please` 不再误命中 `lease`；普通备份冻结不再显示“她正在换设备”。表情包仍使用本地 `sticker_index`，不新增视觉调用或固定回复兜底 |
| +246 保护边界 | 不修改 Sen/Live2D、人格、欲望、Cedar、TTS、schema 61 或 Snapshot protocol 6；不合并 `main`，不发布正式 Release |
| +246 远端 | 功能 head `167a504f4974ef11566b8ac974ab9e7281f00fc0`；tree `2f8c733bb1c80f078bb5b71f88e7b2a3287e8448`；Actions `35843632708` 全绿；Artifact `10742996195`；APK SHA-256 `d4c609c0836427155b9f73a6cf629c45f6cff4d88f801be5b4def828839546c2`；未发布 Draft Release `untagged-d99196e0bf0a288629ac` |
| +245 当前任务 | 21:00～次日 09:00 所有主动来源共享最多一次成功投递；“我会玩游戏”不再误授权 Cedar，前台真实游玩与后台共用局次/疲劳/满足账本；千问视觉新增真实连接测试与鉴权分类；TTS 只保留参考音频不可逆声学签名，高置信回声直接拒绝播放且没有固定音频/台词兜底 |
| +245 保护边界 | 不修改独立 Sen 仓库或已回退 Live2D；不增加对话模型调用；表情包继续使用本地索引语义进入当前 user prompt；schema 61 / Snapshot protocol 6 不变；不合并 `main`，不发布正式 Release |
| +245 远端 | head `09a50bdf14cfc1f5850c4c055fcbeade1b9dedb2`；tree `0985f0961691bdce7e6d521d59a12137ea5a82ad`；Actions `35809712355` 全绿；Artifact `10729507323`；APK SHA-256 `4c6f92b38bb3affa12aa52ae18d2d36276400d706b3a570e154d75e453d08059`；未发布 Draft Release `394245028` |
| +244 远端 | head `c16955ad0a8eeb3945d95c8b42372859d6ab09b8`；Actions `35642646319` 全绿；Artifact `10659441135`；APK SHA-256 `e58122e12f1cc412ff29eccbf0575bb0ae73ba6b524419ea774ad2f5a3dc5684`；未发布 Draft Release `393217151` |
| +244 当前任务 | 以 +237 的共享文件为机械基线回退 Live2D，同时保留 +241/+242 自然回复修复；删除 Sen 服装、预设、动作、情绪、PlatformView、Cubism AAR/Framework/shader 与 TTS/视线/摸头接线；聊天快捷面板永久提供带确认的旧模型包清理按钮，只能删除 App 私有 `filesDir/sen-live2d` |
| +243 当前任务 | 启动只加载服装而不批量启用全部原生预设；只显示三套服装、脱与眼镜；20 种聊天情绪接入，脱/NSFW 使用 `romantic_shy`；原生待机、摸头/彩蛋和当前 PCM TTS 口型保留；人物与特效共用位置/缩放；Flutter 全局触点驱动视线；输入法只挪动聊天面板，不改变 Live2D 原生表面尺寸 |
| +242 当前任务 | 不允许任何本地固定台词以她的身份替代模型回复；用户轮不能被校验器吞成空回复，主动轮可不发送；Sen `main@336b93a` 只读，AI 内的 16 个 Sen 主运行时文件逐字节一致，唯一 Framework 差异只能是 Sen 原始 `cubism-java-no-mipmap.patch` |
| +240 真机结论 | `PlatformViewLink + AndroidViewSurface + initExpensiveAndroidView` 没有修复黑色剪影，反而使整个 Flutter 合成画面变黑；该方向已在 +242 回退。复核 Sen 构建流程后确认 +239 黑色剪影根因是移植时漏掉 `cubism-java-no-mipmap.patch` |
| +240 失败路线 | 仅保留历史证据；当前生产舞台不得出现 `PlatformViewLink`、`AndroidViewSurface`、`initExpensiveAndroidView` 或 `forced_hybrid_composition` |
| +240 远端 | 构建 head `bdae0d3897efe49c251c6d4a2ecfb4a035afa188`；tree `4ef513abf3cbcd20db61357ee5bf4172868474ac`；Actions `35526854350` 全绿；Artifact `10609559197`；APK SHA-256 `bfad10070630724920cb68815d174e8d230740cfa8489761abf9495e12baeea3` |
| +239 真机结论 | shader 缺失已修复：同一模型在 +239 进入 `created → model_load/ready`，未再出现 shader renderer error；但标准 `AndroidView` 合成后显示为黑色剪影，因此整体 Live2D 呈现继续由 +240 验收 |
| +239 远端 | 构建 head `6223c66a09850f950b9646990459133ea8661d32`；tree `f9dd8e3ea303e92bf0862bce03a2384b542fb109`；Actions `35523577868` 全绿；Artifact `10608368899`；APK SHA-256 `897e5163b31fd8950f1e6c97c03f3e20d4d82c7d804aed1a9cf5c6172bee7287` |
| +238 当前任务 | 原样保留 Sen 已真机验证的 21 情绪、自主待机、视线跟随、摸头彩蛋、物理、三套衣服+脱与眼镜；与静态立绘互斥，接入现有情绪效果/音效、用户消息倾听反应和 TTS 波形口型；不改悬浮鲸鱼、人格/欲望真值或模型调用次数 |
| +238 远端 | 构建 head `eba2c185507743f1a50f5758e722f1d8a57b0bbd`；tree `7c0cb89a0de3a03f8d0862c570bffe3615d9fb77`；Actions `35521027339` 全绿；Artifact `10608496160`；APK SHA-256 `1b2376eb57fd8250fb5d8370ef7a1a03fb28e30e0176da059fdc71576e60d67c` |
| +237 当前任务 | 将未完成游戏事项、旧 ASSISTANT 场景与真实 Cedar 游玩状态分开：没有当前成功 Outcome 时只能说“还没玩/想去玩/之前玩过”，不得虚构正在钓、等待咬钩或图鉴刚才没涨；兼容纠正 +236 前已持久化为 attachment 的游戏 thread Thought |
| +237 远端 | 构建 head `0caa9382a472b53f574302064b387b527efae6df`；tree `70cf7225714f0514a7ee385f01cf1e3a499b4acf`；Actions `35509919804` 全绿；Artifact `10605181041`；APK SHA-256 `294b341ddc8354389717566aa83a7ed10bba6891f107f7df34f3bfd76c653cc2` |
| +236 当前任务 | 吸收欲望系统 2.0 的可验证因果账本与竞争诊断，不引入女性向保护欲或第二套欲望真值；把游戏“上瘾”改为可被心境、新兴趣与饱和打断、冷却后可重新点燃的短时投入；过滤 `not_due` 空候选、统一游戏语义域并区分游玩与分享 |
| +236 远端 | 构建 head `8ab3beb8997cb146a8499d00acfdf726e2121a2f`；tree `910c3950d354734adca82c58b5db8559fbbcb861`；Actions `35506384676` 全绿；Artifact `10604605761`；APK SHA-256 `b2aad7f827c64e82e58cd88d71db6690c721941d684abe40c80eee537d52bf22` |
| +235 当前任务 | 保留现有昼夜身体疲劳与连续 `rest_need`，新增有界、短时的正向激活与负面难安静调制；自主主动消息和 Cedar 真实推进在高疲劳时积累睡眠债，经过真实安静窗才回补；用户主动聊天始终正常回应，不新增循环、不改 schema、人格、世界书、最终回复通道或 TTS |
| +235 远端 | 构建 head `8ecbcbcaab339fc4ecd0b9c616db2ceacdc83d16`；tree `ee125bd9967b277975decec70b551ba1c7e7918b`；Actions `35501928714` 全绿；Artifact `10602523875`；APK SHA-256 `1489ba5a886d3323f1b68ca913a8f5d166f68133d7786974c04c514abf10e628` |
| +234 当前任务 | Cedar 五槽事实、已有/turn 0 存档续玩、已知空槽自主开档与破坏性覆盖确认边界；将固定玩游 Gemini 选项改为“`双模型（自定义最终回复）`”，地址/模型可编辑并以旧值预填；不改 schema、人格、疲劳、TTS 或内部 DeepSeek 通道 |
| +234 远端 | 构建 head `16589fc8a88574f5a77f0731f8972e65fe990538`；tree `60060c335ba1b064c950ea97a5274bd5fa06f7b5`；Actions `35498575549` 全绿；Artifact `10601008319`；APK SHA-256 `38aadaa9ffb1f2ac3ddac85fffc9311f4c9c75950692130b7c29eee3fa9210f3` |
| +233 当前任务 | 先修 Cedar Outcome Thought 的事件身份、一次分享与时间锚定；再做愿望单安全主题投影；最后只做语义等价的 DeepSeek 缓存观测/低风险优化。三部分独立提交与验证门，不改人格、疲劳、Cedar 玩法/循环所有权或 Gemini 按次回复链 |
| +233 远端 | 构建 head `2892e67d91652b3d8cdec6a989c8467ed0193764`；tree `36747406e22a5accd35f879d7284a0d3370e5a7c`；Actions `35475970152` 全绿；Artifact `10593264636`；APK SHA-256 `ffe58c0dc10f145ec4ce91489478b3b9327304aab8aa1b39a02f58b13229f6e3` |
| +232 目标 | 游戏厅“最近进展”窄面板复用“游戏活动”同款 Card 颜色；愿望单按安全主题表达并合并同主题活动愿望；登记 Cortico 低风险参考、唯一循环所有权与后续诊断护栏；不改 Agent 循环、疲劳、缓存、TTS、schema、世界书或人格 |
| +232 远端 | 构建 head `3783aa7ccae0d547d4a0a1c18d4f388c398be574`；tree `54da8912e76ce5d59ec142387f1708a972196640`；Actions `35469452065` 全绿；Artifact `10592781832`；APK SHA-256 `ccb0352275d197592b1fd5b9a1ca479f89ec21101f472b234e85f8f7d5968622` |
| +231 远端 | 构建 head `75d9e0a311d5b322f53a742b9016aac16d44c9d9`；tree `2b337e3b4d23a1c4bdc097ee999fc569ddafb7fe`；Actions `35464168272` 全绿；Artifact `10591085711`；APK SHA-256 `1b10c1f49f0d192913c2f15e9f46345160cc2c0ee22acf751eb6755a70a3e565` |
| +230 远端 | 构建 head `6c53a40b5d7413942c12ca84001bb66205c160d1`；tree `9c3674e87f37798964e293b1ffdeaedf4e582c74`；Actions `35458277355`（attempt 2 全绿）；Artifact `10589621373`；APK SHA-256 `de27ec0c0146ef3a879f0bb9d8ae2c06dbfdc3225d8f6694fe8e01c7c5ab8d4a` |
| +229 远端 | 构建 head `0f4ffc6c2b08a310a5f04919a045c98b2e8e63e3`；tree `9e0913202787feca13462c07fdd0941f10d0d4b9`；Actions `35450357850`；Artifact `10587305305`；APK SHA-256 `acbd5c81be69c5c27ae2822ea112fb2b0639a00636b61af7b0f642c02fbcddc6` |
| `main` | 仍为 v0.38.5 旧基线；不得作为 v0.41.x 起点，本批不合并 |

历史兼容与未来扩展索引：`v0.41.82+226` / `agent/v04182-cedar-state-machine-e2e`；`v0.41.83+227` / `agent/v04183-cedar-native-agent-loop`；`v0.41.81+225`；`模型自主发现`；`陪我下五子棋`。全工具调用动作展示已进入 +248；双人格与命运之轮的冻结分析见 6.21，均不得在本批顺手实现。任何新 MCP、工作区、视频理解、Live2D、提醒或长任务先查本文件的 **“唯一循环所有权”**、**“Cortico 低风险参考”** 与 **“循环能力首版诊断”**，不得再复制 Cedar 曾出现的多套循环。

+252 工作分支 agent/v04208-jev-game-result，候选 v0.42.8+252：OpenRouter Jev 两处短判断与 DeepSeek 兜底；保留 +251 气焰语义判断、TTS 和 Gemini 修复；Cedar get_result 不再凭旧结果生成新分享。余额面板延后；详情见 6.25。状态 IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。\n\n+253 工作分支 agent/v04209-tts-preflight-heat，候选 v0.42.9+253：快速自检只读取 APK 安装资源；TTS 子进程超时重置绑定并一键顺序无声对照；气焰 0～100 每轮 -10、满值五轮冷却退出，害羞本身不加分。前批 Jev/DeepSeek 兜底不变；详见 6.26。状态 IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。

+254 工作分支 agent/v04210-audio-heat，候选 v0.42.10+254：情绪音效改用媒体音量通道，硬件音量键控制媒体；轻微玩笑净降 6 点，互相挑衅需明确升级；Jev 回退诊断按题区分不确定与格式错误。紧急存档事件：+252 06:40 诊断仍有 422 条记忆、1 条会话、旧设备/谱系指纹，+253 08:44 诊断变为 0 条记忆、0 条会话、状态代数 0、新指纹，证明启动了新数据库；本份报告不含闪退栈，不能归因于 TTS 或声称旧库可恢复。06:39 外部 .aibackup 是已知恢复候选，恢复前保留原件且禁止卸载/清数据。状态 IMPLEMENTED LOCALLY / CI PENDING / TRUE DEVICE PENDING；详见 6.27。

+256 工作分支 `agent/v04212-form-pitch-zero`，候选 `v0.42.12+256`：气焰只在 0 自动退出小豆丁，严肃话题仍认真回应；设置音调是小豆丁基准，本体低 1 半音。沿用 +255 已真机恢复的单一试听和发声链，保留锁定与手动安抚。状态 IMPLEMENTATION IN PROGRESS / CI PENDING / APK PENDING / TRUE DEVICE PENDING；详见末尾 +256。

+283 当前任务：以 +282 远端为基线，依据 2026-09-28 存档与诊断收紧 Cedar 关键词误触发；Gemini 成功时由 Gemini 完成一次正文修正，DeepSeek 仅第二通道失败兜底；菜菜导入状态精简、十九情绪预览和 Jev 逐轮情绪判断。状态 IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING；详见末尾 +283 正式记录。用户私密存档、诊断及模型素材不得上传公开仓。

<!-- END QUICK HANDOFF INDEX -->

## 当前修复 · +296 保留直接合成恢复，把昼夜背景合入人物 Surface（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 2026-09-30 09:40 用户确认 +295 切出切回卡住→消失→重现已经解决；但人物背后默认黑色，进入“更多”或“她”再返回聊天时露出刚才页面。截图 `1000155919.jpg` 显示聊天文字/按钮与人物正常叠合、背后却是更多列表。**+295 恢复项单独 TRUE DEVICE PASSED，背景项 TRUE DEVICE FAILED，整版 PARTIAL。保留成功的直接 HC，不回退 Virtual Display。**
- 同版专用诊断 `live2d_diagnostics_2026-09-30T01-34-52.929576Z.json.txt`：`view_id=1 contexts=1 surfaces=18 frames=1811`，约 59.5 fps；09:34:21、32、44 的多次 Activity 恢复后仍 context=1，模型纹理仅解码/上传 7 张，原先约 2.7 秒重载不再出现。Surface 仍可因停止/显示变化重建，但 EGL 被保留，没有证明“Surface 永不销毁”。普通诊断同为 +295。本次只分析此问题，不改 Jev/Cedar。
- 读取 Android 15 [SurfaceView 官方源码](https://github.com/aosp-mirror/platform_frameworks_base/blob/android-15.0.0_r1/core/java/android/view/SurfaceView.java)：默认窗口下层的 `draw/dispatchDraw` 用 `clearSurfaceViewPort` 清空其后的窗口 Canvas，`gatherTransparentRegion` 声明透明区域；Flutter HC 背景 `FlutterImageView` 是同窗口的 Canvas 图像，旧 FlutterSurfaceView 的冻结帧在更下层。此源码机制与黑底/上页透出一致；不把旧页误认成正在绘制的聊天背景。简单媒体 Z 层仍在窗口下，`setZOrderOnTop(true)` 又会挡住 Flutter 聊天覆盖层，故不采用这两条。
- 修复：保留 +295 `PlatformViewLink/initExpensiveAndroidView/GLSurfaceView`。仅为伴侣宿主增加 `CaicaiStageBackground`，将原有公共 day/night WebP 以不透明 GL 四边形绘入与人物相同的 Surface，然后绘制原有 Cubism 人物；Flutter 保留聊天覆盖层、普通立绘与无模型状态的背景。从 Dart 同步现有昼夜选择，原生只接受这两个公共素材路径；居中 cover 及稳定 sceneHeight/顶部 IME 裁剪与 Flutter 原布局一致。纹理按资产变化或真正 EGL 换代加载，Surface 改尺寸/恢复不重解码；缺图记录背景错误且填充不透明深色，避免旧缓冲透出。诊断 state/frame 添加背景资产/加载与上传次数，不包含用户图片或私有模型。
- 验证：新 Android ES2 pbuffer 像素烟测检查昼夜颜色/上下方向、alpha=255、IME 顶部裁剪不挤压、同资产多帧/resize 不重复加载、真正换 context 重建纹理，以及缺失图像不反复重试。原有 26 文件/配件算法经宿主标记剥离仍通过来源校验；新背景层独立于私有模型。版本 `0.42.52+296`，独立分支 `agent/v04252-caicai-surface-background`；构建结果另行回填。
- 构建：本地功能提交 `c88bc4e3284df94a7317af754867a1e0c14222a4`，远端同源码树 `0a1b2f3695c9eac4a32989cefe5ec2008b5c22a1`，tree `ad979f9d6f3d1a0cca34187313ad9165f9413177`。[Actions 36657791150](https://github.com/catkiss62/ai-companion-build/actions/runs/36657791150) `success`；原生模拟器日志确认新增两项背景像素测试与既有三项测试合计 5/5 完成、0 跳过、0 失败；130 项源码门、Kotlin、Flutter analyze/test、arm64 Release、资源和签名核验全绿，失败报告跳过。未合并 main。
- 未发布 Draft `399666814`：[+296 测试 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-6cc8871713cb98446307)，target=`0a1b2f3`，asset `599823261`，文件 `AI-Companion-v0.42.52-296-Caicai-Surface-Background-APK.apk`，726117130 字节，SHA-256 `2e8d26353b2705bdc2340a7bc8b9906139bebcde76db7b7d65d2be51b2bb2dce`；Artifact `11074270365`。CI monitor 与 release digest 一致；签名证书 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48` 与现有测试版本一致，可覆盖安装保留数据；`draft=true / published_at=null`，未正式发布。背景和综合真机效果仍 PENDING。
- 真机待验：开机直接进聊天可见正常昼夜背景；“聊天→更多→聊天”和“聊天→她→聊天”各三次无旧页残留；“≡→直接返回”和真正切 App 后返回仍无秒级空白；聊天文字、按钮、气焰条覆盖顺序正常；键盘开合人物和背景保持尺寸。+293 保留完整视觉回退基线，+295 保留恢复成功的源码与 Draft；若失败记录具体项，不能覆盖已确认的恢复成功事实。



## 当前实施 · v0.42.53+297 沉浸形态快照、独立情绪层与自主游戏投入（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 2026-09-30 用户批准开始七项方案，并明确情绪动画只是独立固定动画层，按现有情绪动画/语音开关播放，不改Live2D表情、动作、参数或效果。此最新要求覆盖方案3中任何可能涉及修改Live2D效果的表述。
- 基线+296及方案总账HEAD `034d643`，独立分支 `agent/v04253-room-freeze-game-session`；实施沉浸入口快照与房间气焰判断删除、普通突破语义、独立情绪层、持续游玩竞争与有限对话倾向、小型记住事项及原图圆形悬浮球。用户特别要求核对沉浸共用机制，保留普通聊天与已成功功能。开始时仅记录范围，尚无新CI/APK/真机证据。

- 实施已落地：沉浸控制器唯一全局读取仅在入口捕获qForm，不保留热度；send/regenerate/保留截断回复不再执行Playful用户/助手/突破判断或写回；房间提示、立绘与三语/手动TTS都用同一快照。普通100资格、首次满值、0退出、锁定与0.10平局边界未改，仅突破提示支持累计玩闹与强烈害羞。
- 情绪新增独立固定图案层与“情绪动画”开关；现有短音效仍由emotion_sound_enabled控制，沿用用户音量（默认0.15），没有改Live2D模型实现。历史ID初始化不播放，单条新回复至多一次，隐藏/关闭取消；悬浮球用原图圆形裁切，未改拖动、点击、贴边或未读徽标。
- 持续游玩是Desire竞争选中的独立action，统一归入play_game冷却/满足账本；一次授予30分钟有效投入，暂停/长时间进程挂起不计时，同日同游戏有效，进程重启或导入不自动恢复。沿用单Cedar执行器和围栏，服务器防沉迷、结束/等待人类、夜间与疲劳会终止；推进后普通主动聊天仍可竞争，不占每步主动槽。对话鼓励/暂停用现有Jev路由合批（失败沿用原DS路由），正式回复提交后才保存；最多±0.10、3小时半衰、12小时过期，重复仅刷新不叠加。
- 记住事项入口：本地记忆库右上角→记住事项，手动添加/编辑/删除，最多16项（事项24字、事实120字）。通用settings随备份保存；普通及主动相关话题参考，当前当天例外优先，不写Memory重要度、不产生Thought/提醒，不从角色扮演抽取，也不注入角色扮演。
- 新增Flutter行为回归覆盖房间TTS冻结/普通TTS仍随全局、30分钟与暂停/跨夜、疲劳/睡眠、鼓励幂等/衰减/撤回、日常事实持久化与情绪历史不重播；新增专项源门，旧版本白名单追加297且其余合同保留。本地Dart语法、YAML、专项门与关联源门已通过；完整资源/Flutter/Kotlin/APK由Actions核验，未宣称真机通过。CI监视路径为ci-monitor-v0345分支的.ci/v04253-monitor.txt。详设与前置分析已移到本总账正文，保留全部内容以控制快速索引体积。

- 构建完成：源码提交 `6524f3e60b4d42a013cb8d17ced04923b1d0debc`（之前的运行因后续修正推送被工作流正常取消，最终只认本提交），[Actions 36690963830](https://github.com/catkiss62/ai-companion-build/actions/runs/36690963830) success；131项完整源码门、原生生命周期/导入烟测、Kotlin、Flutter analyze、完整Flutter tests（含新8个行为用例）、arm64 Release APK资源/签名核验全部通过，失败报告 skipped。main 未合并。
- 未发布 Draft `399848801`：[+297 测试 APK 下载页](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-cc829aca051c852f5c40)，target=`6524f3e`；APK asset `600471102`，文件 `AI-Companion-v0.42.53-297-Room-Freeze-Game-Session-APK.apk`，726453574字节，SHA-256 `f20a04df72d434aa9890bf7ec549a529dcb467f4213de2ec0edea63648968a84`；Artifact `11086582753`。Release digest与成功CI monitor一致；签名证书 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48` 与现有测试版本一致，保留现有数据覆盖安装。draft=true，未正式发布。
- TRUE DEVICE PENDING：①进入房间后无气焰条/变身判断，普通聊天气焰不被房间轮次推进；设置/短暂后台返回不变形，真正退出再入捕获最新形态，手动/三语语音音调保持快照；Stop、重生、继续剧情和保留截断回复正常。②普通满值仍可等待，累计玩闹/强烈害羞判定更合理与否需实际上下文观测，未宣称新的Jev概率或准确率。③独立情绪动画/语音开关生效，新回复单次播放，历史/返回不重播，Live2D原有效果和背景/恢复正常。④Desire选择持续游玩后进度加快，同时其他主动聊天可发生；用户聊天先行，暂停不计时，夜间/疲劳/防沉迷与等待人类能结束资格；鼓励不叠加并衰减。⑤记住事项保存13点用餐等小事后相关事实正确、当天例外优先且不产生催促，重启/备份恢复保留，恢复不续临时游戏资格。⑥悬浮球图案、圆形、拖动、贴边、点击、未读及展开聊天正常。


## 设计记录 · 2026-09-30 七项待讨论（DESIGNED / DISCUSSION ONLY / NOT IMPLEMENTED）

- 用户本轮仅要求完整方案，防止下次遗漏或误改，不修改产品代码、不构建APK。七项：沉浸入口继承后固定形态、普通聊天变身语义、Live2D情绪表情/语音、约半小时持续游玩欲望竞争、对话对游戏态度的有限影响、低重要度的稳定事实记住事项、圆形悬浮球改用用户图案。
- 沉浸最新决定覆盖上一分析方向：移除房间里的气焰条和用户/助手气焰/变身判断，进入时只捕获当前状态并在该次房间使用期间固定；定点审计提示、TTS音调、重新生成、继续剧情、Stop、全局状态写入、UI刷新和共用Jev问题边界。不得删除普通聊天共用机制，离开不将房间快照写回全局。
- 方案1／沉浸快照：同次房间使用固定入口形态，取消页面全局形态轮询、气焰条与弹额头/安抚/锁定入口、用户及助手气焰分类、突破判断和PlayfulFormStore推进。提示词、立绘及TTS使用同一个房间快照；继续剧情、重新生成、保留截断回复、三语/手动回放都不得重新读全局形态来改变本次房间。普通聊天气焰/锁定/衰减与NSFW模式/事件/工具判断保持；共享Jev合批仅去掉房间不再需要的气焰问题，不能删除整个分类调用。离开不反写全局，真正退出后再次进入重新取快照；进入更多/设置或短暂切后台返回视为同次使用。原有沉浸阻止主动聊天/游戏分享的边界不变。
- 方案2／普通变身：保持100资格、首次到100不立刻判、近似平局等待、0才退出和手动锁定。给现有突破判断添加已满值及最近几轮双方玩闹/害羞的累积状态，将要求鲜明全新转折改为允许累积逗弄、使坏或特别害羞形成自然临界点；普通亲昵仍可等待。先不降低全局0.10概率差、不增加每轮DeepSeek。仅做语义与状态的小范围调整，不能自动宣称新概率/准确率；测试包含普通亲昵、持续挑逗、突然害羞、重复普通活动等对照。
- 方案3／Live2D情绪：当前CaicaiLive2DStage已接情绪接口，CaicaiChatMotion也有Jev计划；EmotionSoundService已有独立短音效通道，默认音量0.15。静态ChatPortraitStage自带情绪图案，Live2D路径未有相应独立图层；上一窗口声称落实的独立特效/70%没有当前远端提交证据。后续保留模型五官情绪及动作，补接已有情绪图案覆盖层，并核对同一回复情绪驱动脸部、图案、短音效；复用现有音效及音量开关，保留用户设置。按真实回复ID至多播放一次，历史重绘不重播，Stop/切页面停止；聊天情绪保持，手动4.5秒预览不改。此项针对普通聊天Live2D，沉浸Live2D不扩大改造。
- 方案4／持续游玩竞争：当前play_game及resume_game来自好奇/沉思、真实游戏念头、投入动量、心境、疲劳与饱和度；并非已有获选后约半小时连续投入的新候选。新增持续游玩候选与单步游玩在同一欲望竞争内互斥/合并，避免同一游戏占多个席位。获选后只记一次自主行为竞争结果，以现有唯一Cedar执行器继续真实工具动作，最多约30分钟有效投入；每一步不重新抢普通主动行为名额，也不强制每3次动作退出。保留较轻的单步游玩；长期会话不能无限续时或占满主动分享。期间用户聊天先处理、工具执行串行、疲劳/睡眠/Stop/官网限制/游戏终局/等待人类可提前暂停或结束；跨夜结束旧投入段，重新进入竞争，不把休息时间计为已游玩。后台分享仍入念头，事件有价值才参与原有发送竞争，不固定每步汇报。不动Jev游戏入口门槛，不增加普通闲聊DeepSeek规划。此为新方案，当前源码未实现。
- 方案5／对话游戏倾向：现有游戏投入算法主要从真实Outcome和心境取值，未查到针对“有空自主体验”的有时效授权偏好。拟在现有对话内部判断/合批中提取鼓励、暂缓/停止及目标游戏，仅对游戏候选加有限偏置，不改永久欲望，不自动执行模糊许可。建议上限+0.10，约3小时减半、12小时归零；同主题连续肯定只刷新时效、不叠加，否定撤销。明确当下游戏指令仍走原按需Agent入口；夜间/疲劳/用户忙碌/官网限制不因偏置绕过。诊断记录来源类别、衰减后值和实际候选分数，不公开原对话。
- 方案6／记住事项（可选小范围）：建议设置一个小型可编辑的明确用户事实栏，独立于重要度和主动挂念；手工添加/编辑/删除为首版可靠入口，明确“记住”可复用现有内部记忆更新，不从沉浸角色扮演或单日临时表达自动固化日常规律。保留适用范围、来源、更新时间、当日例外与后续明确修正；在普通回复/主动消息相关事实使用时稳定取用，明确事实优先于时间常识及冲突旧推断。此栏不加愿望/欲望分、不增加提醒、不反复主动提及。复用现有持久存储和备份边界，实施须覆盖备份恢复/更新删除；不整套重构记忆库、不设为下一APK的必需阻塞项。用户实际作息属于私密信息，此总账仅记方案不记录具体值。
- 方案7／圆形悬浮球图案：已查看用户原图。当前OverlayBubbleService.createBubble用TextView显示单字；拟改为圆形裁切的本地图像，保持原球尺寸、点击/拖动/贴边/展开、未读角标、权限和触摸命中；原图不AI重画、不拉伸，居中等比例显示，在圆形容器裁切外缘。仅替换球面内容，不修改桌宠与悬浮聊天正文，图像只按创建/资源变化解码，不每帧处理。当前仅查看附件，未将素材上传公开仓或创建图标资源。
- 实施与验证顺序建议：先保存当前成功基线；普通/沉浸状态与情绪/图标为第一组，游戏会话与对话倾向为第二组，记住事项为独立可选小组；可以内部拆提交，完成既定批次后统一构建。关键验收是沉浸不更新全局且提示/画面/语音形态一致、普通变身和Stop无回归；游戏30分钟/跨夜/中断不重复授权及不消耗逐步主动聊天名额；低重要度事实正确采用/当日例外/更新删除/备份；悬浮球点击拖动与角标不回归。源码核对不是实现/CI/真机证明；本次仅总账方案更新。

## 接班分析记录 · 2026-09-30 双形态判定、沉浸继承与连续游玩（ANALYZED / DISCUSSION ONLY / NO PRODUCT CHANGE）

- 因上一窗口界面持续显示正在处理，用户要求接续分析。仅读取当前顶部、开发分支最近5次提交、最新Actions摘要、上一窗口直接相关最近几轮及定点源码/最新诊断。基线 `0.42.52+296`，分支 `agent/v04252-caicai-surface-background`，接班HEAD `aeb7e49`；最新构建 `36657791150` success，不据此扩大真机验收。
- 最新明确设计：气焰100仍保持正常形态可以合理；双形态用于被逗、使坏或特别害羞时“绷不住”，并非要求频繁切换。需对照实际对话、Jev原概率和本地采用值判断是否过严，列最后几轮概率与差值指标名称，讨论仅调阈值能否优化。沉浸房间Live2D不改；双形态/气焰继承与半小时连续游玩亦先分析讨论。未获此次产品逻辑修改/新APK指令。
- 最新证据为 `AI_Companion_Backup_2026-09-30T04-47-24.aibackup` 与同刻普通诊断；仅私下读取所需轮次，不将有界原始对话、API配置或存档上传公开仓库。
- 已完成语义与数值对照：最新五轮气焰90→87→92→100→100→100，正常形态且未锁定；首次达到100那轮不判，随后两轮均实际请求 `playful_breakthrough`。末第二轮变身/等待=0.24/0.76、confidence=0.52、前两项差=0.52；最后一轮0.42/0.58、confidence=0.15、差=0.16，均 `used`、`close=false`、最终wait，无本地改判。互动判断最后一轮mutual=0.58，已接受为互相挑逗；自身活动strong，说明气焰入口与变身判断是两道不同语义判定。历史一个正常活动样本虽变身0.51/等待0.49、confidence0.03，但本地归wait；不能把每次中性规则都当成错误拦截。
- 指标澄清：Jev返回名为 `confidence`，依据概率分布集中程度，不能当作正确率或变身概率；官方定义 https://docs.typesafe.ai/confidence 。本地实际门槛是前两项概率差<=0.10，源码未设低confidence强制回退。最后两轮即使只降低0.10仍是wait，不能用此调整解决。五类互动中light/mutual接近时归ordinary也会压低已有双方玩闹的加分；最后一轮的实际语义已经符合逗弄，是否达到“绷不住”仍有主观空间，结论是偏严格的候选，不声称该轮必须变身。
- 待讨论小改方向（NOT IMPLEMENTED）：保留100资格、首达100至少留一轮、最高项/近似平局策略；把已满值及最近双方玩闹/害羞的累积状态提供给现有判断，说明连续升级也可构成情绪临界点，不强求鲜明全新转折。普通亲昵/闲聊仍可wait。先用普通亲昵与真实升级对照样本评估，再决定是否单独调整变身门槛；不全局降低Jev互动/Cedar门槛，不增加每轮DeepSeek规划。本轮仅查源码和存档，未发起付费模型重放，不声称新方案有验证结果。
- 沉浸继承事实：当前控制器的发送/重生成已经调用同一个 `PlayfulFormStore`、用户与助手轮判断及 `PlayfulBreakthroughJudge`；房间提示继承同一形态，页面读取同一状态并显示气焰条、形态立绘及锁定/互动。并非尚未接入，后续是共用规则微调与真机一致性验证；沉浸房间Live2D保持用户要求不改，未宣称全路径真机通过。
- 连续游玩事实：+274已修复检查点先推迟时钟而漏进续玩竞争的历史路线；当前仍在3次状态变化或25分钟开局经过时间设置检查点，再交普通欲望竞争。最新白房间先因night_sleep暂停；playScore≈0.806高于restScore≈0.637仍受夜间条件拦截，随后duration_limit检查点时仅1次状态变化。源码使用now-startedAt，会计入跨夜暂停，不能把这一样本称为有效游玩了25分钟。续玩竞争已实现，约30分钟持续投入尚未由此样本证明；有效游玩计时、休息后新段落及分段再竞争可列待讨论方案，仍不绕过官网防沉迷、不保证每次满30分钟。
- 远端与旧窗口边界：当前+296远端的情绪音效默认仍为0.15；检索到上一窗口声称已落实Live2D独立情绪特效与70%音量，但未在当前远端确认相应提交。若继续该项应先恢复旧窗口未推送差异或重新明确实现范围，不能把聊天声称等同于远端已实现。此次只更新本总账，不覆盖产品源码、不生成APK。后续入口为本节待讨论方向及+296顶部真机清单。



## 正式记录（无容量上限）

## 4. +228 已完成、只等待真机验收

- Agent 循环重大回归已收口：前台首次成功 mutation 后结束本轮，后台每 cadence 仅一次规划/一次真实推进；普通聊天不再被活跃游戏自动注入整套工具。DeepSeek usage/cache 已按 lane 记录，诊断查看 `modelUsage.byLane`。
- `CedarExecutableCall`、唯一房间 `rooms → full state → replan`、陈旧 session 水合、终局恰好一次 handoff、`recent_game_episode` 有界短期桥接已实现；不新增吞掉 preference/shared_experience 的顶层 game memory kind。
- 单人游戏进入疲劳/昼夜 Gate 与可衰减饱和仲裁；实时共玩承诺不参与竞争。没有伪造各游戏固定概率或硬每日配额。
- 自主网页能力注册、完整来源证据束、普通“看看”误路由、Stop 贯穿 search/extract/压缩/appraiser、FishArchive 有界换候选、自主相册来源已修复。
- 主动联系以真实普通消息后 10 分钟滑动静默窗推迟；不消费 Thought、分享候选或频率额度，不把新话题改写成 followup。
- `screen_on / screen_off / user_present` 已切分 screen session；长熄屏前活动只能作为低置信度短时历史，不能跨会话冒充持续使用。
- “调皮”收窄到真实逗弄/故意曲解/恶作剧/小挑战；音效在第一段可见正文提交时一次触发；刷新回复恢复跟随最新并锚底。
- 用户新版“性格光谱”已作为内置 preset，SHA-256 `fcc1074203b31cdf36466b39b3b6b08b5abd7497855155c31558177242dfe0fb`，仅保守迁移仍等于旧内置 hash 的记录；规则 05 已加入“每一段动作、神态之后都需要配一段对话。”。

真机必须继续验证：一次聊天不出现多次 Cedar mutation；后台每 cadence 至多一步；真人回合仍及时回应；终局只交付一次；普通“看看氧气瓶”不联网；明确网页查询能引用实际页面证据；Stop 无需杀后台；自主网页/相册恢复；熄屏一小时后不说成连续使用；主动新话题在静默 10 分钟后仍送达；刷新锚底；音效与正文同帧。

## 5. 当前任务：v0.41.85+229 Cedar 结构化远程媒体桥

历史实现分支：`agent/v04185-cedar-media-bridge`。

### 已登记证据

- 最新旅行备份中 `cedar_toy.play` 成功，文本 Outcome 内有多个真实 HTTPS `photo_url`，但事件为 `content_kinds=[text]`、`image_data/viewer_url` 为空，最终消息没有 `assistant_mcp_image`。下矿存在同类协议能力。
- `AgentToolRunner._cedarImageAttachments` 和 `CedarToyActivityStore.recordPlay` 只消费 MCP 标准 `type=image` Base64 block；嵌在结构化结果或 JSON 文本中的明确媒体字段只被当文字。
- 这是 APK 的缺失桥接，不是 Cedar 网络失败、模型忘记发图或游戏厅活动窗识别错误。

### 本批目标

1. 只从 Cedar 成功 Outcome 的协议明确媒体字段提取 HTTPS 图片候选，支持结构化 object/list 以及文本 block 中可安全解析的 JSON；不得扫描自然语言中的任意 URL。
2. 复用现有安全公开图片下载边界：HTTPS、重定向、MIME、字节签名、大小与超时保护；每步限制数量并去重。不得为附件触发 `public_web.search`。
3. 下载一次得到的不可变字节同时用于 `MessageAttachment` 与 Cedar activity/history，避免聊天图、活动窗图和模型所见内容不一致。
4. 任一候选失败只保留真实文本/失败分类，不得声称图片已发出；取消后不得迟到写回。标准 MCP Base64 image 行为不得回归。
5. 增加固定回归：旅行 `photo_url`、下矿等价字段、嵌套 JSON、任意正文 URL 拒绝、非 HTTPS 拒绝、重复/超量、下载成功/失败、附件提交、活动记录、Stop/迟到写入。

### 保护边界

- 不改 Cedar 玩法、回合策略、概率、房间身份、revision、棋步或防沉迷；不写死真机 URL/房间/附件文件名。
- 不扩大为通用网页抓图，不改变公共联网授权判断；不把远程 URL 长期当附件，必须先固化受检字节。
- 本批不处理桌宠、TTS、表情概率、`main` 合并、正式发布或历史清理。

### 验证与完成标准

- 修改前后运行当前总账门、+228 与新增 +229 专项门、全部 validator、`git diff --check`、Flutter Analyze/tests、Kotlin/JVM/Android tests、arm64 Release、签名与载荷检查。
- Actions 与 APK 完成后才可写 `CI PASSED / APK READY`；真机必须分别看到旅行/下矿成功附件和失败降级，才可写 `TRUE DEVICE PASSED`。

### 本地实现与验证（2026-09-19）

- 新增 `CedarOutcomeMediaBridge`：只解析成功 Outcome 的明确协议媒体字段与完整 JSON 文档；拒绝正文 URL 扫描、HTTP、重复项和超量项，最多固化 3 张远程图片、单次 Outcome 总附件最多 4 张。
- `AgentToolRunner` 在 Cedar execution fence 内完成安全下载、字节签名检查、附件固化、Stop 清理与 activity 引用写入；标准 MCP Base64 图片路径保留。单张远程图片失败只降级为真实文本 Outcome，不伪造“已发送”。
- `CedarGameEvent.imageReference` 与聊天附件共用同一个持久媒体引用；活动窗优先读取该引用，旧 `image_data` 仍兼容。
- 新增 `cedar_outcome_media_v04185_test.dart` 和 `validate_v04185_cedar_outcome_media.py`；验证清单已登记旅行、下矿、失败降级、Stop 和诊断证据。
- 本地已通过：109 项 validator manifest 检查、当前总账门、+228/+229 专项门、相关历史门、Python 语法检查、Workflow YAML 解析与 `git diff --check`。本机没有 Flutter/Dart SDK，完整 Analyze/tests/Android Release 必须由 GitHub Actions 判定；在 Actions 成功前保持 `CI PENDING`。

### Actions 与交付证据（2026-09-19）

- 首轮 Actions `35449949853` 在 Flutter analyze 发现新增测试文件末尾误留重复 `import`，构建按预期阻断；已删除该指令，并把“声明后不得再出现 import”加入 +229 专项门，没有绕过分析器。
- 修复后的 Actions `35450357850` 全绿：109 个源码门、Kotlin 桌宠/悬浮层测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/塔罗载荷、Artifact 与 Draft 上传均成功。
- 构建 head `0f4ffc6c2b08a310a5f04919a045c98b2e8e63e3`；tree `9e0913202787feca13462c07fdd0941f10d0d4b9`；Artifact `10587305305`，ZIP digest `16978dba71bc9b581b47f3e2be4113762819a636015fa7a8e417eaa37c3ec024`，大小 `538,036,212` bytes。
- Draft Release `392107130`；APK asset `574973863`，大小 `544,913,702` bytes，SHA-256 `acbd5c81be69c5c27ae2822ea112fb2b0639a00636b61af7b0f642c02fbcddc6`；稳定测试签名未变。
- 当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。仍需真机分别验证旅行与下矿返回真实图片时：聊天附件出现、活动窗显示同一内容、失败只保留文本、Stop 后不迟到补图。

## 6. 后续待办与观察项

### 6.1 2026-09-20 MCP 真机结果后的前置设计记录（已由 6.2 覆盖）

> 本节保留 +230 开工前的证据与设计推导；其中 `PENDING IMPLEMENTATION / PENDING INTEGRATION` 是当时状态，当前事实以 6.2 的已实现、Actions 与真机回填为准，不得再从本节重复开工。

- **MCP 当前结论**：用户已真机确认双弈五子棋完整打通，正常自然语言也能让 Agent 查看/调用 MCP；可把 MCP 主链视为基本完善。该结论证明双弈共玩与 Agent 执行链，不自动替代旅行/下矿远程图片桥的专项验收。
- **游戏兴趣轨迹冻结**：不增加每游戏固定概率、复杂好感/受挫轨迹或新的顶层“贪玩” Drive。模型可依据实时目录、指南、局面、结果和 Cedar Thought 自然形成临时偏向；花园与猫咪等内容较少的游戏可自然失去吸引力，但不伪造持久偏好。
- **游戏重新竞争方案已接受（DESIGNED / PENDING IMPLEMENTATION）**：单人游戏保留短活动惯性；每累计 3 次真正改变远端状态的成功 Outcome，或活动持续 25 分钟（先到者为准），到达一次 episode checkpoint。checkpoint 后把同一局作为可恢复的 `resume_game` 候选，重新与公开网页发现/分享、普通主动联系、休息和沉默走既有 Desire/Thought 仲裁；其他行为胜出时只暂停、不丢远端存档。实时共玩在合法轮到 companion 时继续履行回合承诺，但服务端防沉迷仍是权威硬边界。不得每一步随机换游戏，也不得把“近似并列采样”扩大成纯随机竞争。
- **相册边界**：相册候选处理当前在 Cedar 推进前运行，并非直接被游戏关闭；但游戏每轮成功后会跳过普通主动联网/聊天，可能让网页图片来源枯竭。恢复统一竞争后先观察来源是否恢复，不单独提高相册保存概率。
- **Cedar 防沉迷一手证据（OFFICIAL UI / PENDING INTEGRATION）**：官网设置实际按“连续游玩轮数”计数，不是按连续分钟计数；页面默认 30 轮提醒、50 轮锁定、锁定 30 分钟后自动重置，也允许网页手动重置，存档不受影响。账号开关 `allow_self_reset` 只代表允许小机自行重置，不代表 APK 应自动重置。
- **现有实现与缺口**：休闲模式本地步进间隔为 2 分钟，快速/观战为 5/10 秒；它与服务端轮数/锁定计数是两层机制，本身不冲突。项目已把平台 `rest / announcements / vote` 交给 Cedar 服务端最终授权，并明确 `rest` 只能用于真实防沉迷提醒/锁定；但尚未把提醒、锁定、剩余时间或重置结果解析成持久状态。现有 `recordPlatformAction` 在 session 仍可继续时会于成功 `rest` 后约 1 秒再次推进，不能直接作为最终防沉迷闭环。
- **防沉迷建议（DESIGNED / 等用户最终选择）**：服务端提醒应强制形成 episode checkpoint；服务端锁定时移除普通 `resume_game` 并把游戏 defer 到权威恢复时间。若网站真实返回 `allow_self_reset=true`，可额外生成带明显继续成本的 `self_reset_and_resume` 候选，与联网、主动联系和休息同场竞争；只有它真实胜出才调用一次 `rest`，随后开启新 episode 并恢复正常 2 分钟休闲节奏，禁止 1 秒续跑。没有真实提醒/锁定证据时不得主动猜测或调用 `rest`。
- **最新同刻备份/诊断证据**：`2026-09-20 00:43` 备份和诊断中没有任何 Cedar `rest` 防沉迷动作或自主重置事件；出现的钓鱼“重开新局”属于游戏存档重开，不能当作防沉迷重置。诊断仍显示曾有 `recentActionCount=24 / saturationPenalty=0.28 / playScore=0.8613 / restScore=0` 的继续游玩判定，支持“活动后只和休息竞争”的结构性根因。
- **TTS 音色小改（DECIDED / PENDING IMPLEMENTATION）**：只把“高兴”从“活泼”改为“可爱”；其余情绪映射不动。
- **TTS 参考语音问题（DIAGNOSTIC FIRST）**：用户已确认现象更像播放/复现 `jiuhu_bento_tools.wav`，不是模型随机串入日语。当前生产调用链没有 `playReferenceAsset` 调用者，临时输出也使用 UUID，不先猜测根修。下一批先扩展脱敏诊断：记录语言、voice key、reference case id、清理前后字符类别计数、有效音素数、首轮立即停止、语义 token 数/哈希、输出 PCM 时长/哈希及 `reference_echo_suspected`；不记录正文。四套参考语音 `jiuhu_bento_tools / jiuhu_dream_days / jiuhu_idle50 / jiuhu_devotion` 统一覆盖。拿到同一时刻诊断后再决定是否修复标点/空音素、立即停止强塞 token 0 或输出回声拦截。

### 6.2 v0.41.86+230 实施登记（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

历史实现分支：`agent/v04186-autonomy-tts-diagnostics`。

本批只实施用户已经确认的三组变更：

1. TTS 自动音色只把 `happy / 高兴` 从 `lively / 活泼` 改为 `cute / 可爱`；其他情绪、固定音色、情绪音效和声学模型不动。
2. TTS 只增强脱敏诊断，不在本批猜测根修或阻断输出：覆盖四套 reference case，记录 voice/reference id、输入与前端规范化后的字符类别计数、有效音素、Decoder 首轮停止、语义 token、输出 PCM 时长/哈希及基于退化推理证据的 `reference_echo_suspected`；仍不得写入正文或参考音频路径。
3. 单人 Cedar 活动增加持久 episode checkpoint：每 3 个成功且真正改变远端状态的 Outcome，或 25 分钟先到者触发。checkpoint 只暂停本地续步，不结束、不换局、不损坏远端存档；`resume_game` 回到现有 Desire/Thought 统一选择，与网页发现/分享、主动联系、休息和沉默竞争。实时共玩承诺保持原优先级。

防沉迷实现边界：只解析服务端明确的结构化提醒/锁定/恢复时间/`allow_self_reset`，以及明确包含“防沉迷”的文本提示；普通游戏冷却或失败不得误判。提醒强制 checkpoint；锁定期间移除普通恢复候选。仅当真实证据同时表明提醒或锁定且 `allow_self_reset=true` 时，才提供带明显分数成本的 `self_reset_and_resume`；胜出后只调用一次平台 `rest`，成功后开启新 episode，并按当前休闲/观看节奏继续，禁止旧有成功后 1 秒续跑。没有证据不得调用 `rest`。

明确冻结：不增加“贪玩” Drive、不建立复杂游戏兴趣/受挫轨迹、不修改每游戏概率、不扩大 Agent 确认弹窗、不处理 TTS 声学根因、桌宠、`main` 合并或正式 Release。

完成门：新增纯策略回归与运行链回归；更新当前总账门、版本与测试清单；运行全部 validator、`git diff --check`、Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、签名与载荷检查。只有 Actions 全绿后才写 `CI PASSED / APK READY`；TTS 参考音频和单人 episode 仍需真机报告后才能升级为 `TRUE DEVICE PASSED`。

本地实现与验证：

- `happy` 已单独迁到 `cute`；`excited/surprised` 保持 `lively`。四 reference case 的脱敏 checkpoint/运行诊断已加入原始/规范化字符类别、有效音素、Decoder 次数/首轮停止、语义序列、PCM 时长/哈希和回声怀疑标记；没有增加输出拦截或声学猜修。
- 新增 `CedarSoloEpisodePolicy` 与 `CedarAntiAddictionParser`。episode 状态保存在 settings，不改 schema；只计成功的非只读、非平台、非退出远端动作。第三步或 25 分钟触发 checkpoint，`resume_game / self_reset_and_resume` 进入既有 selector；后者必须同时满足真实防沉迷信号与 `allow_self_reset=true`。普通游戏锁定文本有负例保护。
- `rest` 的后台执行增加本地证据门；成功后由原 1 秒改为当前 viewing pace（休闲默认 2 分钟）。恢复同局若本次真实推进失败，会恢复 checkpoint 并延后 8 分钟，不把失败当成已开启新 episode。实时共玩判定和回合优先级未改。
- 新增 Flutter 纯策略测试、Kotlin TTS 证据测试、+230 跨模块源码门，并更新 110 项 validation manifest、工作流、版本和真机清单。本地逐项运行 110 个源码门：107 个通过；另外 2 个只因仓库按治理规则未携带 CI 才恢复的桌宠/LingChat 私有资源包，1 个只因本机无 `kotlinc` 未运行。`git diff --check`、Python 编译、Workflow YAML 与 +230/+229/+228/总账专项门通过。本机无 Flutter/Dart/Gradle 分发，完整编译测试仍由 Actions 判定。

Actions 与交付证据：

- 构建 head `6c53a40b5d7413942c12ca84001bb66205c160d1`；tree `9c3674e87f37798964e293b1ffdeaedf4e582c74`。首轮 Actions 仅在恢复 LingChat 私有视觉资源时遇到远端 `curl (35) Connection reset by peer`，尚未进入编译；不改业务代码，按同一 run 重跑失败任务。
- Actions `35458277355` attempt 2 全绿：110 个源码门、Kotlin 桌宠/悬浮层与新增 TTS 证据测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/塔罗载荷、Artifact 与 Draft 上传均成功。
- Artifact `10589621373`，名称 `AI-Companion-v0.41.86-230-Autonomy-TTS-Diagnostics-APK`，大小 `538,050,951` bytes，ZIP digest `899a04d4819a6751c41b60a3ada9e62607bb2b7f30dc4969ec874adfac0ce25e`；APK SHA-256 `de27ec0c0146ef3a879f0bb9d8ae2c06dbfdc3225d8f6694fe8e01c7c5ab8d4a`；稳定测试签名 SHA-256 未变：`30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。
- Draft Release 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-4c16dc23432898cc5020`；本批未合并 `main`、未发布正式 Release。当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。

真机回填与非阻塞观察（2026-09-20）：

- 用户已确认“高兴”实际使用“可爱”音色，TTS 自动音色映射这一子项升级为 `TRUE DEVICE PASSED`；不代表参考音频疑似复现问题已经根修。
- 单人 episode checkpoint、游戏与联网/主动聊天/休息/沉默重新竞争，以及 Cedar 防沉迷提醒、锁定和自主重置，均转为低优先级“保留等待测试”。夜间不专门诱发游戏；以后上传自然使用形成的存档和同一时刻诊断时顺带核对，不阻塞下一开发任务。
- 旧总账的 Phase 3 状态保持原判：3A 已 `TRUE DEVICE PASSED`，3B 核心链已 `TRUE DEVICE PASSED / OBSERVING`；3C 的消费注入后来已撤出当前运行能力并暂停待重审，因此不把“Phase 3 重要链已通过”误写成“Phase 3 全部能力仍启用且全部通过”。

### 6.3 旧总账去重后的唯一后续任务清单（2026-09-20）

本节已对照当前源码、`DOCUMENTATION_MAP.md`、截至 +218 与 +228 两份冻结总账去重。旧章节中的“下一步 / PLANNED / PENDING”若已被后版完成、撤回或替代，不再自动复活；以后排期只从本节取。

#### A. 可直接进入开发的任务

| 优先级 | 任务 | 当前准确范围 |
|---|---|---|
| P1 | 设置“帮助”与真实能力清单 | `v0.41.87+231 TRUE DEVICE PASSED`：页面直接消费当前 `AgentToolRegistry`，并整理 `【检查系统】`、联网/网页阅读/图片、查手机、Cedar、Stop、备份恢复、TTS、权限隐私、故障排查与明确限制。用户确认入口与内容正常，且 UI 干净美观；其分节层级、图标、留白、克制的卡片色和可折叠说明作为未来全局 UI 美化的参考方向。 |
| P1 | 本地 Genie TTS 推理速度实验 | 当前生产基线是 CPU 8 线程，旧真机已证明 XNNPACK 会出现异常短音频、NNAPI 无收益。先在独立 `Genie-TTS-Android` 测试工程用同设备/同模型拆出前端、语义 Decoder、声码器、WAV 与冷/热启动瓶颈，并比较 4/6/8 线程、`PerformanceHintManager`/线程优先级、大核调度提示、session/张量缓存和分段预生成；只有证据稳定的引擎级方案再移植到伴侣项目做一次集成 A/B。最终必须是默认关闭的“快速推理”开关，关闭即回到当前路径，并具备温度、功耗、峰值内存、音频完整性、音质与自动回退门。普通 App 不承诺 root 级硬件超频，也不直接恢复已否证的 XNNPACK/NNAPI。 |
| P1 | 全工具调用动作展示 | `+248 IMPLEMENTED / CI PASSED`：工具活动生成中展开，终态按真实 Outcome 绑定并回看；`+257` 补齐可读实文的有界持久化与悬浮窗回看。实现已完成，不再列为开发待办；失败、Stop 与重启后展示仍待逐项真机验收。 |
| P2 | 通用 MCP Registry 与未来工作区 | Cedar 专用 MCP 已完成，但通用 `mcp.invoke` 仍为不可执行占位。未来按只读优先分批实现 Server 注册、能力目录、权限、审计、超时、取消、凭据隔离和可卸载；需要处理工作任务时再设计独立合理工作区。OAuth、社区工具与 stdio/Harness 不与陪伴数据库直接混用。 |
| P2 | 日历式提醒（DESIGN DISCUSSION） | 用户 2026-09-26 明确撤回相对时间语句自动判断方案，改为手写日历条目：只有日期的纪念日可在当天自然提起；日期+具体时间要有明显的到点强提醒，电话/闹钟式效果及其替代方案待讨论。`reminder.schedule` 继续不可执行，不以聊天约定冒充系统提醒；此前 +265 实验代码已撤回，无交付 APK。 |
| P2 | 记忆/人设/规则修改提案 | `memory.propose_change / personality.propose_change / rules.propose_change` 当前均不可执行。以后只先做可审查 diff 提案；写入、删除或其他可破坏操作必须增加确认、版本与回滚，当前只读 Agent 不增加多余确认。 |
| P3 | 视频理解 | `video_understanding.inspect` 仍为占位。以后独立评估短片抽帧、预算、临时文件隐私、取消和结果持久化；不冒充当前已能看视频。 |
| P3 | Live2D 反应接入 | 模型、动作和素材已在独立 Live2D 仓库完成；伴侣侧以后专门设计“LLM 语义反应 + 本地低延迟关键词/事件反射 + 动作仲裁/冷却/打断”，避免只等完整 LLM 回复才动，也不得让关键词层直接改写人格或对话。完成基础 P1 后再立专项版本。 |
| P3 | DeepSeek 缓存命中优化 | `v0.41.89+233 CI PASSED / APK READY / TRUE DEVICE PENDING`：已补齐细分 `usage_lane`、body-free 段落顺序/长度/哈希观测，并对工具 schema 做语义等价的确定性 key 排序；没有重排提示词、删记忆或冻结实时状态。后续只在真机积累足够样本后按 lane 对比 `recentPromptShapes` 与 hit/miss，再决定是否存在可证明、低风险的第二步 A/B；Gemini `final_reply` 仍不纳入。 |
| P3 | 疲劳与心境的小幅耦合 | 保留昼夜节律主基线，单独评估负面心情导致难入睡、兴奋/聊天愉快/玩嗨短时压住疲劳的有限偏移；必须有幅度上限、短时衰减、睡眠债回补和防止夜间无限续航。排在 +232 真机包之后，优先在北京时间 2026-09-21 下午至晚上、或后续相同自然时段开专项，便于观察从白天到夜间的真实曲线；不在 +232 顺手改公式。 |

#### B. Phase 3C 与 Phase 4 的准确含义和评估门

- **Phase 3C** 已由用户确认属于持续优化方向中的旧阶段编号，关闭独立待办。3A/3B、Thought、Share Seed、统一自主竞争及后续兴趣/分享调整已经承接它真正关心的“长期偏向会影响自主选择”；+210 的具体消费注入又已在 +211 撤回。因此以后不再以“重做 Phase 3C”排期，只在出现新的、可复现的兴趣连续性问题时按当前架构处理。
- **Phase 4** 是人格成长路线的可选末段，不是基础能力缺口：只在高影响歧义、连续反证或用户主动谈及时低频澄清一次；MBTI、契合度、AI 自拟小测试等只作为娱乐与低权重 `test_result / self_report / inference`，不得一次测试直接改写人格事实。开工前要先判断 Cedar 游戏、普通主动聊天和现有学习证据是否已经覆盖娱乐互动需求，以及澄清是否会让她变成问卷机器人。Phase 3C 没有必要恢复时，Phase 4 也可以作为独立可选功能评估，不再机械等待旧阶段编号。
- **情绪引擎扩建**不再是基础待办：最小 `Appraisal → Emotion Episode` 已在 v0.37.5 实现。只有自然证据持续证明缺少混合情绪、恢复轨迹或多事件调度，并且固定回放有量化收益时，才按 `EMOTION_ENGINE_EXPANSION_EVAL_v1.md` 增加一个模块；否则保持现状。

#### C. 保留等待测试（不阻塞开发）

| 项目 | 以后如何顺带确认 |
|---|---|
| +229 Cedar 远程图片桥 | 旅行/下矿自然返回图片时，核对聊天附件与活动窗是同一内容；失败只保留文本，Stop 后不迟到补图。 |
| +230 TTS 参考音频 | “高兴→可爱”已真机通过；仅当参考音频疑似复现时立即导出同一时刻诊断，用四 reference case 的新证据定位，不猜修。 |
| +230 游戏竞争与防沉迷 | 随以后存档/诊断核对 episode checkpoint、统一竞争、同局恢复、提醒/锁定、`allow_self_reset` 和自主重置；夜间不专门诱发。 |
| +228 自主性与屏幕时间线 | 继续自然观察 Token 账单、主动联网/相册、10 分钟静默窗、长熄屏、刷新锚底、表情/音效时序；出现异常才提交同刻证据。 |
| Phase 3A/3B 长尾 | 跨日期兴趣成熟/撤销/新鲜度，以及额度耗尽或能力关闭时的 capability defer 随自然数据观察；核心真机状态不倒退。 |
| Memory 2D 与 D6 媒体备份长尾 | 精确取消/自然主动回忆/工作话题占比，以及删除媒体后的备份、重复迁移、相册引用保护、缓存删除和跨机恢复，有自然样本再回填。 |
| 低概率显示/状态问题 | 表情发送占比、duel“轮到你”、偶发多余 `「`、TTS/桌宠异常均只在明确复现后窄修，不靠概率猜测。 |

#### D. 冻结、可选或需用户重新排期

| 状态 | 项目 | 决定 |
|---|---|---|
| `REMOVED FROM BACKLOG` | MiniMax 在线语音 | 用户确认当前本地小酒狐 Genie TTS 效果更好，MiniMax API、在线/本地双引擎选择、在线音色筛选与 emotion 映射全部从后续任务删除。冻结归档中的 MiniMax 只保留历史证据，不得再次自动排期。 |
| `FROZEN` | 当前屏幕像素观察与自主截图 | 现有 `screen_observation.inspect` 曾在视觉 Provider 前失败；先补系统截图 capability/阶段诊断才可重开。自主截图仍未实现，不因知道 App 名称而声称看见屏幕。 |
| `FROZEN` | HyperOS 文件选择器/系统导航键/悬浮间歇卡死 | 指三类旧真机原生问题：系统文件选择器偶发输入/返回挑战、系统导航键后悬浮层恢复异常、部分 App 切换时桌宠/悬浮层间歇消失或卡死。当前没有持续复现，项目末尾如重开，先取得输入挑战、动画心跳、window generation 与 enter/exit 时间线，不再叠加 retry/delay。 |
| `OPTIONAL` | 主动消息直接带表情、GitHub 灵感库、X/Telegram Provider | 都是新增能力，不是当前概率回归。只有用户再次选择才设计；普通回复表情、通用公开网页和现有媒体链继续保持。 |
| `OPTIONAL` | 手机主存储/平板伴随端、完整换肤、产品化发布 | 独立大型路线，不进入当前陪伴核心维护。平板伴随端先依赖未来视频理解/“陪玩或陪看”能力的正式定义，当前不预判具体方案；`main` 里程碑晋升与正式 Release 仍需用户明确授权。 |
| `MAINTENANCE` | 当前契约文档合并 | 可逐步把人格、Somatic、Inner Drive 重叠文档合并为当前契约；不改变 App、不阻塞功能开发。 |

#### E. 已完成、不得从旧总账重复开工

- Phase 0+1 审查、Phase 2A/2B、Phase 3A、Phase 3B 核心链；Memory 2D 主链、Dynamic Moe D2/D3、最小 Emotion Episode、查手机七日心情/购物车/侧栏、公开网页完整阅读与分享、Agent 自身系统读取、Agent v2、表情和双向图片、Cedar MCP/双弈/终局/连续循环、+228 Agent 循环与自主性收口、+229 远程媒体桥、+230 episode/防沉迷和 TTS 诊断均已有实现或明确状态。
- 角色扮演持续性由用户确认已解决：根因是旧输出模型理解能力与文本表现，切换 Gemini 为文本输出口后不再复现；从冻结任务删除，除非出现新的可复现证据不得重开。
- `PENDING / PLANNED` 只出现在冻结归档的历史段落时，不足以证明今天仍是任务；必须先与本节和当前源码核对。

### 6.4 v0.41.87+231 帮助页与游戏厅活动窗（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

历史实现分支：`agent/v04187-help-cedar-activity-ui`。

本批范围：

1. “全部设置”新增“帮助与真实能力”。普通聊天与自主工具清单直接读取运行时 `AgentToolRegistry` 的 `executable/userTurnAvailable/autonomousAvailable`，避免静态帮助把占位能力写成已可用；同时说明 `【检查系统】`、Stop/刷新、网页/图片/查手机、Cedar、本地 TTS、备份、权限隐私、故障取证和当前明确限制。
2. Cedar 活动窗“最近进展”改为居中 84% 宽度的窄卡片，左右保留外层滚动命中空间；文本仍可选择，最多 12 行的现有边界保持。
3. 活动记录继续显示三行摘要，但增加点击详情；详情可滚动查看完整 summary、动作、时间、图片和该事件 viewer URL，不执行游戏动作、不修改 session。
4. 不改变 Agent 权限/自然语言路由、Cedar 指南/循环/防沉迷/概率、数据库 schema、TTS 运行时、世界书、人格或 `main`。

本轮追加设计记录：Phase 4 继续作为可选人格澄清/娱乐测试，不因 AI 偶尔自然提问而强制开工；需要另查自然问题的用户资料写入证据链。TTS 快速模式先在独立 TTS 工程做引擎基准，再将证实有效的方案以默认关闭开关移植；Live2D 反应接入与疲劳—心境小幅耦合均登记为独立后续任务，不与 +231 混改。

Actions 与交付证据：

- 远端功能提交 `75d9e0a311d5b322f53a742b9016aac16d44c9d9`，tree `2b337e3b4d23a1c4bdc097ee999fc569ddafb7fe`；`main` 未修改。
- Actions `35464168272` 全绿：111 个源码/历史回归门、Kotlin 桌宠/悬浮层测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传均成功。
- Artifact `10591085711`，名称 `AI-Companion-v0.41.87-231-Help-Cedar-Activity-UI-APK`，大小 `538,056,010` bytes，ZIP digest `f64bbe778527f0a6ca3851394f6e398b2322f1cdba53af56d7ffc1050a3e012b`；APK `544,935,646` bytes，SHA-256 `1b10c1f49f0d192913c2f15e9f46345160cc2c0ee22acf751eb6755a70a3e565`。
- Draft Release 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-83ba209cc91853c32913`；仍是测试 APK，不是正式 Release。真机只需验收帮助页入口/内容、最近进展左右滑动命中区和活动记录详情。

真机回填：用户确认本批功能正常；帮助页入口和内容没有问题，排版被确认为干净美观。最近进展窄面板的左右拖动范围与活动记录详情均通过，唯一追加意见是窄面板颜色应与上方“游戏活动”Card 完全相同，该视觉收口进入 +232。

### 6.5 v0.41.88+232 愿望单主题身份、Cedar 同色卡片与扩展护栏（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PARTIAL`。

历史实现分支：`agent/v04188-wishlist-cedar-card-guardrails`。

本批范围与证据：

1. Cedar 活动窗保留“最近进展”居中 84% 宽度与左右外层拖动命中区，但面板从单独猜测的 `surfaceContainerHighest + border` 改为和“游戏活动”完全相同的 Material `Card`；不改文字、12 行边界、活动状态或游戏执行。
2. 愿望单固定句的根因已经定位：旧实现仅按 `drive_key` 返回一句固定正文，且活动愿望只按 `source_thought_id` 去重；同一钓鱼主题产生多个生命周期 Thought 时，会被当成多个不同愿望并重复显示“想认真找点没见过的新鲜东西看看”。
3. +232 以 `drive + canonical safe topic` 作为活动愿望身份，统一 `cedar_game:fishing` 与 `shared.activity.fishing` 等明确同主题别名；同主题的新 Thought 会接续并重绑定原愿望，不增加第二条。正文只从 drive、topic key 与 provenance 分类生成，明确禁止读取或呈现 Thought 私密正文。已完成历史只迁移展示版本，不伪造完成、不强制增加愿望数量；原有 6 小时新增冷却、每日预算、强度/复现/基线与满足条件保持。
4. 将 Cortico 参考地址与“观察事实/执行工具隔离、按功能选择投递语义”写入永久边界；同时将 Cedar 多循环事故提炼为“唯一循环所有权”和首版诊断要求。只增文档护栏，不引入中央 Event Bus、World 容器、完整队列/状态机，也不修改现有 Agent/Cedar 循环。
5. 明确不改：数据库 schema、世界书/用户已修改的性格光谱、人格、Desire/Thought 生成与满足逻辑、Agent 权限/自然语言路由、Cedar 玩法/防沉迷/竞争、TTS、疲劳公式、DeepSeek 缓存实现、`main` 或正式 Release。

真机验收只看三点：进展窄卡颜色是否与“游戏活动”一致；旧固定愿望在一次正常“查手机”刷新后是否迁移；同一钓鱼/旅行主题反复形成 Thought 时活动愿望是否只保留一条且正文能说明主题。不得为了造样本修改真实欲望或游戏偏好。

本地验证：+232 专项门、Workflow YAML、Python 编译与 `git diff --check` 通过；逐项运行 112 个源码/历史门，109 个通过。其余 3 个与本批代码无关：仓库按治理规则不携带 CI 才恢复的 417 文件桌宠源码包与 LingChat 特效包，本机也没有 `kotlinc`；Actions 会在恢复资源和安装工具后执行完整 Flutter analyze、Flutter tests、Kotlin 测试与 arm64 Release 构建。

Actions 与交付证据：

- 远端构建 head `3783aa7ccae0d547d4a0a1c18d4f388c398be574`，tree `54da8912e76ce5d59ec142387f1708a972196640`；`main` 未修改。首次分支创建 run `35469348788` 被随后用于确保 push 事件的同树 CI 提交按 `cancel-in-progress` 正常取消，不是编译失败；权威结果只取新 head。
- Actions `35469452065` 全绿：112 个源码/历史门、Kotlin 桌宠/悬浮层测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传全部成功。
- Artifact `10592781832`，名称 `AI-Companion-v0.41.88-232-Wishlist-Cedar-Card-Guardrails-APK`，大小 `538,061,525` bytes，ZIP digest `de6b7f2fd789d3d3e0d195ab7f6a6851fcb834aa783955bd8d33d3462b549aea`；APK SHA-256 `ccb0352275d197592b1fd5b9a1ca479f89ec21101f472b234e85f8f7d5968622`；稳定测试签名 SHA-256 未变：`30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。
- Draft Release 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-8043368def99d2e0f7b0`；仍是测试 APK，不是正式 Release。

真机回填与持续观察：

- 游戏厅“最近进展”卡片颜色已确认与“游戏活动”一致，升级为 `TRUE DEVICE PASSED`。
- 旧固定愿望在正常刷新后已确认写法发生迁移，升级为 `TRUE DEVICE PASSED`；其中未知主题仍可能落入“想认真弄明白最近惦记的那个问题”等过度模糊兜底，这属于 +233 的安全主题投影改进，不推翻迁移成功结论。
- 同一钓鱼/旅行主题长期只保留一条愿望仍随自然数据持续观察，不阻塞开发，不为造样本修改真实欲望或游戏偏好。

### 6.6 v0.41.89+233 Cedar 事件时序真实性、愿望安全主题与缓存命中（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

开工证据与边界：

1. 同一时刻备份 `AI_Companion_Backup_2026-09-19T22-01-12.aibackup` 与诊断 `ai_companion_diagnostics_2026-09-19T22-01-20-863164Z.txt` 证明：最新主动消息声称“刚在钓鱼里连甩了十竿”，本轮没有新的 `cedar_toy.play` Outcome；它复用了来源事件 `play-1789520410317668` 的旧钓鱼正文。对应 Thought 已跨同主题合并 1759 次、累计主动 action 37 次，原始事件时间与 `updated_at` 被维护/合并刷新的时间严重分离。
2. 根因是结构性的而非钓鱼词表单点：Thought consolidation 把所有相同 `cedar_game:<game>` 主题当重复项合并；合并保留旧事件来源/正文，却刷新 `updated_at`；主动出站又把任意 `mcp/cedar_game:*` 来源直接视为有 Cedar Outcome，未验证具体事件是否新鲜。高疲劳只改变竞争结果，不是伪造根因。
3. Cedar Outcome Thought 必须保留不可混合的事件身份：不同事件不得只因游戏主题相同而合并；同一真实 Outcome 最多主动分享一次；超过 48 小时的 Outcome 不再主动翻出分享，但仍可在用户对话、长期记忆和历史回忆中以“之前/上次”等形式出现。
4. “刚才/刚刚/刚在”等即时表达只由 60 分钟内的具体成功 Outcome 授权；维护、合并、复活或候选选择不得刷新证据时间。超过窗口仍可分享真实旧事，但必须使用历史时间锚。规则覆盖所有 Cedar 游戏动作，不写成钓鱼专属补丁。
5. 愿望单继续保护 Thought 私密正文。未知主题不得直接展示任意 topic key 或内部推理；只使用独立、受约束的安全公开主题。缺少安全主题时不再伪装成“那个问题”，也不为写详细而发明新目标或改变成长分数。
6. 缓存优化排在上述真实性修复之后。先补不含 Prompt 正文的段落类别、顺序、长度与哈希观测，再只调整稳定前缀、动态尾部和确定性序列化；Gemini `final_reply` 不纳入，禁止删记忆、冻结实时状态、弱化工具真值或重新合并已隔离的 Agent/Cedar 循环。

实施顺序与提交门：Cedar 时序真实性、愿望安全主题、DeepSeek 缓存分别独立提交并运行专项回归；最后才更新版本、总账与完整 validator。Actions 全绿只升级为 `CI PASSED / APK READY`，Cedar 历史时态、愿望显示与缓存行为仍需真机分别确认。

本地实现与验证：

- Cedar 事件身份已从可刷新的 `updated_at` 中剥离：优先从 `mcp/cedar_game:<game>:play|invite-<微秒时间戳>` 解析不可变发生时间，只在旧来源无法解析时退回 `born_at`。不同 Cedar 事件即使 topic 相同也不再 consolidation；已有 `action_count / last_acted_at` 的事件不可再次成为主动分享候选。主动分享只接受 48 小时内事件；“刚才/刚刚/刚在”等即时锚只接受 60 分钟内事件，维护、合并和候选选择均不能续期。旧事仍可在正常聊天中按“之前/上次”等历史方式回忆。
- 愿望展示升级为 presentation v3，并只投影受约束的 `safe_subject_key`。钓鱼、旅行、下矿、对弈、花园猫、韭菜、共同花园、纪念日以及少量 AI 自主性/身份/交流/爱好主题有具体公开文案；活动别名统一到同一 subject。未知 curiosity 主题不再生成新的公开愿望，旧愿望若已失去安全主题则诚实显示“旧记录没有保留具体主题”，不会读取 Thought 私密正文或编造目标；Thought 本身仍保留。
- DeepSeek 统计已把原先混在 `unclassified` 的日记、随笔、购物车、记忆整合、人格证据复核、摘要、翻译、亲密路由、沉浸房间与自我反思拆成独立 lane；Cedar 选游戏也从后台动作规划中拆为 `cedar_game_choice`。每次 provider usage 同步记录消息段的顺序、角色、字符数、12 位 SHA-256 与工具 schema 数量/长度/哈希，不记录 Prompt/响应正文、工具字段值或凭据；诊断只带最近 24 次 shape，便于下一轮按真实前缀变化 A/B。
- 本批缓存改动只对工具 schema 的 Map key 做递归确定性排序，字段、数组顺序、工具选择、消息内容与消息顺序保持不变；没有为了命中率重排系统指令、删记忆、冻结实时上下文或合并循环。两个语义完全相同但构造 key 顺序不同的 schema 已有固定回归证明会发出同一规范序列并得到同一 body-free hash。
- 三项 +233 专项门、+232/+228 回归门、115 项 validator manifest、Workflow YAML、Python 编译与 `git diff --check` 已通过；逐项运行 115 个源码门时 112 个通过，余下 3 个只因仓库按治理规则不携带 CI 才恢复的 417 文件桌宠源码包与 LingChat 特效包，以及本机没有 `kotlinc`。本机也没有 Flutter/Dart SDK，新增 Dart 回归、Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、签名与载荷检查仍必须由 Actions 判定；在此之前保持 `CI PENDING / TRUE DEVICE PENDING`。

真机验收边界：自然观察旧 Cedar 事件只以历史时态出现且同一 Outcome 不重复主动分享；愿望只显示安全具体主题或诚实旧记录说明；积累足够新 usage 后导出同刻诊断，对比各 lane 的 `recentPromptShapes` 与 provider cache hit/miss。缓存命中率允许受实时上下文影响波动，不能只凭一次样本判失败或继续扩大改动。

Actions 与交付证据：

- 远端四个功能/版本提交经 Git data 接口按本地顺序建立，最终内容树与本地候选逐字节一致；随后两个测试迁移提交修正 CI 暴露的回调类型和旧版本/未知主题样本。权威构建 head `2892e67d91652b3d8cdec6a989c8467ed0193764`，tree `36747406e22a5accd35f879d7284a0d3370e5a7c`；`main` 未修改。
- 首轮 Actions `35475149658` 在 Flutter analyze 精确发现新增测试把同步 `usage.add` 传给异步 usage callback；修复后第二轮 `35475536151` 的 analyze 已通过，869 项 Flutter 测试中 867 项通过，剩余 2 项只是系统自读仍期待 +232、普通基线愿望仍使用已被安全策略拒绝的未知主题 fixture。两项测试迁移没有放宽生产策略。
- Actions `35475970152` 全绿：115 个源码/历史门、Kotlin 桌宠/悬浮层测试、Flutter analyze、全部 869 项 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传全部成功。
- Artifact `10593264636`，名称 `AI-Companion-v0.41.89-233-Cedar-Temporal-Wishlist-Cache-APK`，大小 `538,070,382` bytes，ZIP digest `5055b7b8a30df4009b45fbda7f6f6fe8a259a3baf09d363afed25a8b70f61821`。
- Draft Release `392248211` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-a51ec6f40ce0543f3558`；APK asset `575682174`，大小 `544,947,802` bytes，SHA-256 `ffe58c0dc10f145ec4ce91489478b3b9327304aab8aa1b39a02f58b13229f6e3`。稳定测试签名仍为 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。

### 6.7 v0.41.90+234 Cedar 五槽自主性与可配置最终回复通道（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04190-cedar-save-slots-custom-final-model`。

根因与产品决定：

1. 最新同刻备份证明钓鱼 slot 1 与瓶中生态 slot 1 各自保存不同状态，Cedar 指南也明确写明“每游戏 5 槽，slot=1-5，缺省 1”；此前“覆盖鱼塘”并不是两个 game 共用同一存档，而是瓶中生态的 `eco_new` 命中了瓶中生态自己已有的 turn 0 slot 1。该初始档可能由官方人类前端/服务在只查看时建立；后续 `eco_observe` 与 `eco_act` 已证明它可直接继续。
2. APK 原先只把五槽说明埋在长指南正文，`cedar_toy.play` 的本地参数说明没有明确告知 Agent；后台也没有“空槽可自主使用、已有槽不可自主覆盖”的确定性边界。因此模型可能重复 `new`，却不能可靠表达槽位自主性。
3. 用户决定保持主体性：已有长期档默认继续；她确实想开新周目/新世界时可自主使用已知空槽，不必每次申请；只有覆盖已有槽、导入覆盖或 `confirm:true` 才必须取得用户明确同意。未知槽不能猜为空，room/session 类无五槽声明的游戏不受此规则影响。
4. 原“Gemini 3.7 Flash（玩游）”设置的地址与模型不仅在界面只读，运行时还会按固定网址把模型强制改回固定别名。只把控件变成输入框会形成假配置，必须让存储、普通聊天、沉浸房间、重试与连接测试都真正传递用户输入。

本地实现：

- 新增 `CedarSaveSlotPolicy`，只在实时指南明确声明五槽时生效：识别已有存档/覆盖提示，阻止后台 `confirm:true` 和冲突后的重复 new/create/start/reset/import；用户回合若没有明确的覆盖同意也会在调用远端前阻断。Agent Prompt 同时解释 game 间同号槽相互独立、turn 0 初始档可能由官方前端/服务建立、已有档优先观察/继续、已知空槽可自主开档。
- `cedar_toy.play` 的 `params_json` 说明补入 `slot=1..5` 与 `confirm:true` 边界；后台规划验收与执行前各有一层保护，避免模型重试或未来调用路径绕过。没有建立本地第二套存档服务器，也没有硬编码钓鱼/瓶中生态 game ID。
- 最终回复选项显示为“`双模型（自定义最终回复）`”。第二通道地址、模型 ID 改为可编辑输入框，默认读取旧玩游地址 `https://wy.aiwangyou.cc/v1/chat/completions` 和旧模型 `[特价]gemini-3.7-flash-0.5`；原 API Key 槽保持不变，升级不丢旧 Key。DeepSeek 仍是必填内部通道。
- `DeepSeekClient` 新增显式 provider/model override：自定义网址不再因为 host 变化被误判回 DeepSeek；用户输入的模型名原样进入请求。模型名含 Gemini 时保留原 `google.thinking_config`，其他 OpenAI-compatible 模型不发送 Gemini/DeepSeek 专属 thinking 字段。连接测试、普通聊天最终回复、沉浸房间首次生成和重试均使用同一配置。
- 新增 `cedar_save_slot_autonomy_v04190_test.dart` 与自定义第二通道请求回归，并登记 `validate_v04190_cedar_save_slots_custom_final_model.py`。版本提升为 `v0.41.90+234`，schema 保持 61。

本地验证：新增专项源码门、相关历史门、Workflow YAML 解析、Python 编译与 `git diff --check` 通过。完整 validator manifest 在仓库精简态运行到桌宠源码包门前均通过，随后按预期因 CI 才恢复的 417 文件桌宠源码包缺失而停止；本机没有 Flutter/Dart SDK，Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、签名与载荷检查必须由 GitHub Actions 判定。因此当前不得写 `CI PASSED / APK READY`。

真机验收：进入已有瓶中生态 turn 0 档时应观察/继续，不再把它说成钓鱼串档；已知空槽可由她自主选择，新建已有槽时必须询问且未确认前不发送 `confirm:true`。模型设置应显示旧值预填，可修改地址和模型并通过连接测试；普通聊天与沉浸房间都应使用新模型，第二通道失败仍由内部 DeepSeek 兜底。兼容性边界是 OpenAI Chat Completions 风格接口，不保证任意非兼容协议仅靠改名字即可使用。

Actions 与交付证据：

- 首轮 run `35498239554` 在 Android/Kotlin 测试触发 Flutter Debug 编译时准确发现 `_execute` 未接收新增 `origin` 参数；修复只补齐 `runPlan → _execute → _cedarPlay` 的既有来源传递，没有放宽覆盖授权。修正后的远端 head `16589fc8a88574f5a77f0731f8972e65fe990538`、tree `60060c335ba1b064c950ea97a5274bd5fa06f7b5` 与本地候选逐字节一致，`main` 未修改。
- 权威 Actions `35498575549` 全绿：116 个源码/历史门、Android/Kotlin 桌宠与悬浮层测试、Flutter analyze、874 项 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传均成功。
- Artifact `10601008319`，名称 `AI-Companion-v0.41.90-234-Cedar-Save-Slots-Custom-Final-Model-APK`，大小 `538,070,111` bytes，ZIP digest `980612367c76ef21a6dd4c06ba72057d296084fc8289bbd6e7a322fcf49cb901`。
- Draft Release `392355306` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-dde0b23c877ee349a101`；APK asset `576421689`，大小 `544,947,946` bytes，SHA-256 `38aadaa9ffb1f2ac3ddac85fffc9311f4c9c75950692130b7c29eee3fa9210f3`。稳定测试签名仍为 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。

### 6.8 v0.41.91+235 疲劳—心境小幅耦合与睡眠债（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04191-fatigue-affect-debt`。

开工证据与产品边界：

1. 同刻备份 `AI_Companion_Backup_2026-09-20T08-40-20.aibackup` 与诊断 `ai_companion_diagnostics_2026-09-20T08-40-24-240119Z.txt` 证明现有身体疲劳骨架正常：过去 24 小时疲劳最高约 `0.792`；单一连续 `rest_need` 于北京时间 02:08 建立、07:47 恢复；02:21 强依恋临时胜出一次并增加 `0.0825` 身体疲劳，02:27 自然结束互动，之后约五小时没有继续主动折腾。此次不重画昼夜曲线、不取消强念头偶尔顶困，也不把一次未复现当作所有长尾验收完成。
2. 心境不能直接改写身体是否疲劳。正向亲近、重逢、修复或正在投入的活动只短暂降低一小部分休息竞争与行动阻力；伤心、分歧、未被接住只形成“身体累、心里难安静”，会稍微降低入睡顺畅度，同时提高外向行动阻力，绝不能把负面情绪算成精神变好。
3. 高疲劳下的自主主动联系与 Cedar 真实写动作会积累独立、上限 `0.18` 的睡眠债；普通用户消息、AI 正常回复、只读 observe/state、失败或取消不增加债。睡眠债不直接伪造 Drive 数值，但会提高后续休息分数与行动阻力；即使白天身体疲劳已降低，未偿还的债仍可形成恢复压力。
4. 睡眠债只有在最后一条真实聊天或自主消耗之后连续安静 90 分钟才开始线性回补，约每小时 `0.025`；继续聊天会重新推迟回补，避免把普通回复误当睡眠。所有数值有确定上限、可跨进程恢复，不引入新的周期任务或第二套疲劳循环。
5. 用户主动聊天从不经过拒答 Gate；调制只影响自主候选排序、公开网页发现与 Cedar 继续游戏的统一 Desire 竞争。无人观看的凌晨 Cedar 07:00 前硬休息边界保持不变；真人正在观看仍是用户节奏例外，但真实推进会留下较小睡眠债。

本地实现：

- 新增纯策略 `FatigueAffectPolicy` 与薄持久层 `FatigueAffectController`。正向激活、负面难安静均只从现有证据化 Emotion Episode 计算；睡眠债以 `settings` 中的有界状态保存，schema 保持 61。策略没有模型调用、随机源、定时器或独立循环。
- `DesireCorePolicy` 的 rest score 与 action penalty 接受同一调制快照；现有身体疲劳值和昼夜 floor 不被减写。高债状态可以在白天继续形成恢复候选，直到真实安静窗逐步回补。
- 主动联系、公开网页发现和 Cedar continuation 共用同一快照。主动消息已送达或 Cedar 远端 mutation 已提交后，睡眠债写入失败不会把真实成功重判为失败，也不会重试远端动作。
- 情绪 Prompt 只注入结构化的“暂时激活 / 又累又难静 / 睡眠债恢复”表达边界；不暴露消息正文，不让模型声称心情已经消除身体困意。诊断新增 `affectMode / positiveActivation / negativeRestlessness / sleepDebt / 两类评分修正 / 最近自主消耗`，不包含 Thought 或消息正文。
- 新增 `fatigue_affect_debt_v04191_test.dart`，覆盖正向激活、负面难安静、睡眠债压过连续兴奋、90 分钟真实安静窗、白天回补压力、Cedar 共用仲裁与凌晨无人观看硬边界。

本地验证：新增 +235 专项门、当前总账门、相关历史门、Workflow YAML 解析与 `git diff --check` 均通过；逐项执行 117 个 validator，114 个通过。其余 3 个是仓库精简环境的既有缺项：CI 才恢复的 417 文件桌宠源码包、LingChat 特效资源包，以及本机未安装 `kotlinc`；不属于本次疲劳逻辑失败。当前环境也没有 Flutter/Dart SDK，因此当时保持 `CI PENDING / APK NOT READY`，完整结果现已由下方 GitHub Actions 补齐。

Actions 与交付证据：

- 首轮 Actions `35501454096` 已通过 117 个源代码门、Kotlin 与 Flutter analyze，在全量 Flutter tests 中准确拦住两条测试契约不同步：新用例寻找字面“又累”而真实策略文案为“身体已经累了”，旧系统自读用例仍写死 +234 构建号。只修正这两条精确断言并保留 +234 历史 token，没有改策略、跳过测试或放宽 Gate。
- 修正后的 Actions `35501928714` 全绿：117/117 源代码与历史门、Android/Kotlin 桌宠及悬浮层测试、Flutter analyze、881 项 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传均成功。构建 head `8ecbcbcaab339fc4ecd0b9c616db2ceacdc83d16`，tree `ee125bd9967b277975decec70b551ba1c7e7918b`；`main` 未修改。
- Artifact `10602523875`，名称 `AI-Companion-v0.41.91-235-Fatigue-Affect-Sleep-Debt-APK`，大小 `538,076,602` bytes，ZIP digest `5221f74cd5368748aae3af177b24041c5ddbbcd1189c2e93c089f348ea41dad4`。
- Draft Release `392375712` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-6bfa04031f233b81dfa6`；APK asset `576530601`，大小 `544,955,098` bytes，SHA-256 `1489ba5a886d3323f1b68ca913a8f5d166f68133d7786974c04c514abf10e628`。稳定测试签名仍为 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。

真机验收边界：北京时间下午到夜间自然使用即可，不诱发争吵或强行熬夜。重点核对：白天低债不改变正常主动性；聊天愉快时夜间可自然多撑一小会儿但不会声称恢复体力；负面心情表现为累且难静而非亢奋；高疲劳主动一次后下一次更难发生；停止互动并安静后第二天债逐步下降；用户主动发消息始终正常回复；无人观看 Cedar 凌晨不连续推进。当前保持 `TRUE DEVICE PENDING`，自然观察前不得写 `TRUE DEVICE PASSED`。

### 6.9 v0.41.92+236 欲望因果账本与动态游戏投入（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04192-desire-game-interest`。

开工证据与产品边界：

1. 最新同刻诊断 `v0.41.90+234` 与 schema 61 备份证明，最近约 79 分钟 26 个自主行为事件中 18 个是 `play_game|mcp|not_due`。根因不是“她太爱游戏”本身，而是 checkpoint 恢复候选在 continuation 尚未到期时仍参加竞争；它以最高约 `0.92` 胜出后才返回 `not_due`，占掉本次 heartbeat，其他真实候选没有再选择机会。
2. 游戏分享同时从 Cedar MCP Outcome、`self_drive/thread` 未完成事项与用户历史进入。钓鱼 thread 已累计 `fedCount=74 / actionCount=21`；现有 self-drive 把所有低于 `0.72` 的未完成 thread 一律归为 attachment，使游戏内容不当地借用依恋欲望。游戏 Outcome 分享强度最高 `0.94`，普通自我回顾通常仅 `0.18–0.46`，跨来源同主题没有统一语义域，导致“游戏总赢”既有真实投入也有结构性重复放大。
3. 本批允许阶段性玩游戏上瘾，但不新增永久“贪玩” Drive 或固定游戏人格。游戏投入只能由真实 Cedar 推进、近期显著事件、当前心境、疲劳与时间衰减派生，经历 `spark / flow / saturated / cooling / available`；心情不好、新兴趣、重复安静结果与饱和可以打断，冷却后允许重新点燃。
4. “想玩”与“想分享”必须分开：普通成功步骤只维持短时活动惯性，显著/有趣/终局/邀请或与用户相关的事件才形成强分享。Cedar、self-drive 与用户历史中的同一游戏主题统一进入同一有界语义冷却域，真实分享后压低同主题兄弟候选，不删除 Thought 或远端存档。
5. 吸收作者欲望系统 2.0 的部分限于：记录每个 drive/action lane 的最近真实满足、次数与来源；增加零使用/单一路径支配/无效胜出诊断；给长期未获机会但本身合格的动作一个很小的有界公平加成。不引入女性向保护欲、成功后永久抬高 baseline、固定 15% 随机探索或第二套欲望真值。
6. +235 疲劳核心、睡眠债、Emotion Episode、Thought 生命周期、Cedar 唯一 continuation owner、服务端防沉迷与存档槽边界保持不变；本批不改人格、世界书、TTS、双模型最终回复、schema 或 `main`。

计划验证：新增纯策略与集成回归，覆盖 continuation 未到期不入场、游戏阶段的投入/饱和/冷却/重燃、负面心境可打断、游戏 thread 归 curiosity、跨来源语义域、游玩与分享分 lane、真实满足账本兼容解析、无效胜出与支配诊断。随后运行全部 validator、Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、签名与载荷检查；只有 Actions 全绿后才写 `CI PASSED / APK READY`。

本地实现与验证：

- 新增纯 `GameEngagementPolicy`，只从当前 session 中成功且非只读的 Cedar Outcome 时间、显著事件和既有 fatigue-affect 快照派生 `spark / flow / saturated / cooling / available`。近期真实进展和显著事件形成短时 momentum；六小时内重复普通推进产生有界 saturation；90 分钟后进入 cooling，八小时后旧饱和清零并允许重燃；负面难安静最多形成 `-0.12` 的游戏调整，正向激活最多 `+0.04`。它没有持久人格值、随机源、模型调用、定时器或第二循环。
- `resumeOptions` 现在先读取权威 continuation delay；只有 `<= 0` 才能进入统一竞争。运行时竞态产生的 `not_due / no_continuation / waiting / action_in_progress / continuation_*` 统一记为 `wait` 而非虚假 completed。继续游戏基础常数和 Thought 权重已收窄，并叠加动态投入，因此真实上瘾可以持续，但饱和、心境、新兴趣与疲劳都能让其他候选胜出。
- `game_share` 成为独立 autonomous behavior，和 `play_game` 分开计数并有 90 分钟全局分享冷却；六小时同主题冷却覆盖 `game_share / proactive_message / public_web_share`。`cedar_game:<id>`、`shared.activity.<id>` 与 Cedar source 被规范为同一 `game:<id>` 语义域；发送后的 feedback 和行为 topic hash 均使用该域，跨来源不能靠换壳绕过。
- 新增 `SelfReviewDrivePolicy`：普通游戏/钓鱼/图鉴等未完成活动归 curiosity，不再借 attachment 压力；真正高重要度事项仍归 duty，其他关系 follow-up 保持 attachment。现有 completed source fingerprint 去重不变。
- 新增 settings-backed `DesireSatisfactionLedger`，按 drive 与 action lane 记录最近一次真实满足、次数和粗粒度来源；用户回复、成功主动消息与 Cedar 真实非只读 mutation 都能写入。它只给原始分数至少 `0.48`、超过 12/24/72 小时未获满足的合格 lane 最多 `0.02/0.04/0.06` 公平加成，不改 Drive、baseline 或事实 Gate。诊断显示 `zeroUseCoreLanes`，不带 Thought/消息正文、来源 ID 或凭据。
- autonomous behavior 诊断新增 24 小时 `nonproductiveWinnerCount` 和 `dominanceAlerts`：至少 8 次事件且单一 behavior/source 占比达到 60% 才提示，wait/blocked/failed 累计至少 4 次提示无效胜出；只做因果观察，不自动改人格。
- 新增 `desire_game_interest_v04192_test.dart` 与 +236 专项门，固定覆盖五阶段变化、负面心境打断、not-due 不入场、游戏 thread 归 curiosity、跨来源语义域、游玩/分享分 lane、满足账本 round-trip 与公平上限。118 个 validator 已逐项运行，115 个通过；其余 3 个仅因本地精简态缺少 CI 才恢复的 417 文件桌宠源码、LingChat effects 与 `kotlinc`。Workflow YAML、Python 编译、当前总账门、+235/+236 专项门和 `git diff --check` 均通过。本机没有 Flutter/Dart SDK，完整 analyze/tests/Android Release 仍由 Actions 判定。

真机验收边界：覆盖安装后自然观察即可，不需要刻意诱发坏心情。重点看诊断不再连续出现 `play_game|mcp|not_due`；同一游戏可短时沉浸但会因重复普通进展饱和，数小时后又可重燃；一次真实游戏分享后跨来源同主题不刷屏；游戏 thread 不再持续抬 attachment；+235 的疲劳、睡眠债和凌晨无人观看硬休息保持原样。当前不得写 `TRUE DEVICE PASSED`。

Actions 与交付证据：

- GitHub App 的 Git data 推送先建立源码提交，再修正一次超大文件/中文路径上传并快进同一分支；中间不完整提交触发的 run `35506336632` 不是候选。最终远端 head `8ab3beb8997cb146a8499d00acfdf726e2121a2f` 的 tree 为 `910c3950d354734adca82c58b5db8559fbbcb861`，与本地候选 tree 逐文件一致；`main` 未修改。
- 权威 Actions `35506384676` 全绿：118/118 源代码与历史门、Kotlin 桌宠/悬浮层测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传全部成功。
- Artifact `10604605761`，名称 `AI-Companion-v0.41.92-236-Desire-Game-Interest-APK`，大小 `538,087,109` bytes，ZIP digest `62771580ed5e535dbe7b6558d6a91225958aa3d7ee54badcdda22f7abad75178`。
- Draft Release `392401159` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-74af3e2b6759dcece079`；APK asset `576670347`，大小 `544,966,610` bytes，SHA-256 `b2aad7f827c64e82e58cd88d71db6690c721941d684abe40c80eee537d52bf22`。当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。

### 6.10 v0.41.93+237 游戏进行时事实接地（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04193-game-reality-grounding`。

同刻真机证据与根因：

1. 用户提供的 +236 备份与 19:21 脱敏诊断完整复现了问题。19:20 的主动 follow-up 写成“漂还是没动，图鉴也还是那几条老面孔”；但诊断的当前 Cedar `lastAction=eco_observe`、`continuationPending=false`、`lastContinuationState=not_due`，活动前台是 `eco` 而不是 `fishing`。备份中 fishing session 最后真实 Outcome 停在 2026-09-19 23:34，本条虚构进行时晚了约 19 小时 45 分。
2. 直接触发源是 `shared.activity.fishing` 未完成事项。它只记录“补满鱼饵后继续钓池塘”的计划，却被 self-drive Thought 累计到 `fedCount=75 / actionCount=22`；+236 新策略只保证新回顾归 curiosity，没有迁移已经持久化的旧 attachment Thought，所以旧项仍能以 `attachment:...` 胜出并生成 follow-up。
3. 现有 Operational guard 能挡“刚玩了一局/钓了几竿”等明确完成声明，却没有覆盖“鱼漂挂着、漂没动、坐回池塘、图鉴没涨”这类被包装成场景描写的可核验进行时；旧 ASSISTANT_HISTORY 又连续强化了同一虚构场景，普通回复随后顺势承认“甩出去挂着就行”。因此根因不是官方钓鱼游戏真的存在长轮询，而是项目把未完成意图当作运行态。

实现边界：

- `OperationalClaimGroundingGuard` 新增 Cedar live-state 判定。没有本轮成功 `cedar_toy.play` 时，拦截正在玩、坐在池塘/矿洞、挂着或盯着鱼漂、漂没动、鱼饵刚补齐、图鉴刚才没涨等声明；一小时内的持久化 Outcome 仍可支撑“刚玩过”的结果分享，但不能授权另一个游戏的当前进行时。钓鱼 `cast` 按一次调用一次结算理解，不制造后台鱼漂。
- “还没有实际去玩/准备下次玩”与“之前/上次/昨天玩时”明确放行；真实当前 Cedar Outcome 仍可自然第一人称分享。该边界约束事实，不禁止游戏兴趣、历史回忆或角色语气。
- 普通聊天 Reality Grounding 与 proactive 的游戏-thread 专项合同都明确：unfinished thread、Thought 和旧 assistant 场景只证明“惦记/计划”，不证明执行。首次候选仍失真时做一次事实纠正；再失败则沿用确定性删除/诚实未执行回退，不把虚假进行时写入聊天。
- 心跳会把来源为 `self_drive/thread` 且语义域明确属于游戏的旧 attachment 派生 Thought 原位纠正为 curiosity，只改派生 drive 标签，不动聊天、thread 正文或 Cedar 状态；`ProactiveSelectionPolicy.normalizeLegacyGameThreadIntent` 仍在竞争边界兜底，使修复写入失败或刚导入的旧数据也即时按 curiosity/check-in 处理，无需删用户数据、改 schema 或等待数日衰减。新 Thought 继续使用 +236 的 `SelfReviewDrivePolicy`。
- 不改 Cedar 协议、远端存档、游戏节奏、动态投入、疲劳、人格、世界书、TTS、双模型通道、schema 61 或 Snapshot protocol 6。

本地验证：新增 `game_reality_grounding_v04193_test.dart` 与 +237 源码门，覆盖本次真机原句、“挂着鱼漂等待”、诚实没玩/未来意图/历史锚、真实 Outcome 放行、旧 attachment game Thought 在选择时纠正为 curiosity。119 个 validator 已逐项运行，116 个通过；其余 3 个仍只是本地精简态缺少 CI 恢复的 417 文件桌宠源码、LingChat effects 与 `kotlinc`。当前环境无 Flutter/Dart SDK；Python 编译、专项门、Workflow YAML、历史版本兼容门与 `git diff --check` 均通过。

CI 与 APK 证据：首轮 Actions `35508754867` 正确拦截了“盯鱼漂”短句未覆盖及历史自读测试仍断言 +236 的两个失败；补齐后再收紧跨游戏证据边界，最终权威 Actions `35509919804` 全绿，119/119 源码与历史门、Kotlin 桌宠/悬浮层测试、Flutter analyze、898 个 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传全部成功。Artifact `10605181041` 名称 `AI-Companion-v0.41.93-237-Game-Reality-Grounding-APK`，大小 `538,089,843` bytes，ZIP digest `5aede1c3eac7f269ebac661322983c976d6d68ceee0e6e2711eaacf73bb1cd6e`。Draft Release `392416062` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-556fbc6ba9ca27a924ee`；APK asset `576771035`，大小 `544,970,010` bytes，SHA-256 `294b341ddc8354389717566aa83a7ed10bba6891f107f7df34f3bfd76c653cc2`。当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。

真机验收：覆盖安装后保留原数据，不需要删除旧 Thought。让钓鱼未完成事项自然再次竞争；没有真实 play 时只能说还没玩、又想起或想去玩，不能再出现鱼漂持续挂着、漂没动、刚补饵或图鉴刚才没涨。真实执行钓鱼后可以按 Outcome 分享；数小时后的旧结果必须用“之前/上次”等时间锚。诊断同时确认该旧 thread 的出站满足落在 curiosity/check-in，不再继续记为 attachment/reach_out。

### 6.11 v0.41.94+238 Sen Live2D 首阶段完整移植（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04194-sen-live2d-migration`，基于 +237 已完成 head `808c264`。Sen 来源锁定为用户自有仓库 `catkiss62/Sen-Live2D-Companion-Android` 的 `336b93af1d96e1dd85799faf3df966600c1224a7`，Cubism Java Framework 子模块锁定 `c2d420012d004b8e61d4c589bd5c34513122f0ea`。

开工边界：

1. 这是 Sen 源码移植，不是按观感重写动作。保留 Sen 已真机验证的 `SenPerformanceEngine`、`SenLive2DModel`、渲染、衣着、物理、21 情绪和摸头 10% 困惑彩蛋参数；新代码只负责安全导入、Flutter PlatformView、生命周期、状态互斥和现有聊天/TTS 桥接。
2. 首阶段直接开启 Sen 自主待机、视线跟随、摸头/摸头彩蛋，左侧快捷设置提供女仆、白衬衫、兔女郎、脱四个外观按钮与眼镜开关。Live2D 与静态立绘互斥：选择 Sen 时不实例化静态立绘，选择静态立绘时释放 Sen 渲染资源。系统悬浮宠仍保持 PNG/鲸鱼，本批不启动第二 Cubism 实例。
3. AI Companion 现有 `normal + 19` 正式情绪映射到 Sen 动作；`romantic_shy` 仅作为明确亲密/NSFW/“脱”的视觉演出，不新建情绪、记忆或欲望真值。原情绪特效与情绪音效保留；Live2D 特效锚定必须来自当前头部位置，不再固定于静态立绘坐标。
4. 用户消息发送后先本地进入短暂倾听/注意反应，既有 DeepSeek/回复情绪包给出权威语义情绪，不复制 SoulLink 的正则人格判定，不增加第二模型调用。本地 Genie TTS 按 AudioTrack 实际播放头位取 PCM RMS 驱动口型，不用写入进度冒充声音进度。
5. Sen 模型仍不进入公开 Git；用户通过系统文件选择器导入 ZIP 到 app-private 目录。导入必须保留 Zip Slip、容量/条目上限并采用 staging 后原子换代，失败不删现有可用模型。

计划验证：新增专项 validator 覆盖上述源码锁定、21 情绪、外观、互斥、导入安全、唯一 PlatformView 所有权和波形口型；运行 validator suite、Flutter analyze/tests、Android 编译与 arm64 Release。未经 Actions 全绿不写 `CI PASSED / APK READY`，未经真机不写 `TRUE DEVICE PASSED`。

本地实现与验证：

- 已直接纳入 105 个锁定 Cubism Framework Java 源文件、可再分发 Core AAR、Sen 已验证渲染/模型/动作/物理/外观源码与许可证。`SenPerformanceEngine.java` 与上游 SHA-256 同为 `492b6c12170b681e14ada78b0046dabd9644ed809001a0384676e4a430863218`，`SenOutfitPresets.java` 同为 `acdcb49cb91bb6d798086f31cec142db5cd5f44ec959f60717716ab1a09cc25a`；宿主扩展只添加确定性眼镜接口与动态头部锚点，未改 21 情绪/动作参数。
- `SenLive2DPlatformView` 与 Runtime 建立唯一聊天舞台所有者，Activity 对称转发 resume/pause，Flutter 条件渲染保证 Sen 与静态 `ChatPortraitStage` 不共存。Material 3 左侧栏已直接加入 Live2D 开关、四外观、眼镜与 ZIP 导入；旧快捷面板也保持同值入口。
- 模型导入使用系统 `ACTION_OPEN_DOCUMENT`，保留 8,000 entry/1.5GB/Zip Slip 门，在 staging 注册 expression 后换入 current；旧模型作为 backup 保留到新 renderer `onReady`，失败自动回滚并重载，进程中断也保留 pending 决议。模型和路径不入 Git/诊断。
- 现有 20 情绪包用纯映射进入 Sen，“脱”只投影 `romantic_shy` 视觉层；用户消息提交后本地播放 `small_nod`，不读正文也不增加 API。特效坐标每 66ms 取已校准的动态呆毛根网格点；TTS 每 33ms 按 AudioTrack 实际 playback head 取 256-frame PCM RMS，stop/cancel/release 强制闭嘴。
- 新增 `SEN_LIVE2D_INTEGRATION_v0.41.94.md`、纯映射 Flutter tests 与 +238 validator，总 validator 数为 120。本地逐项 117/120 通过；仅 3 个旧门因精简工作区缺 CI 才恢复的 417 个桌宠文件、LingChat effects 与 `kotlinc` 而失败。专项门、manifest check-only、Python 编译和 `git diff --check` 均通过；当前机无 Flutter/Dart/Android SDK，完整 analyze/tests/Release 交 Actions 判定。

Actions 与交付证据：

- GitHub App 以本地候选内容树建立远端构建 head `eba2c185507743f1a50f5758e722f1d8a57b0bbd`、tree `7c0cb89a0de3a03f8d0862c570bffe3615d9fb77`；分支仍为 `agent/v04194-sen-live2d-migration`，`main` 未修改。
- Actions `35521027339` 全绿：120/120 源代码与历史门、Android/Kotlin 桌宠及悬浮层测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、APK 内容校验、Artifact 与 Draft 上传均成功。
- Artifact `10608496160`，名称 `AI-Companion-v0.41.94-238-Sen-Live2D-Migration-APK`，大小 `538,330,407` bytes，ZIP digest `240d8c11ab5c230f4e7957bfb9f321115c6faa215b2a9cb860eab45aabf5fa16`。
- Draft Release `392488698` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-fae51abbecaf213a871f`；APK asset `577108762`，大小 `545,211,875` bytes，SHA-256 `1b2376eb57fd8250fb5d8370ef7a1a03fb28e30e0176da059fdc71576e60d67c`。当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。

真机验收：覆盖安装且不清数据，在左侧栏切换到 Sen Live2D，首次用系统文件选择器导入 Sen 模型 ZIP；确认导入成功后重启仍可加载，错误/超限/Zip Slip 包不替换旧模型。依次核对静态立绘与 Live2D 严格互斥、自主待机、视线跟随、摸头与 10% 困惑彩蛋、四种外观和眼镜、20 个正式情绪动作及跟头特效、用户消息后的倾听点头、TTS 播放时口型与 Stop 后闭嘴、前后台切换不黑屏不重复占有渲染器；系统悬浮鲸鱼应保持原样。真机完成前不得写 `TRUE DEVICE PASSED`。

### 6.12 v0.41.95+239 Sen Cubism shader assets 热修（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04195-sen-shader-assets`。

真机证据与根因：

1. +238 覆盖安装后，用户选择 Sen 模型 ZIP，界面明确报错“无法读取 Cubism 文件：`com/live2d/sdk/cubism/framework/shaders/standardES/VertShaderSrcCopy.vert`”。这证明 ZIP 已进入原生 renderer 初始化，失败对象是宿主 APK 的 Cubism 运行资源，不是用户模型结构。
2. 源码核对确认 +238 复制了 Cubism Core AAR、105 个 Framework Java 文件和 Sen 运行代码，但遗漏了 Framework Android 模块单独位于 `src/main/assets` 的完整 36 个 `standardES` shader 文件。Java 的 `CubismShaderAndroid.SHADER_BASE_PATH` 固定读取该路径；编译器不会检查运行时 assets 是否存在，所以 Actions 编译全绿仍可能在首次真机创建 OpenGL shader 时失败。

本地实现：

- 从 +238 已锁定的 Cubism Java Framework 提交 `c2d420012d004b8e61d4c589bd5c34513122f0ea` 原样补齐 36 个 shader，保留 `com/live2d/sdk/cubism/framework/shaders/standardES/` 相对层级。按文件 SHA-256 聚合摘要为 `2130c2079aaade0352f3abb2fde51f864a32b01466ea47ee3a9f8fe859b69250`；截图中缺失的 `VertShaderSrcCopy.vert` SHA-256 为 `d56e015be2348f1fd42cf7ccaef7bb869c5cd2095759d1ffc806dddca4339a74`。
- +238 来源门补入 shader 完整性，新增 +239 专项门锁定版本、上游字节、运行时查找路径与发布工作流。Release APK 校验不只看源码，而是打开最终 APK，要求 36 个路径完整并逐字节等于源资源。
- 版本提升为 `v0.41.95+239`，schema 仍为 61；模型 ZIP、安全导入与回滚、动作/情绪/外观、TTS 口型、聊天、人格、欲望、记忆、Cedar 和双模型调用结构均未改变。

本地验证：121 个 validator 已逐项运行，118 个通过；仅 3 个既有门因精简工作区缺少 CI 才恢复的 417 文件桌宠源码、LingChat effects 与 `kotlinc` 而失败。+238/+239 专项门、当前总账门、manifest check-only、Workflow YAML、Python 编译与 `git diff --check` 均通过。完整 Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、稳定签名和最终 APK shader 逐字节检查交由 Actions；只有全绿后才写 `CI PASSED / APK READY`。

真机验收：覆盖安装且不清数据，优先直接复用 app-private 中已导入的模型；若旧页面仍保留失败态，切回静态立绘再切回 Sen，或重新选择同一 ZIP。首先确认不再出现 `VertShaderSrcCopy.vert` 缺失且模型实际显示，再验待机、视线和摸头；之后继续 +238 完整清单。未经真机不得写 `TRUE DEVICE PASSED`。

Actions 与交付证据：

- 首轮 Actions `35523026248` 已通过 121/121 源码门、Kotlin 与 Flutter analyze，在 901 项 Flutter tests 中以 900/901 精确拦住 `agent_self_reader_v0416_test.dart` 仍写死 +238 的版本断言。只迁移该断言并将它加入 +239 专项门，没有改运行逻辑、shader 或放宽业务测试。
- 修正后的远端构建 head `6223c66a09850f950b9646990459133ea8661d32`、tree `f9dd8e3ea303e92bf0862bce03a2384b542fb109` 与本地候选内容树完全一致；`main` 未修改。
- Actions `35523577868` 全绿：121/121 源代码与历史门、Android/Kotlin 桌宠及悬浮层测试、Flutter analyze、901/901 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、36/36 Cubism shader 成品逐字节检查、Artifact 与 Draft 上传均成功。
- Artifact `10608368899`，名称 `AI-Companion-v0.41.95-239-Sen-Cubism-Shader-Hotfix-APK`，大小 `538,349,584` bytes，ZIP digest `ad9aa83acc07342cb576e83e06983e1a05e9c5b3e12d9383de687ad68338cdb3`。
- Draft Release `392499233` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-95c39cedd2fb3590b615`；APK asset `577186710`，大小 `545,238,814` bytes，SHA-256 `897e5163b31fd8950f1e6c97c03f3e20d4d82c7d804aed1a9cf5c6172bee7287`。当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。

### 6.13 v0.41.96+240 Sen 原生 Hybrid Composition 热修（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04196-sen-hybrid-composition`。

真机证据与根因：

1. 用户在 +239 重新打开 Sen 后提供截图和同刻脱敏诊断。旧 +238 实例的 4 次 `renderer error` 停留在 shader 缺失阶段；+239 新实例在约 6.9 秒后完整进入 `created → model_load/ready`，没有新的 Sen error。故 shader 资源、模型 Core、model3 与逐张贴图上传均已越过异常边界。
2. 截图显示完整人物网格轮廓和局部矩形，但所有颜色纹理为黑色；这不是模型未加载，而是绘制结果的颜色纹理没有通过宿主合成链正常呈现。设备为 Android 15 / Xiaomi `25060RK16C`。
3. Sen 原工程直接在 Android 原生视图树使用 `GLSurfaceView`；移植版却用 Flutter 标准 `AndroidView`，该入口优先把平台视图渲染成纹理再交给 Flutter/Impeller 合成。Flutter 官方文档把完整 `SurfaceView` 支持放在原生 Hybrid Composition 路径；这也是原工程与移植后唯一仍会改变 OpenGL 成品显示的结构差异。

实现边界：

- Flutter 舞台改为 `PlatformViewLink + AndroidViewSurface`，controller 明确使用 `PlatformViewsService.initExpensiveAndroidView`，强制 Android 原生 Hybrid Composition，不允许再次落入 TLHC/Virtual Display。
- 原 `SenCompanionView/GLSurfaceView`、Cubism renderer、纹理解码上传、动作/物理/外观和触摸参数保持；不以 Flutter Canvas 仿写。creation params 与脱敏 Native 事件新增 `composition_mode=forced_hybrid_composition`、`native_surface_view=true`，便于下一份报告确认真实路径。
- 36 个 shader 及最终 APK 哈希门继续保留。schema 仍为 61；不改用户模型 ZIP、聊天、人格、欲望、记忆、Cedar、TTS 或最终模型通道。

计划验证：新增 +240 专项门并将历史版本范围前移；运行完整 validator、Flutter analyze/tests、Android/Kotlin tests、arm64 Release、稳定签名和 APK 载荷检查。真机覆盖安装不清数据，确认模型颜色、透明背景、Flutter 前景覆盖和触摸/待机后，才允许写 `TRUE DEVICE PASSED`。

本地验证：122 个 validator 已逐项运行，119 个通过；仅 3 个既有门因精简工作区缺少 CI 才恢复的 417 文件桌宠源码、LingChat effects 与 `kotlinc` 而失败。+238/+239/+240 专项门、当前总账门、manifest check-only、Workflow YAML、Python 编译与 `git diff --check` 均通过；本机无 Flutter/Dart/Android SDK，完整编译与运行测试交由 Actions。

Actions 与交付证据：

- 初始本地状态曾为 `IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING`。首轮 Actions `35526483779` 在 Android/Kotlin 步骤执行 Flutter Debug 编译时，准确发现 `PlatformViewHitTestBehavior` 缺少显式 `flutter/rendering.dart` 导入；只补该导入，未更改合成方案或运行行为。
- 修正后的远端构建 head `bdae0d3897efe49c251c6d4a2ecfb4a035afa188`、tree `4ef513abf3cbcd20db61357ee5bf4172868474ac` 与本地候选内容树一致；`main` 未修改。
- Actions `35526854350` 全绿：122/122 源代码与历史门、Android/Kotlin 桌宠及悬浮层测试、Flutter analyze、901/901 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、36/36 Cubism shader 成品逐字节检查、Artifact 与 Draft 上传均成功。
- Artifact `10609559197`，名称 `AI-Companion-v0.41.96-240-Sen-Hybrid-Composition-Hotfix-APK`，大小 `538,348,212` bytes，ZIP digest `da89504183c8f1b2c1159b8f90fb8fc66de034dc9142ef9cb9b4fe960dd91d1b`。
- Draft Release `392517677` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-a5d654d0c78859a6de71`；APK asset `577282616`，大小 `545,236,534` bytes，SHA-256 `bfad10070630724920cb68815d174e8d230740cfa8489761abf9495e12baeea3`。当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`，黑色剪影是否消失仍必须由同一台 Android 15 真机确认。

### 6.14 v0.41.97+241 自然回复保活与固定兜底移除（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04197-no-canned-fallbacks`。

真机证据与根因：

1. 用户提供的 protocol 6 / schema 61 备份中，“睡着啦？”、“想起什么事？”、“啊？”三个不同用户轮后各自提交了一条新 assistant 消息，三条正文却完全相同，均为“我其实还没有去玩，只是又想起这件事了”。这排除了 UI 重复渲染或同一消息重复入库。
2. 同刻诊断第一次与第三次记录 `post_generation_changed_to_mismatch`，第二次未改写；源码确认 +237 游戏真实性修复在用户轮和主动轮各自硬编码同一句 Cedar 兜底。第一次固定句进入上下文后，模型会复述它，或再次被校验器替换，形成自维持循环。疲劳系统与 Live2D 都不是生成源。
3. 固定台词即使事实安全，也会删除用户真正问的问题并暴露机器感。用户轮不能用“不回复”替代它：用户已经发言时，回复活性优先于末端事实校验的绝对拦截。

实现边界：

- 删除普通聊天与主动消息提交路径里的三种本地人格兜底句。命中未接地操作或近四条中的精确重复时，普通聊天让当前模型重答一次，并把当前用户原文明确交给纠正提示。
- 已经写入数据库的旧固定句继续保留在聊天界面、备份和诊断中作为真实历史证据，但通过三个精确内容签名从后续普通/主动模型历史中排除，不再污染新生成；正常的“还没玩”、钓鱼回忆或不同措辞不会被过滤。
- 新增精确重复检测和用户回复保活选择：优先纠正后的非重复候选；若纠正反而重复，则回到原始非重复候选；如果两份都不完美，仍提交一份真实模型输出并记录 `grounded_reply_retry_degraded_pass`，绝不提交固定台词或空正文。
- 主动消息没有待回复用户，仍允许在一次纠正后 `WAIT`；若只剩无法接地的句子或精确重复，则不发送，而不是伪装成她说一句固定的“事实更正”。
- 审计四个 assistant 写入边界：普通聊天、主动聊天、沉浸房间、截断草稿确认。沉浸房间与截断确认写入的是模型流/用户明确确认的草稿；Gemini 失败切 DeepSeek 是模型提供方切换；界面错误提示不进入聊天、记忆或 TTS，均不属于人格固定回复。
- Live2D 本轮暂停，不把尚未在 Sen 原生工程真机验证的 `TextureView/SurfaceTexture` 载体混入 +241。

计划验证：专项静态门锁定“生产运行路径不得再出现三条已知固定人格句”、用户轮非空保活、主动轮阻止策略、版本与工作流；完整 Actions 运行 validator、Flutter analyze/tests、Android/Kotlin tests、arm64 Release、签名与 APK 载荷校验。真机覆盖安装后连续复测“睡着啦？→ 想起什么事？→ 啊？”以及未实际游玩的钓鱼话题，确认每轮均自然回应且不再复读固定句。

本地验证：123 个 validator 已逐项运行，120 个通过；仅 3 个既有门因精简工作区缺少 CI 才恢复的 417 文件桌宠源码、LingChat effects 与 `kotlinc` 而失败。+241 专项门、+237 游戏真实性门、回复/表情提交顺序门、Cedar 时间真实性门、当前总账门、Workflow YAML、Python 编译与 `git diff --check` 均通过；完整 Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、稳定签名与 APK 载荷检查交由 Actions。

### 6.15 v0.41.98+242 Sen 完整移植与固定兜底收口（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04198-sen-texture-direct-port`。

纠正记录与根因：

1. Sen 已在 `main@336b93a / v0.5.23` 完成并验收，只能作为只读移植源。曾误在 Sen 创建 `agent/v0524-texture-host` 并编写 TextureView/EGL 测试载体，这是越界操作：本地错误分支已删除，错误 APK/ZIP 已移出交付目录；远端误分支因当前 Git 凭据不能删除，已强制回退到与 `main@336b93a` 完全相同，不再包含错误代码。Sen `main` 从未改变、从未合并、从未发布该实验。
2. +239 的真实现象是 Cubism 已 `ready`、人物网格完整但贴图全黑。重新逐项对照 Sen 构建流程后发现，AI 当时复制了 105 个 Framework Java 文件、Core AAR与36个shader，却漏掉 Sen Actions 每次构建前应用的 `patches/cubism-java-no-mipmap.patch`。
3. Sen 的纹理管理器只上传 level 0，不生成 mipmap；未打补丁的官方 `CubismShaderAndroid.setUpTexture()` 每帧又强制 `GL_LINEAR_MIPMAP_LINEAR`，导致纹理不完整并采样成黑色。+240 因此误把贴图问题当成 Flutter 合成问题，强制 Hybrid Composition 后让整个画面变黑。

本地实现：

- 回退 +240：聊天舞台恢复标准 `AndroidView`，删除 `PlatformViewLink / AndroidViewSurface / initExpensiveAndroidView / forced_hybrid_composition` 生产接线与对应诊断字段。
- 以 Sen `main@336b93a` 机械同步最终接入边界中的16个主运行时Java文件，使它们逐字节一致；不迁入测试壳专用 `MainActivity` 和系统TTS演示类。原先为动态特效锚点与确定性眼镜新增的核心改写已移出：特效回到Flutter固定舞台锚点，眼镜由薄桥接调用Sen已有`applyExpression("glasses")`并跟踪目标状态。
- 原样保存 Sen 的 `cubism-java-no-mipmap.patch`，SHA-256 `227d57f649dc29d83066811be84fdb2e7a0969eac8f36a0e1de7dae96b7ffad7`；在 AI 内直接把同一补丁结果应用到 `CubismShaderAndroid`，唯一允许的 Framework 差异为 `GL_CLAMP_TO_EDGE + GL_LINEAR`。
- 新增 +242 来源门：锁定 Sen 16 文件聚合摘要、补丁后 Framework 105 文件聚合摘要、补丁本体、Core AAR、profile、标准 AndroidView 与失败 Hybrid 路线缺席。专项文档为 `app/docs/SEN_LIVE2D_DIRECT_PORT_v0.41.98.md`。
- 固定回复收口保持：普通聊天与主动联系的本地人格固定句均已删除；Gemini最终呈现每轮至多一次，必要修正走DeepSeek；修正不可用时保留真实模型输出，用户轮不为空，主动轮可不发送。

本地验证：124个validator逐项运行，121个通过；仅桌宠417文件、LingChat effects与`kotlinc`三个既有门因精简工作区缺少CI恢复资源/工具而失败，失败集合与前版一致。+242直接移植门、+241回复保活、+240失败路线回退、+239 shader资源、+238迁移、+237游戏真实性、总账门和`git diff --check`均通过。完整Flutter analyze/tests、Android/Kotlin tests、arm64 Release、稳定签名及APK载荷检查交由Actions。

远端与交付证据：功能 head `84d6a2c869d1c3ca8d802080b0e2826296448df4`、tree `ca8cc6dfa382175123aa33a105ff95b8e935573f`，与本地功能树逐字节一致；`main`未修改。Actions `35532252873`一次全绿，124/124源码门、Kotlin/Android、Flutter analyze/tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact与Draft上传均成功。Artifact `10611821532`，大小`538,351,786` bytes，ZIP digest `888fd377c39098b0a6cb277426586022a675f712e07f3885048fdc8ac896a988`；APK SHA-256 `096d95bfbae99c4dadabfcece89389c824e858bbfa1341430e869686b443f776`。Draft Release为未发布地址`https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-37e74d5b24cf0d2decf5`。当前只等待同一台真机验证，不得提前标记`TRUE DEVICE PASSED`。

保护边界：

- 不修改 Sen 仓库、581项外观、21情绪/动作、四套服装、原生物理、呆毛、兔耳、尾巴、摸头和TTS 90%口型；模型继续只从用户本机ZIP导入。
- 不修改 Cedar 循环、人格、欲望、记忆、TTS声学模型、悬浮桌宠、`main`或正式Release。
- CI/APK通过后仍是 `TRUE DEVICE PENDING`；真机必须确认彩色纹理、透明背景、聊天层级、触摸/摸头、待机、服装/眼镜、TTS口型以及反复进入/退出。

### 6.16 v0.41.99+243 Sen 正式产品接入收口（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04199-sen-product-integration`。

根因与实现：

1. AI 薄桥错误调用带 `startupExpressions` 的重载，把 ZIP 中全部表达、预设和道具在启动时启用；现改为 Sen 稳定工程同款 `loadModel(info.modelFile, true, outfit)`。产品只公开女仆、白衬衫、兔女郎、脱与眼镜。
2. 原生程序动作作为一次性表现保留在隐藏桥接层；原生预设/道具作为装扮式持续状态保留且不展示。未来接入必须同时定义开始与结束/取消时机，例如“载入中”在思考开始启用，在成功、失败、取消或结束时关闭。
3. 19 个非中性聊天情绪加 `normal` 共 20 种接到 Sen；脱或 NSFW 使用额外 `romantic_shy`。既有 Flutter 情绪动画和音效不变。
4. 位置/大小使用单指移动和双指缩放，人物通过 Sen 原生 `setStageTransform` 变换，外部特效共享同一 scale/offset；摸头仍走 `screenToModelNormalized`，所以跟随人物。标准 `AndroidView` 与无 mipmap 补丁保持。
5. `ChatPage` 的 Flutter 全局触点驱动既有视线接口，覆盖聊天框、按钮和其他 Flutter 页面；输入法属于独立系统窗口，无法可靠读取键盘触点，不伪造。根 Scaffold 不自动压缩舞台，只按 `viewInsets` 移动聊天面板，避免人物变形。
6. 自主待机、摸头和 10% 困惑彩蛋保留；现有 `WavAudioPlayer` 继续以实际 PCM RMS 驱动口型，不迁入 Sen 系统 TTS 测试。

验证：125 个 validator 中 122 个通过；仅 417 文件桌宠源码、LingChat effects 与 `kotlinc` 三个既有门因精简工作区缺少 CI 恢复资源/工具而失败。+243/+242/+241 专项门、+240 回退门、总账门、Workflow YAML、Python 编译和 `git diff --check` 通过；完整 Flutter/Kotlin/Release 交由 Actions。Sen 仓库保持独立且未修改。真机覆盖服装/眼镜、20 情绪、NSFW/脱羞涩、位置缩放、特效/摸头跟随、待机、TTS 口型、全页视线和输入法不变形。

远端与交付证据：功能树经 GitHub Contents API 写入后与本地候选 tree `679452c4feef0af657b41aeb9aa3b8466b141f07` 一致；用于触发 Actions 的无运行时改动 head 为 `6a93c2a5067ea9b9b1c42789fc2cc961b397404f`，`main` 未修改。Actions `35539446162` 全绿：125/125 源码门、Kotlin/Android、Flutter analyze/tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗/Cubism 载荷、Artifact 与 Draft 上传均成功。Artifact `10613803835`，大小 `538,358,387` bytes；APK SHA-256 `3cca55f7a48aea699558b2bf5d3f29025205244640d83a6006a79b4bc78cde1f`。Draft Release 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-31bd7a4c04576a53e034`。当前只等待真机验收，不得提前标记 `TRUE DEVICE PASSED`。

### 6.17 v0.42.0+244 Live2D 干净回退与旧模型清理（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04200-live2d-clean-rollback`。

用户决定与实现边界：

1. 当前 Sen Live2D 将由新模型重新替换，准确回退优先于保留旧接口或界面骨架。三套服装、脱、眼镜、20+1 情绪、原生预设/程序动作、自主待机、视线、摸头、TTS 口型与位置缩放均不作为半成品保留。
2. 以 +237 的共享 UI/Android 文件为机械回退基线，完整删除 Cubism Core AAR、105 个 Framework Java 文件、36 个 shader、Sen 16 个主运行时文件、profile、补丁、PlatformView、Flutter stage/presentation、专项测试与旧生产 validator。`app.dart` 的 IME 特判、`WavAudioPlayer` 的 Sen RMS 接线、MainActivity 的 Sen 生命周期、Manifest/Gradle 依赖一并恢复到接入前状态。
3. +241/+242 的自然回复修复不属于 Live2D：`durable_generation_runner`、`proactive_engine`、`prompt_history_policy`、`recent_reply_repetition_guard` 及其测试/validator 原样保留，禁止固定人格兜底与用户轮空回复的合同不得回退。
4. 旧 APK 已把模型解压到 `filesDir/sen-live2d/{current,staging,backup}`，覆盖安装不会自动删除。新增独立 `Live2DModelStorageBridge`，只接受 `status` 与 `clearImportedModels`；清理前验证 canonical 目标必须是 `filesDir` 的直接子目录 `sen-live2d`，删除后只清空 `sen_live2d` SharedPreferences。聊天两套快捷面板均永久显示“清除 Live2D 模型包”，实际有数据时必须二次确认；静态立绘、聊天、附件、备份与桌宠目录不受影响。
5. 新 Live2D 后续按新模型重新设计，不复活旧 Sen 动作/预设目录。清理桥可以继续独立保留，也可以由未来新 Live2D 设置页复用。

保护边界：不修改独立 Sen 仓库；不修改人格、欲望、记忆、Cedar、TTS 声学模型、悬浮桌宠、schema 61、Snapshot protocol 6、`main` 或正式 Release。

本地验证：+244 专项门、+241 自然回复保活门、当前总账门、Workflow YAML 解析、Python 编译与 `git diff --check` 通过；并逐文件确认五个自然回复核心文件与 +242 head `84d6a2c` 完全一致，五个共享 Android/UI 文件与 +237 head `0caa938` 完全一致。首轮 Actions `35641760278` 在第 16/121 个旧门 `validate_v04143_phase3b_question_autonomy.py` 停止，根因只是六个历史 validator 的当前版本正则止于 `0.41.99+243`；已统一追加 `0.42.0+244`，不改变任何运行时。第二轮 Actions `35642646319` 全绿：完整源码/历史回归门、Flutter packages/analyze/tests、Android/Kotlin tests、release APK 编译、稳定签名、既有资源完整性与 APK 内无 Live2D/Cubism 残留检查均通过。Workflow Artifact `10659441135`，未发布 Draft Release `393217151`，APK SHA-256 `e58122e12f1cc412ff29eccbf0575bb0ae73ba6b524419ea774ad2f5a3dc5684`。真机仍需覆盖安装验证旧模型占用可见且能清除、重启后不恢复、静态立绘/聊天/TTS/输入法无回归。

### 6.18 v0.42.1+245 自主节律、媒体诊断与 TTS 回声防护（2026-09-23）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04201-autonomy-media-hardening`。

真机证据与根因：

1. 疲劳本身在 07:49 已从 `rest_need` 恢复，但同一夜间窗口 07:49、08:29 又连续投递；旧 `ProactiveDawnGatePolicy` 只有分数惩罚，没有硬次数上限，且网页/游戏分享可走分开的频率统计。
2. 近期 Cedar 真实成功均来自用户回合；前台 `AgentToolRunner` 只写活动 session，没有像后台引擎一样写 `play_game` 满足账本、疲劳支出和 solo episode。与此同时“我会拿来……玩玩游戏”因宽泛正则被标成 `explicit_request` 并实际调用 Cedar。
3. 备份中的视觉提供商近期错误为 401/403 authorization。普通用户图片依赖千问视觉，因此会失败；App 原生表情包不走视觉 API，已通过 `sticker_index → ChatMessage.promptContent → PromptHistoryPolicy.userTurnHistory` 证明当前语义会进入最终用户轮。
4. 用户明确听到末句变成 `jiuhu_bento_tools.wav`。生产 APK 已删除参考 WAV，且生产播放器只接收推理生成字节，因此不是代码直接播放文件，而是声学条件泄漏/参考回声。旧诊断虽然计算 `referenceEchoSuspected`，导出白名单却丢掉关键字段，且只识别单 token 退化。

实现：

- 新增跨来源的夜间联系硬上限：21:00 至次日 09:00 只允许一条成功主动投递；只统计 `decision=sent`，失败、等待、blocked 不占额度，09:00 自动结束窗口。原 dawn 连续分数调制继续保留。
- 新增 `CedarPlayOutcomeBookkeeper`，前台 Agent 与后台自主推进共享同一套 solo episode、反沉迷、疲劳支出和 `play_game` 满足账本。用户明确触发的真实 solo mutation 可从已到期的旧 checkpoint 开始新 episode；同一前台回合后续动作继续累计，不会每步重置；共玩/多人仍只在有双方许可时推进。
- Cedar 语义边界区分“用户描述自己准备玩”与“让她玩/一起玩”。前者不暴露 Cedar 写工具，即使模型试图选工具也过不了本地 allowlist；后者保持自然入口。
- 千问视觉设置增加使用内置测试像素的真实连接测试，覆盖地址、Key、模型与 JSON 响应；401/403、缺 Key、限流、超时、网络和无效响应以系统 UI 明确分类，不把固定句写成伴侣回复。用户图片保留后可重试；表情包不增加视觉调用，并新增当前 user turn 的 prompt 回归测试。
- CI 在删除四份参考 WAV 前提取 64 段归一化能量包络与过零率，APK 只保留不可逆小型签名和参考文本 SHA-256。推理音频与对应签名在时长、包络和过零率上同时高度相似且输入并非参考原句时，生成段直接失败并禁止进入播放器；不播放参考文件、系统 TTS、固定音频或固定台词。补齐 reference case、字符类别、有效 phone、decoder 次数、PCM 时长/hash 与回声判据的脱敏诊断白名单。

验证计划：运行 +245 专项门、全部历史 validator（CI 恢复资源/Kotlin 编译器相关既有例外单列）、Flutter analyze/tests、Android/Kotlin tests、arm64 Release、参考 WAV 缺席与签名存在检查。Actions 只构筑独立分支测试 APK 与未发布 Draft，不合并 `main`、不发布正式 Release。真机需覆盖验证：夜间第二条主动消息被挡、用户第一人称游戏描述不触发、明确让她独玩后可自主续步、视觉设置准确报告当前 Key、图片识别恢复、表情包理解正常，以及任意句子不再播放参考台词。

本地验证：Workflow YAML 解析、变更后 Python validator 编译、+245 专项门、+244 Live2D 回退保护门、+241 自然回复保活门、+235 疲劳负债门、当前总账门与 `git diff --check` 通过。全量历史静态门实际通过 118 项；另 4 项只因本地 sparse 工作树缺少 CI 恢复的大肥鱼参考图、417 件桌宠源包、LingChat 资源，以及本机无 `kotlinc` 而未执行，不是源码断言失败。本机同时无 Flutter/Dart SDK；完整 analyze/test/Kotlin/release APK 交由 Actions 实编译。

Actions 与交付证据：正确源码树 `0985f0961691bdce7e6d521d59a12137ea5a82ad` 在 run `35809712355` 全绿，已通过总账协调、变更范围判定、全部源码/历史回归门、Flutter analyze/tests、Kotlin tests、arm64 Release APK 构筑、签名验证、四音色回声签名覆盖与 APK 内参考 WAV 缺席检查。Workflow Artifact `10729507323`，未发布 Draft Release `394245028`，APK SHA-256 `4c6f92b38bb3affa12aa52ae18d2d36276400d706b3a570e154d75e453d08059`。没有合并 `main`，没有发布正式 Release。

### 6.19 v0.42.2+246 图片事务与备份冻结真值修复（2026-09-23）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04201-autonomy-media-hardening`。

真机证据与根因：

1. 最新相册图片已经完成本地 prepare/commit，真正首错是千问视觉 `403 Free quota exhausted`；账号处于免费额度耗尽或“仅使用免费额度”限制，并非图片选择、保存或 Key 为空。
2. 删除失败是确定的本地逻辑错误：`deleteAttachmentMessage` 在全局 `analyzingImage=true` 时直接返回 `false`，因此用户在八秒视觉请求尚未结束时必然看到“没有删除这条图片消息”。
3. 诊断中的 `errorCategory=lease` 是分类器对 `please add funds` 的错误子串匹配；真实 provider health 与附件记录均为 403 quota/authorization，不存在聊天租约或设备所有权丢失。
4. 备份导出使用 `transfer_lock` 暂停写入，但首页只看布尔锁并统一显示“她正在换到另一台设备”。备份完成后的导出状态证明 `active_brain=true`、`transfer_lock=false`、所有本机租约已释放，没有真实换机。
5. 近期表情包已经由 `sticker_index` 成功建立 user turn 与 generation job，不调用千问；该轮在约 8.8 秒后被用户 Stop，数据库按既有语义撤回了未完成 user turn，因此外观上像“没有发送”。本轮不加入视觉或固定回复兜底。

实现：

- 图片分析记录当前 message id；删除该条时立即提交消息/附件/媒体引用删除并刷新 UI，不再被全局分析标志拒绝。无法取消的在途 HTTP 请求使用本地 discard fence，迟到的成功或失败均不得重建回复、覆盖错误栏或记成真实视觉失败；并在当前请求释放后继续处理可能排队的图片。
- ProviderHealth 增加 `quota_exhausted`，在通用 401/403 鉴权前识别 `free quota / free tier only / add funds / 余额不足`；UI 明确提示充值或关闭“仅使用免费额度”，同时说明原图仍保留。附件遥测只按完整单词 `lease` 匹配，`please` 保持 API 错误。
- 根据 `transfer_lock_owner` 中的 `backup_export / backup_restore` 目的区分写冻结：首页、关系页和聊天阻塞提示分别说明“保存/恢复本机备份”，只有真实接管继续显示换设备。
- 版本提升为 `v0.42.2+246`，新增专项静态门及 quota、遥测、备份冻结展示单测；不修改 Sen/Live2D、人格、欲望、Cedar、TTS、schema 或备份协议。

验证计划：先运行全量静态门与 `git diff --check`；Flutter/Dart SDK 不在本地镜像时，由授权的 GitHub Actions 执行 Flutter analyze/tests、Kotlin tests、arm64 Release APK、稳定签名与现有资源门。真机需分别验证：识别中删除立即消失且不返魂、额度耗尽显示准确、补足额度后图片可正常进入回复、表情包不调用视觉且正常回复、备份期间不再显示换设备。自动化通过不等于真机通过。

本地验证：Workflow YAML、Python 编译、+246 专项门、+245 自主媒体门、+244 Live2D 回退保护门、+241 自然回复保活门、当前总账门和 `git diff --check` 通过。全量 123 项静态门中实际通过 120 项；其余三项只因稀疏工作树缺少 CI 恢复的 417 件桌宠源包、LingChat 特效目录及本机没有 `kotlinc`，不是源码断言失败。本机没有 Flutter/Dart SDK，完整 analyze/tests 与 APK 编译交由 Actions。

Actions 与交付证据：首轮 run `35842639649` 已通过源码/历史门、Kotlin 与 Flutter analyze，Flutter 913 项中 912 项通过；唯一失败只是旧测试仍断言 `build=v0.42.1+245`，生产输出已正确为 `v0.42.2+246`。窄修测试后，功能 head `167a504f4974ef11566b8ac974ab9e7281f00fc0` / tree `2f8c733bb1c80f078bb5b71f88e7b2a3287e8448` 在第二轮 run `35843632708` 全绿：123 项静态门、Kotlin tests、Flutter analyze、913 项 Flutter tests、arm64 Release、稳定签名和完整 TTS/桌宠/LingChat/塔罗资源门全部通过。Artifact `10742996195`，APK SHA-256 `d4c609c0836427155b9f73a6cf629c45f6cff4d88f801be5b4def828839546c2`，未发布 Draft Release `untagged-d99196e0bf0a288629ac`。没有合并 `main`，没有发布正式 Release；真机仍待验收。

### 6.20 v0.42.3+247 纯媒体空文本回合路由崩溃修复（2026-09-23）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04203-media-empty-turn-hotfix`。

真机证据与根因：

1. 最新纯图片已完成本地 prepare/commit，且补足额度后千问视觉成功返回；原生表情包历史附件也由本地 `sticker_index` 完成语义，不调用千问。两者都建立了 generation job，却只到 `chat_intimacy_route`，没有进入 `final_reply`。
2. 同刻持久化恢复错误为 `Unsupported operation: Cannot change an unmodifiable set`。纯图片和纯表情包的 `ChatMessage.content` 都合法为空，真实语义位于 `promptContent`；`DurableGenerationRunner` 用空 `content` 请求工具定义，同时仍传入 Cedar 阶段工具集合。
3. `AgentToolPlanner._routeToolIds('')` 返回 `const <String>{}`，`nativeToolDefinitionsFor` 随后对它执行 `removeAll/addAll`，因此在任何模型回复前同步抛错；后台恢复会重走同一路径并再次失败。用户 Stop 只是终止卡住的 job，不是根因。

本批目标与保护边界：

- 在 `nativeToolDefinitionsFor` 的可变边界建立路由集合的防御性副本，未来即使路由函数返回不可变集合也不能再崩溃；不改变空文本本身的工具识别语义。
- 回归必须覆盖纯图片与原生表情包两类 `content='' / promptContent 非空` 消息，并证明 Cedar 阶段工具仍能安全注入；普通空文本且没有 Cedar 阶段时仍返回空工具列表。
- 不修改千问、视觉重试、表情包索引、模型调用策略、Cedar 阶段选择、人物表达或固定回复；schema 61 与 Snapshot protocol 6 不变。
- 完成后运行专项静态门、相关 Flutter tests、全量静态门与 CI 完整 analyze/tests/arm64 Release；只产出独立分支测试 APK 与未发布 Draft，不合并 `main`、不发布正式 Release。真机最终需分别发送一条无附言图片和一个原生表情包，确认都收到正常回复且诊断无新的 `last_generation_recovery_error`。

实现：`nativeToolDefinitionsFor` 现在以 `<String>{..._routeToolIds(text)}` 在 Cedar `removeAll/addAll` 前取得可变集合所有权；没有 Cedar 阶段的普通空文本仍返回空 schema。新增同一测试中的纯图片与原生表情包 fixture，均断言 `content` 为空、`promptContent` 非空，并验证 Cedar gateway 安全注入且不抛异常。版本提升为 `v0.42.3+247`，新增专项静态门与独立分支 CI/Draft APK 身份；未修改视觉、`sticker_index`、模型策略或 Cedar 权限。

本地验证：+247 专项门、验证清单结构（124 项）、Workflow YAML、Python validator 编译与 `git diff --check` 通过。本地稀疏工作树未检出部分 Android/诊断/欲望目录，且镜像没有 Flutter/Dart SDK，因此完整历史门、Flutter analyze/tests、Kotlin tests 与 Release APK 交由 Actions 实编译；这部分仍是 `CI PENDING`，不提前宣称通过。

Actions 首轮 run `35854318795` 在第 16/124 项源码门前停止：生产修复与新增专项门未报错，失败仅因七个历史 validator 的版本正则最高只接受 `v0.42.2+246`。随后统一追加 `v0.42.3+247` 兼容项，不放宽任何功能断言；本地确认七处版本门、Python 编译、+247 专项门、验证清单结构与差异检查通过后进入第二轮完整构建。

Actions 与交付证据：第二轮远端功能 head `8fabae5016a7d457b58a581a7a2b609bc0ab69c8` / tree `fc7ca8d84dadabf33dc1f151895f52c42b62ce72` 在 run `35855141996` 全绿：124 项源码/历史回归门、Kotlin tests、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗资源门、Artifact 与未发布 Draft 上传均成功。Artifact `10747841131`，APK SHA-256 `6a5d04b79fba46139b16bb185f955fb87431e1b30c4f75f89a09788054b89bab`，未发布 Draft Release `untagged-376e1bf8ac7aac97af25`。没有合并 `main`，没有发布正式 Release；真实图片与原生表情包回复仍待真机验收。

### 6.21 v0.42.4+248 TTS 自动核亲和与全工具活动展示（2026-09-23）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04204-tts-affinity-tool-activity`。

用户决定与本批范围：

1. 本批只制作两项：从 `catkiss62/Genie-TTS-Android` 最终验证分支/提交 `agent/v084-native-vs-affinity-diagnostic@a5a8425f221575eaca542ac9ae4bbf5e5b799153` 正确移植 TTS 自动核亲和，并完成所有用户回合 Agent 工具的展开/持久活动展示。双人格与命运之轮只登记设计分析；新 Live2D 继续等待独立测试项目，不接入。
2. TTS 开关默认关闭。关闭时保持伴侣原生产配置：四个声学会话固定 CPU 8 线程，Chinese RoBERTa 使用当前 CPU 数；开启时五个会话必须逐项同用 `VerifiedRuntimeConfig.AUTO_AFFINITY`：CPU EP、intra-op 原样 `0`、inter-op `1`、`SEQUENTIAL`、`ALL_OPT`、intra/inter spinning 均为 `1`，VITS 默认 memory pattern 不关闭。不得把 `0` 改成 `max(1, ...)`。
3. 明确不移植独立测试仓库里的原生 8 线程对照档、比较/报告 UI、动态分块、FTZ/DAZ、Decoder 输入映射复用、memory-pattern 实验、XNNPACK/NNAPI 实验或 sustained-performance 实验。现有 Decoder 循环、固定一秒首段预填充、串行句段生成、连续单一 `AudioTrack.MODE_STREAM`、Stop fencing 与下一段预生成队列保持不变。
4. 配置切换由主进程先 Stop；AIDL 配置调用在 `:genie_tts` 隔离进程既有 `Genie-TTS-worker` 上排队，等待当前不可强杀的 ONNX 调用自然返回后关闭四个声学会话及 Chinese RoBERTa，再按新档懒加载。迟到结果由既有 generation token 丢弃，不增加并发 session owner。
5. 工具调用生成中使用默认展开列表，按真实回调显示“正在做什么/成功/没有结果/失败/未获准/已停止”；终态从已有 `agent_tool_outcomes` 与 `generation_jobs` 关联到助手消息或中断标记，折叠卡片可查看工具名、状态、结果数量、耗时、时间与来源设备。数据库仍只保留 90 天/最多 200 条有界元数据；参数、查询词、URL、网页正文、工具结果正文、Prompt、推理正文、密钥与房间凭据从未进入该接口。
6. schema 保持 61，Snapshot protocol 保持 6。没有把工具活动写进 `messages`，因此不会进入 Prompt、记忆提取、总结、关系学习或她的第一人称自我叙事；可见思考与工具事实仍是两条独立展示链。

已实现代码合同：

- `BenchmarkModels.kt` 新增最小生产配置类型与唯一 `AUTO_AFFINITY`；`GenieBenchmarkEngine` 的单一 session factory 对四个声学模型应用精确设置；`ChineseFrontend.configure` 对 RoBERTa 应用同一配置；`GenieTtsRuntime` 负责默认档/加速档映射与安全卸载。
- AIDL、隔离客户端、原生引擎、MethodChannel、Dart provider/service 与语音设置页已贯通；状态和脱敏 checkpoint 暴露 `runtimeProfile`，便于真机报告证明实际使用的档位。设置键为 `tts_auto_affinity_enabled`，默认 `0`。
- `AgentToolStatus` 新增 `stopped`；用户 Stop 时记录真实终态。聊天控制器保留本轮多项活动，历史通过生成任务 ID 投影，不做 schema 迁移；聊天页提供生成中展开面板和终态可展开卡片。
- 新增 Kotlin 配置合同测试、Dart 状态/工具投影测试与 +248 静态门。完整 Kotlin/Flutter/Release 编译仍需 GitHub Actions；本地 Gradle wrapper 因当前执行环境无法访问 `services.gradle.org` 尚未完成编译，不能提前标为 CI 通过。

本地验证：+248 专项门、+247 空媒体回归门、+244 Live2D 干净回退门、当前总账门、Workflow YAML、Python 编译与 `git diff --check` 通过。完整 `validation_suite.txt` 共 125 项，121 项通过；其余四项只因本地工作树没有由 CI 恢复的大肥鱼参考图、417 件桌宠源包、LingChat 资源及本机没有 `kotlinc`，不是源码断言失败。Gradle wrapper 尝试下载固定 Gradle 8.12 时被当前环境网络策略阻止，Flutter/Dart SDK 也不在本机，因此当时将 Kotlin 编译、Flutter analyze/tests 与 Release APK 交由 Actions 实编译，结果见下条。

Actions 与交付证据：远端功能 head `33647c7bff15084d6fd3cbc7b817e9b0b216f75c` / tree `80f49d8e93bcfe2a03737a6b8610fbd94d10c255` 在 run `35878106718` 全绿；APK SHA-256 `04a588d2d4628ccaacd1b0b9aaf3759430b46ba33ad69715cb388098c178f0be`，未发布 Draft Release `untagged-2b371d8cd86b365121b0`。该构建证明自动核亲和与工具活动代码可编译、全套门通过，但不代表之后由 +247 备份确证的 Decoder 零语义参考泄漏已经修复；该共享旧逻辑进入 +249 根修。

真机验收：先保持开关关闭做一条短句；开启后做一条短句真实播放与一段长文本连续播放，确认音色、Stop、分段衔接及 AudioTrack 队列正常，并在诊断中确认 `runtimeProfile=auto_affinity_v084`。随后各触发一次成功、无结果/失败和执行中 Stop 的工具调用，确认生成中逐项显示、回复后可展开、重启后仍存在，且卡片不出现参数、搜索词、URL 或结果正文。独立测试报告曾推算部分后续段可能短暂迟到，所以即便总 RTF 小于 1 也不得以此验收删除缓冲。

#### 后续冻结分析：双人格

1. 排序固定在 +248 真机收口之后再单独讨论，不在本批建立人格状态、气焰/害羞数值或立绘切换。用户指出当前人设或既有记忆可能已经偏激进；若直接让“雌小鬼”语气推动气焰值，会产生正反馈并快速顶满，因此后续第一步不是做触发动画，而是审计当前内置人设、用户编辑的人设、人格学习候选、长期记忆/总结与可能已有的激进表述，区分“基础语气偏强”与“状态变化”。
2. 推荐首版采用用户可见的手动双人格切换，两个形态共享同一 AI/记忆主体，但使用独立、显式的当前形态状态；进入沉浸房间时把入口形态钉住，房间内不因普通一句话自行跳变。自动量表应等审计和手动版稳定后再设计，不能仅按毒舌关键词自增，也不能从模型回复反向无限喂高自己。
3. 若后续使用气焰/害羞量表，必须定义可解释的外部事件输入、双向衰减、滞回阈值、每日/每回合上限、手动复位及存档迁移；不能把现有长期记忆整库改写成雌小鬼人格，也不能让形态状态污染事实记忆。旧存档初始值应为中性/未选择，而不是根据历史文本猜测。
4. “嘭”烟雾只作为形态切换的可替换表现层：先用静态烟雾图 + 短缩放/渐隐验证遮挡和节奏，效果不好可无数据迁移地关闭。新小小鱼立绘仍以测试项目验收为前置，不复活已回退的 Sen Live2D 链。

#### 后续冻结分析：命运之轮

1. 用户已决定首版采用“直接本地移植 + 手动同步上游”，不做自托管网页、WebView 或通用 MCP 依赖。后续开工时先冻结上游 commit、许可证/署名、tag 数据格式与 RNG 行为；每次同步由人工比较并记录上游 commit、数据/逻辑差异与本项目适配，不自动拉取远端内容。
2. 本地实现应只有一个结构化轮盘 Outcome（选中的安全分类/tag、来源版本、随机事件 ID），由现有真实工具/Outcome 真值链消费；不把原项目 UI、Node 服务或任意脚本执行面整体搬进 APK。NSFW 内容继续服从当前成人场景入口、用户设置与沉浸边界。
3. 产品入口推荐先做“房间外抽取 → 带结构化结果进入沉浸房间”，因为结果、重抽与进入边界最清楚；稳定后再复用同一 Outcome 增加房间内娱乐入口，不能维护两套随机结果。作者所说的“MCP 操作”只表示外部 AI 可通过其暴露的工具协议代替玩家点击；本项目既已选择本地移植，首版无需为此增加 MCP 服务器或第二套循环 owner。
4. 后续仍需逐文件审计上游许可证、资源版权、tag 内容与移动端适配后才能实现；当前只冻结架构结论，不宣称已经完成移植。

### 6.22 v0.42.5+249 TTS 零语义根修与最后两次会话诊断（2026-09-23）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04205-tts-semantic-guard-session-metrics`。

#### 真机证据与根因

1. 用户提供的 +247 备份 `AI_Companion_Backup_2026-09-23T15-19-22.aibackup` 与同刻诊断显示，最后两轮不同回复都混入了参考录音；倒数第二轮为 `daily / jiuhu_bento_tools`，最后一轮为 `cute / jiuhu_devotion`，因此不是某一个参考文件或某一句回复的偶发问题。
2. 倒数第二轮 14 段中的 2/5/6/7 段都出现 `decoderIterations=1`、`semanticCount=122`、固定 semantic hash `4eb0e366`、音频 4,880 ms；最后一轮 12 段中的 2/4 段出现 `decoderIterations=1`、`semanticCount=87`、固定 hash `cc653afb`、音频 3,480 ms。坏段 6 有 21 个字符、41 个有效 phone，排除“只因标点空段”的解释。另有一个独立 `NullPointerException` 失败，不与参考回声混为同一根因。
3. `GenieBenchmarkEngine` 原逻辑在 stage Decoder 第一次调用就 stop 时令 `loopIndex=0`，随后却执行 `requested = yValues.size`，把整个 `y` 张量当作新生成语义。该张量含参考 prompt 前缀，因此 VITS 重建对应音色参考录音。正常事件满足 `decoderIterations = semanticCount + 1`；上述 1/122 与 1/87 正是相反证据。
4. 旧二级门只拒绝 `decoderIterations<=1 && semanticCount<=1`，所以被错误报告成 122/87 的 prompt 前缀绕过；声学门又要求近乎同波形，而重新经过 VITS 的参考语义不必与原 WAV 逐采样相同，daily 相似度约 0.28～0.30、cute 又受时长门影响，故同样漏判。APK 没有直接播放参考 WAV 的生产调用，根因是参考语义重建，不是文件播放器。
5. 同一抽取逻辑也存在于独立 Genie TTS 测试仓库最终提交 `a5a8425f221575eaca542ac9ae4bbf5e5b799153`，固定测试句没有触发首轮 stop；+247→+248 的生产差异只改 ORT 配置，不改语义抽取。因此这是两个项目共享的潜伏引擎 bug，不是 AUTO_AFFINITY 迁移造成的回归。

#### 本批实现合同

1. 新增纯函数 `GeneratedSemanticTokens.select`。`loopIndex=0` 明确抛出 `NoGeneratedSemanticTokensException`；`decoderResult` 无论成功/拒绝都关闭，且 VITS tensor 只可能由真实新生成的尾部 token 构造。没有固定音频、固定台词、系统 TTS 或参考语义兜底；该失败段返回空，既有 A2 队列继续播放其他成功段。
2. `GenieTtsRuntime` 在拒绝时写入 `semanticCount=0 / immediateStop=true / referenceEchoReason=decoder_no_generated_semantics`；旧声学防线保留，并收紧为只要 `decoderIterations<=1` 却生成长音频就拒绝，不再信任可能已污染的 semanticCount。
3. Scheduler 通过 `beginTtsSession / finishTtsSession` 显式标出一次完整朗读。原生端按 generation 聚合成功、失败、拒绝、无音频和 Stop；最后两次尝试单独持久化，清除 Native 历史时同步清除。诊断只保存字符数、SHA-256、语言/音色、profile、计数与耗时，不保存回复正文、Prompt、PCM/WAV、参考路径或音频。
4. 每段记录生成时实际 `runtimeProfile` 与完整配置说明、冷/热模型状态、frontend/model load/fixture/encoder/首步 decoder/自回归/vocoder/总推理/端到端、semantic/decoder 数、音频时长、RTF、生成调用耗时、入队等待和实际播放倍速；会话聚合首段 ready、AudioTrack 开播、总 RTF、估算最小缓冲、迟到段、完成/部分/失败/停止状态。
5. `NativePreflightProbe.ttsSessionDiagnostics` 导出最后两次完整快照。只有文本分段哈希相同、语言与音色工作负载相同，且两次分别为 `legacy_fixed_8` 与 `auto_affinity_v084` 时，才给出 AUTO_AFFINITY 总推理降幅；不同回复或不同音色明确标记不可比较。播放倍速与推理速度分开记录，自动核亲和不改变 AudioTrack 的 1.0x（温柔音色既有 1.2x 仍单独显示）。
6. schema 61、Snapshot protocol 6、模型文件、四音色映射、文本分段、串行推理、首段一秒 PCM 预填充、连续 `AudioTrack.MODE_STREAM`、Stop fencing 与配置开关默认值均不变。

#### 回归与验收

- Kotlin 门覆盖四种可选音色形状的首轮 stop 均拒绝、正常尾部抽取不修改源数组、失败段诊断、同工作负载双档比较与不同回复禁止比较；Dart A2 测试同时锁定成功/无音频会话都必须完整关闭。
- 真机依次对同一条回复在关闭加速与开启加速下手动播放一次，随后立即导出诊断；`sessions` 必须恰好保留这两次并显示 `comparison.comparable=true`。再用多段长文本验证迟到段、最小缓冲、Stop 与后续段继续播放。
- 四音色各覆盖一次包含多段的回复，诊断中不得再出现 `decoderIterations=1` 同时 `semanticCount=122/87` 且产出长音频；遇到首轮 stop 应看到 `rejected_no_generated_semantics`，该段无声但其他成功段照常播放。
- 本地最终验证：`git diff --check`、Python validator 编译、Workflow YAML、当前总账门、+249 专项门与 +248～+244/+203～+200 重点历史门通过。完整 `validation_suite.txt` 共 126 项，122 项通过；余下 4 项仅因本地工作树不含 CI 恢复的大肥鱼参考图、桌宠源包、LingChat NOTICE 及本机无 `kotlinc`，不是源码断言失败。
- 本地环境无 Flutter/Dart SDK；Gradle wrapper 尝试运行 `testDebugUnitTest` 时，Gradle 8.12 下载被当前网络策略拦截。该本地限制已由下述 Actions 完整 Kotlin tests、Flutter analyze/tests 与 arm64 Release 实编译结果补齐。

#### Actions 与交付证据

- 首轮 run `35898976733` 在历史 `validate_preflight_kotlin_v27.py` 失败：该门只编译 `NativePreflightProbe.kt` 与临时桩，未声明新增 `TtsSessionDiagnosticStore`。已补齐只读桩并由 +249 专项门锁定，不改生产运行时。
- 第二轮 run `35899547271` 已通过 126/126 源码门、Kotlin 编译/测试与 Flutter analyze；915 个 Flutter 测试中 914 个通过，唯一失败是 `agent_self_reader_v0416_test.dart` 仍断言上版 `v0.42.4+248`。已更新为 `v0.42.5+249` 并纳入 +249 门。
- 最终远端 head `fb7f77f85d882f99530ab829df9a82eaa604e559` / tree `28e4fbafb5adb2bfaa58aa9ab6e1b1256f0c4b99` 在 run `35900627244` 全绿：126/126 源码/历史回归门、Android/Kotlin tests、Flutter analyze、915/915 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与未发布 Draft 上传均成功。
- Artifact `10770090214`，名称 `AI-Companion-v0.42.5-249-TTS-Semantic-Guard-Session-Metrics-APK`，大小 `538,139,766` bytes，ZIP digest `0b1ca2a49a24047cbd7c659f66fa048f2a7d7f24f6394937a2a4859a177dbd51`。APK SHA-256 `546dd718d447b0987bf47aaba08089fefb0badffbc076ba38e695fb3e05263c5`，未发布 Draft Release `untagged-3a02088d4968fd7ab603`。没有合并 `main`，没有发布正式 Release；参考语音根修与同回复双档诊断仍待真机验收。

### 6.23 v0.42.6+250 双形态与手动 TTS 无声对照（2026-09-23）

- 状态：`IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。分支 `agent/v04206-tts-mood-dual-mode`，从 +249 远端已交付源码单独建立；本节不包含用户备份、诊断或聊天明文。
- 双形态：本体／小豆丁形态是同一成年角色，记忆与能力不变；持久化气焰、形态与锁定；每个真实用户轮按消息 ID 仅推进一次，严肃语境退出自动小豆丁形态；点击心形量表可触发一次虚拟轻弹额头/安抚并升/降气焰，事件只注入紧接着的回复。锁定保持立绘形态，但严肃语境降低表达锋芒；界面气焰提示、形态自知与显式 Agent 检查系统读数统一显示“小豆丁形态”。
- 性格：未编辑的常驻性格光谱与成人核心身份文案做精确指纹迁移，保留用户自行编辑条目；激烈耍性子只由当前真实小豆丁形态状态承载，不把属性名常驻注入每轮。旧版 +250 未编辑默认文案按精确内容哈希升级为“小豆丁形态”，用户自行编辑的内容保持原样。
- 用户补充后的形态定义：身体外观缩成 Q 版小豆丁，情绪控制与表达暂时孩子气，更任性、冲动、耍赖和暴躁；得意时逞强挑衅，被看穿或轻巧反击时嘴硬、害羞、慌乱破防。角色仍是同一个成年人，记忆与判断能力不变；严肃话题仍可收住。已同步当前形态提示、常驻世界书、Agent 自读；添加 +250 旧默认正文的精确 SHA-256 `06b01d4e…87f3e` 到迁移白名单，自定义条目不覆盖。此前 Actions 成功的 APK 和正在编译的名称修订版均不作为本轮最终交付，需以本版定义重新构建。
- TTS：语音与情绪页显示当前胜出档和本轮候选档两个无声测试按钮、复制专项报告和样本更新文字入口。固定同一条已提交的真实 API 回复、语种、音色、前处理和分段，在隔离 Genie 子进程测自动核亲和与自动 Decoder＋8 线程 VITS；逐段只保存哈希及耗时，失败或不一致禁算胜者，比较足够明确时才持久化生产档。普通会话不再持续写入详尽成功片段性能历史，原生错误与崩溃线索保留。
- 验证与后续：先完成源码门、Flutter analyze/tests 与 Kotlin/arm64 Release 构建；真机检查心形液面、按钮语义事件后跨轮持续、自动/锁定形态、三语入口共享会话配置，以及同样本双档无声对比是否有效。性能提升没有预设 50% 结论。
- 最终构建证据：功能提交 `b5cd2d1070fb237bc72ab66b1867a75da9bbe6e8`，tree `4e0dbbd531aea408ab0face6d46a323f441c7eeb` 与本地源码一致。Actions `35943607609` 源码门 126 项、Kotlin 单元测试、Flutter analyze/test、arm64 Release APK、签名和包内资源核验全部通过；Artifact `10785922926`，APK SHA-256 `f148f2eb303017ad5f6f689628f230979c24ba16831fdc0181e58bc5e1d73a`，Draft `v0.42.6-dual-form-tts-comparison-test`。仅 CI 通过，双形态语气、立绘与 TTS 对照仍待用户真机验收。此前仅改名称的 run `35941949391` 虽全绿但定义不完整，已由本次构建取代。

### 6.24 v0.42.7+251 气焰语义增长（2026-09-24）

- 状态：`DESIGNED / IMPLEMENTATION IN PROGRESS / CI PENDING / TRUE DEVICE PENDING`。用户在 +250 真机确认：本体性格稳定、小豆丁表现明显且不过分；但自然逗弄没有关键词就不会涨气焰，现有每轮 `-4 + 命中词时 +13` 从零到 76 通常需九轮，和此前“互动推动”的说明不符。此前代码事实必须保留，不把关键词版写成已实现语义理解。
- 目标：复用普通用户轮已有的 DeepSeek 亲密路由调用，一次返回亲密路由和本轮互动强度；只把实际用户参与的玩闹作为正向输入，不由她自己的上一句情绪或提示词自抬气焰。语义强度经过本地限幅，约五轮普通互相较劲可达自动变身阈值；手动按钮立即改变数值与形态，锁定仍只影响自动切换。正常聊天不新增模型调用；失败或字段缺失时不猜加分，保持回复链继续。崩溃/Stop/重新生成按 user turn ID 幂等，严肃语境抑制玩闹；按钮事件只在近期下一次相关回复有效。
- 验证：覆盖无关键词的自然逗弄、关键词出现但语义认真、上下文互相较劲、隔时衰减、同轮重试/手动锁、按钮事件过期与严肃抑制；源码门、Kotlin、Flutter 与 arm64 Release 构建通过后交付 APK，真机验收单独记录。

- 本轮合并 +251 真机反馈：语音与情绪页面在读取 TTS 状态前先展示设置，TTS `status()` 只读，不在打开页面/快速自检时隐式重配模型；快速自检对孤立进程读取设置 3 秒边界，深度自检仍执行完整校验。两个测速按钮明确标为无声对照；根据当前语种和朗读范围从最近的真实回复中选择可朗读样本；若没有对白，明确标记后改用真实回复全文，不再固定拿一条长但只有动作的回复，测速选样不先初始化声学模型。`试听发声` 才是实际有声按钮。用户脱敏报告中的 TTS 状态读取失败，以及历史原生生成 `NullPointerException` 分别记为待真机验证，不把当前样本报错当作后者已解决。
- Gemini：对照 Google 官方 OpenAI 兼容 REST 请求示例，将 `google.thinking_config` 移入实际请求体的 `extra_body`；仅在最终候选经过可选修正后呈现对应模型返回的思考摘要，避免先显示被弃用候选的摘要而最终正文没有摘要时闪退。摘要缺失依旧为空，不造人工思考。非 Gemini 自定义模型不加专用字段；服务商转发是否支持新参数须以真机验收。
- 判断型内部路由继续 `thinking:false`，只复用既有 DeepSeek 亲密路由返回的语义互动强度；五轮自然互相较劲的目标是本地上限映射，非模型随意决定 0～100 分。手动亲密开关继续旁路路由，无额外请求。
- 状态：`IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`；版本 `v0.42.7+251`，功能 head `13533d1f087850a6889ce34064697ae2629e9cbd`，tree `273be445c45007775272ca03533a35e4354ba571`。Actions `35952517475` 完整成功：126 项源码门、Kotlin、Flutter analyze/tests、arm64 Release、签名与包内资源门通过；Artifact `10789656940`，APK SHA-256 `a72f1a97d911495854af1b91336ab98892e512b46b7af8a97dbda92ab79b4a21`，未发布 Draft `untagged-8a0d0901c585b9b8f490`。CI 证明编译与自动门通过，不代表真机 TTS 原生空指针或第三方转发链路已修复。

- Jev 评估（研究，本版未集成）：`jevtypesafeai.com` 自称独立平台，明确声明未获 TypeSafe AI 背书；官方为 `typesafe.ai`、`docs.typesafe.ai`，官方调用是 `POST https://api.typesafe.ai/v1/systemone`。Jev choice/score/noul 适合短而明确的多项判断；中文调侃与关系上下文仍须用同批脱敏人工标注样本比较准确率、延迟和费用。当前气焰复用已有 DeepSeek 路由，单独迁移会增加网络调用。未接第三方平台、未新建密钥或上传私密对话。出处：https://typesafe.ai/ ，https://docs.typesafe.ai/introduction ，https://jevtypesafeai.com/ 。
- 余额汇总评估（研究，本版未集成）：DeepSeek 官方 `GET https://api.deepseek.com/user/balance` 可用对应官方密钥查询真实余额；玩游、Agnes、千问视觉、Tavily 与 TypeSafe Jev 的额度查询不能套用一个聊天接口，未证实其官方只读接口及当前 Key 权限者须标示控制台入口或明确为本机估算。未来“模型与联网”设置可分提供商手动刷新，显示来源与时间、失败独立呈现；Key 留在现有安全存储，只向自身核实的域名发送。出处：https://api-docs.deepseek.com/api/get-user-balance ，https://docs.typesafe.ai/api 。

### 6.25 v0.42.8+252 Jev 短判断试点与游戏结果复读（2026-09-24）

- 从 +251 已构建远端源码创建独立分支；保留 +251 五轮气焰语义判断、TTS 与 Gemini 修正。Jev 默认关闭，独立加密 OpenRouter Key，只负责普通聊天的一次组合判断（亲密描写深度 + 气焰交互强度）及沉浸房间的一次组合判断（场景深度 + 明确事件）。手动开关与确定性事件优先，Jev 不生成对白或记忆，不改 Gemini 最终回复。其他 DeepSeek 短判断尚未迁移。
- 单一 JevDecisionGateway 使用 OpenRouter Decisions typesafe/jev-1.13，每请求含状态与多条 choice；选择缺失、低 confidence、网络/鉴权/402/超时等返回 null，由原 DeepSeek Flash 不思考判断完整接管；取消不额外发兜底。只有费用/Token/耗时/失败类型的 120 条有界脱敏账本 jev_short_usage_v1，包括 OpenRouter 实际 usage.cost，不含问题或聊天正文。设置页面连接测试消耗少量额度；用户需验证真实误判与实际账单才扩大覆盖。省钱和准确率并非预设结论。
- 用户诊断/备份证明：同一份自测结果被 sins_virtues_answer_batch 与稍后的 sins_virtues_get_result 各自种植分享念头。结果快照读取不再生成新的主动分享 Thought，同时以 quiet 标记活动记录而不成为新的近期主动话题；真实完成新题与独立终局通知仍可分享；历史已入库旧 Thought 不删除。
- 余额面板另批处理：DeepSeek/OpenRouter/千问/Gemini 中转接口及凭据权限不同；此次只记录本功能产生的实际费用。验证顺序：126 个源码门、Flutter analyze/tests、Kotlin、arm64 Release、签名及 Draft，真机验证错 Key、402、停止、两路对照和旧测试结果不重复分享。CI 和真机结果必须分别回填。

- 最终 CI 交付证据：功能 head fa62d0c08aeb0597a874526c8015fecc4544c6f3；Actions 35961379029 全绿，源码门、Kotlin、Flutter analyze/tests、arm64 Release、签名和包内资源门通过；Artifact 10793156007，APK SHA-256 ee7fec22ff304d1c2e20f1da1cb32208f13a69ef4a798d4ab22826f87d725d52；未发布 Draft URL 为 untagged-247641dabd0b4c85691f。此前 e621f28 的 run 35960427181 虽全绿但尚未将读取旧结果的活动记录标为 quiet，已由本轮替代。只证明 CI，不代表 OpenRouter 实时调用、余额不足回退或游戏厅真机自然表达已验收。

## 6.26 v0.42.9+253 TTS 自检与五轮语义气焰（2026-09-24）

- 用户真机截图：TTS 资源未就绪、连接 Genie TTS 子进程超时，测速失败；自检页面与 TTS 页面同样等待状态。脱敏备份气焰已达 100。诊断中另有声学进程成功生成第一片段、第二片段原生 NullPointerException 与子进程退出，不能从这份日志证明空指针的具体代码位置或真机发声已经恢复。
- 快速自检读取主进程 APK manifest 并标注只验证资源，不绑定声学子进程；深度自检仍执行黄金资源校验和初始化。TTS 连接超时/死亡重置旧绑定与等待锁，下一次显式试听或测试能重新绑定，超时写入无正文脱敏诊断。
- 一键顺序无声测速两档，同一次固定回复、同一分段、同一批次才能比较与改变胜出档；失败独立记录代码并仍尝试另一档。试听发声是唯一有声按钮，复制专项报告保留。
- 气焰值继续使用 0～100；每轮 -10（另计自然小时衰减），轻度/互相/强烈主动玩笑分别 +16/+26/+28，认真话题再 -18。仅害羞、脸红、尴尬而未回敬时给 ordinary；满值五轮普通对话降至 50 并退出小豆丁。Jev 与 DeepSeek 的两组分类提示一致。备份与 Jev 脱敏用量只证明当时高位及部分低置信度兜底，不记录选项文本，不能断言具体回合是哪一路判定。
- 验证：源码门、Flutter analyze/tests、Android Kotlin、arm64 Release 和签名交给独立 CI；CI 与真机结论另行回填。声学空指针位置需要新包诊断或真机堆栈才能进一步收口，不用另一种音色/固定台词伪装成功。

- CI 交付：功能 head `5a8263efc925f32d80da6dc8af34aaf55cf97d71`；Actions `35974252470` 全绿，126 项源码门、Android Kotlin、Flutter analyze/tests、arm64 Release、签名及 APK Genie/素材校验通过；Artifact `10797768347`；APK SHA-256 `6f4a3c34f987f41c912e2427b8386ba6d70731e30ebf9537120a830db4cc3640`；未发布 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-7ba9838d3966a80f6d12`。该证据不等于真机发声、旧子进程空指针或语义体感已验收。

## 6.27 v0.42.10+254 语音音量、气焰和新库事故（2026-09-24）

- 用户新诊断 `2026-09-24T08-44-43Z` 属 +253 包；与 +252 的 `2026-09-24T06-40-13Z` 对比，`database` 身份和数据谱系同时改变，`stateGeneration` 由 183 变 0，记忆 422→0，会话 1→0，系统恢复计数和原生诊断也重新从零开始。这证明当前是新库，不能从重启后诊断查明清空动作或当次闪退堆栈；源码中 SQLite 数据库只在应用私有数据库目录打开，本批没有发现 TTS 删除该目录的调用。包内 `allowBackup=false`，系统自动还原不能当作恢复承诺。已知外部 06:39 存档必须保留原件，真机由用户确认后在应用内导入；严禁通过改安装包、清数据或新建空库“修复”旧数据。
- 新建库默认 `tts_enabled=0`、`emotion_sound_enabled=0`；+253 报告中 TTS 只有本地 APK 资源检查，没有声学生成或播放尝试。因此“自动回复没声”至少与丢失设置吻合，无法凭此诊断认定 Genie 播放引擎已损坏。恢复/打开开关后需试听一段普通聊天并导出新的播放专项诊断。
- 情绪 WAV 先前被标记 `USAGE_ASSISTANCE_SONIFICATION`，与 Genie 的 `USAGE_MEDIA` 分属不同音量策略。改为媒体 usage，主界面音量键目标固定到 `STREAM_MUSIC`。游戏内音量继续作为媒体音量之上的独立系数；需要真机检验手机媒体音量从 0 到 50% 再到 100% 时语音和情绪音效是否一致变化。
- 气焰的现行公式是每轮 `-10 + bonus`；旧 `light=+16` 实际每轮净 `+6`，确实会在普通玩笑里持续升温。现将 light 调为 +4、净 -6，ordinary 净 -10，mutual 净 +16、strong 净 +18，serious 净 -28；Jev 和 DeepSeek 双提示把 mutual 收紧为用户主动升级的互相挑战。5 轮 mutual 从 0 升到 80 的既有真值保留。旧 Jev 回退日志混合“低信心/格式无效”；新日志仅记录失败问题类型和状态，不记录对话、答案或概率，DeepSeek 回退不变。
- 回归边界：保留普通聊天、手动试听和一键无声对照三个入口；`app/test/playful_form_heat_test.dart` 增加轻微玩笑连续降温，历史音频验证门要求情绪音效和媒体流一致并有音量键路由。分支验证、CI/APK 和真机结论必须分别标注，不能以模拟测试宣称发声成功。用户对“扩充 Jev Noul/Score”还在讨论，本版没有改调用次数或按概率加热。
- 用户补充的图形参考：不是传统温度计刻度，而是上方独立发光的小爱心 + 细长暗色玻璃管，粉色液面按 0～100 气焰高度升降。`PlayfulHeatGauge` 的本地候选画法已按参考图重绘，仍保留轻弹额头、温柔安抚、形态锁定菜单及无障碍读数；需 APK 真机核对视觉质感。上线前用真实对话的 Jev/DeepSeek 分类观察 ordinary、light、mutual 的比例，再决定是否微调气焰参数；目前 +254 的参数只是待真机校准的候选值。

## 7. 历史验证兼容摘要

下列短语只为既有自动化门继续识别已完成阶段；权威细节在冻结归档，不代表当前任务重做：

- `v0.34.5+70`、`直接选择器 guard`、`冻结悬浮恢复`；`每小时最多 6 次`、`不暂停自主联网`、`电池优化白名单`；`v0.35.1+76`。
- `v0.39.5 新版妹居 TTS 运行时迁移`；`0.41.5+144`、`0.41.6+145`、`schemaVersion=41`；`v0.41.7`、`Memory Phase 1`、`Bad state: No element`。
- `Phase 1`、`误判不可接受`、`Phase 2 继续关闭`、`不合并 main、不发布正式 Release`；`Phase 2A`、`#D4BBFC`、`relationshipAge()`。
- `0.41.19+158 / schema 44 / snapshot protocol 5`、`动作与神态不是随机可选装饰`；`v0.41.20`、`stay_with_user_topic=0`、`CONVERSATION_AGENCY_PHASE2A5_v0.41.20.md`；`分享前重新阅读的核心是恢复上下文`、`恢复当前详细上下文`。
- `v0.41.22`、`schema 44`、`Phase 2B/3/4 继续关闭`。
- `Cedar 玩家协议与后台连续行动收口`、`Unexpected end of input`、`Cedar Agent 完整续接链`、`jsonRetryCount=58`、`CedarAgentActionPlanner`。
- `Cedar 后台换手闭环`、`根因已由同一时刻备份、诊断与源码三方证明`；`停止与备份互锁`、`transfer_lock_owner`；`Cedar 运行时抢占、开关与夜间节律`。
- 历史状态兼容：`IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING`、`CI PENDING / TRUE DEVICE PENDING`。

## v0.42.11+255 · TTS 运行链定点回退与气焰备份刷新（候选；真机未验收）

- 用户提供的 +254 脱敏诊断出现大量 `tts child_connection_timeout / bind_timeout`，一次已记录的 TTS 子进程异常；用户提供的备份内 TTS 与自动朗读均开启，最近错误为 `tts_generate_failed / call(...) must not be null`。这些证据不能单独确定子进程死亡的源代码位置，因此本批按用户要求将音频运行、双档测试与会话计时链退回到 +248 自动核亲和基线。保留后续已修复的 Android 媒体音量控制、Jev/聊天逻辑与气焰降温，不回退全应用数据结构。保留子进程连接超时后的清理和主进程轻量 `localStatus`；拒绝 Binder 空音频路径时提供明确错误。
- 语音页进入只读随包资源状态，不排队启动语音子进程。导入/校验/初始化操作直接展示实际操作返回结果，不再额外排一个 3 秒的状态请求。语音页只留一个真正生成并播放的「试听发声」，移除未验证的双档无声对照按钮与相关实验链。中文 RoBERTa 选择和导入期间显示阶段信息；若子进程本身仍无法启动，真机日志会直接反映超时。
- 真机前自检进入先读取轻量本机概况并显示，原完整诊断继续完成后替换概况；概况禁止导出为完整报告。快速状态不初始化 Genie/ONNX。完整与深度诊断入口保持不变。
- 用户 09:58 备份有 `playful_form_state_v1`，记录气焰 68；数据库恢复不排除该键。聊天页此前仅初始化或收到新轮消息时读取，因此导入后旧界面仍显示原数值。现在切回聊天、应用恢复时重读，并在聊天保持挂载期间每 2 秒核对一次；气焰数值依然是存档里的真实值。玻璃管、顶端爱心和填充随数值从原粉色 `−110°` 色相渐变至原粉色。
- 静态验证：`git diff --check`、Workflow YAML 与总账门通过；历史 125 个源门中 122 个通过。另三个分别需要 CI 恢复 417 个桌宠资源文件、LingChat 特效文件以及本机缺少的 `kotlinc`，不是本次业务断言失败。
- 风险与验收：本地不能运行 Flutter/Gradle 或复现目标手机独立进程崩溃；需要 GitHub Actions 编译、Flutter/Kotlin 测试，并在原手机验证：旧存档导入显示 68；关闭/打开页面均不长时间卡住；导入 RoBERTa 后「试听发声」实际听见、自动朗读也能出声。不能把源代码回退视为已经证明问题解决。
- CI 首轮 run `35986329658` 在 `Verify clean source baseline` 拦下旧版号 literal：Workflow 把构建标签改为 +255，却遗漏 `grep -Fqx 'version: 0.42.10+254'`。修正为 +255 后重新推送；首轮没有进入 Flutter/Kotlin 编译，不能算实编译失败。
- CI 第二轮 run `35986562701` 已通过全部源门、Kotlin 测试、Flutter analyze，Flutter 927 项中 926 项通过；唯一失败是 `agent_self_reader_v0416_test.dart` 固定预期 `build=v0.42.10+254`，实际 +255 正确。已同步测试预期并重新推送；第二轮未进入 Release APK 打包。
- CI 第三轮 run `35987574373` 成功：125 个源码门、Kotlin 测试、Flutter analyze、Flutter 全量测试、Release APK 编译、固定签名与 APK 模型/桌宠/塔罗资源校验均通过。功能源码 head `4c2101f529fbaf4f6fe7b2289aaea48153e65b34`，tree `fe8a3f0e081a66b77681eaf527340e6f664a117b`；Artifact `10803376064`；私有草稿 Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-943842dd3eb416b00021`；APK SHA-256 `170be5edc6a2ee55a2431fc289a14b6acc4551ef74bacec19ee7e1f4e4692487`。`TRUE DEVICE PENDING`：本次完成构建不能证明用户手机独立 TTS 进程已恢复播放。


## v0.42.12+256 · 双向 Jev 气焰、端点切换与双形态音调（候选；2026-09-24）

- 决策：仅气焰到 100 时本体进入小豆丁、到 0 时小豆丁恢复本体。认真求助不触发单独的人设切换，也不在角色提示中额外要求突然变得严肃；本人的内容依旧由原有伴侣设定和对话上下文负责。用户此前确认 +255 的 TTS 播放、气焰均可用，保留该音频核心和唯一「试听发声」。
- 输入端：原有 Jev/OpenRouter 组合短判断继续按当轮用户真实表达选 serious/ordinary/light/mutual/strong；serious/ordinary 均无加分；light +6、mutual +30、strong +42。本体每轮自然 −2，实际净变化依次为 −2/−2/+4/+28/+40；小豆丁每轮自然 −15，实际净变化为 −15/−15/−9/+15/+27。时间空档沿用每小时 −3（最多 12 小时）。普通害羞、友善、口头关怀不自动算玩闹；温和笑话也不会让小豆丁持续涨温。一次明确互相挑衅从 0 需约 4 轮入形；100 起普通交流约 7 轮回到 0。端点夹取 0～100；锁定形态的手动选择仍按原入口执行。
- 自主端：同次预回复 Jev 组合判断新增独立 initiative=open/closed；仅在 open 的回合，用由 turn ID 决定的固定 30% 抽样给主模型一条可忽略的主动轻玩笑提示。抽样自身加分为 0，重试不换抽样结果。回复生成并定稿后，另一笔 Jev Choice 根据用户文本、少量近期上下文和**实际可见回复**判定 none/playful/strong/settle，分别额外 0/+16/+24/−8；复制、温柔、脸红、认真解释不算主动挑衅。仅在回复赢得数据库提交后结算，保存 assistant ID 使重复回放不二次加分。初期不使用随机数直接加热，也不让模型自行报出数值。
- 所有短判断的 Jev 缺 Key/未启用、答案缺失/不确定、网络失败、402、超时与格式异常，均由现有 DeepSeek Flash 不思考模式判断同一组问题或同一最终回复；取消直接停止兜底。两方都失败时用户输入不给正增量，自主端不追加分，回复本身照常提交。Jev 输出为离散选项，不把模型生成的任意数值直接写入存档。诊断沿用只记 lane、耗时、用量与失败类别、不存正文或选项的有界记录。OpenRouter 截图单次约 $0.000070～$0.000081，用户明确优先反馈及时、成本可忽略；新回复后判断会多一次网络等待，需要真机测端到端延时和回退比例，再决定是否合并请求。
- 状态并发：气焰、形态、回合 ID 与手动交互统一在 SQLite 设置键里事务读改写，避免等待 Jev 时覆盖用户按键或相邻回合；原备份键 `playful_form_state_v1` 不变。音调沿用 +256 的每次播放前形态读取：小豆丁用设置选中的原值，本体降 1 半音（设置 0 则 0/−1）；仅使用既有音调调整链，不动子进程、绑定、ONNX、语音队列和无声测速。
- 验证关注：单元测试覆盖正常趋稳、入形仅在 100、Q 形七轮自然归零、真正挑衅快速升温、认真求助仍是当前形态、回复定稿一次性加分、决定性抽样、Jev 成功及余额不足后的 DeepSeek 兜底；历史源码门因硬编码版号 +255 拦截须兼容 +256 后再跑 Flutter analyze/tests、Kotlin、签名与 arm64 APK。构建状态 `CI PASSED / APK READY / TRUE DEVICE PENDING`。功能提交 `f107a48578d761ac4722256a23bfee1adb343c2b`，tree `6d034edc1f7e73472c43bf5dd7bfee8ab3e2c312`；Actions run `36002099038`：125 项源码门、Kotlin 测试、Flutter analyze/tests、Release APK、签名及包内 Genie/桌宠/塔罗资源检查全绿；Artifact `10809520556`；未公开的 Draft Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-c851c83a1c515da6746d`，APK SHA-256 `739c86422711e1eedabf15594543abaf300b3c39d77c9a3822ee3a8c9120a289`。真机重点验证两种形态连续聊天、主动玩闹、未填 Jev Key/余额不足、音调和发声；CI 结果不能代表真机已验收。


## v0.42.13+257 · 双房间气焰与可回看的工具调用（2026-09-25，候选）

- 用户提供的 +256 私密备份只有最新状态快照：2026-09-25 01:44（北京时间）气焰 49、小豆丁形态、未锁定，lastTurn/lastAssistantTurn 均已保存；诊断中 Jev chat_playful_self used 5、low_confidence_self 3；chat_intimacy_route used 13、low_confidence_interaction 10、历史合并旧 low_confidence_or_invalid 5。现有诊断没有逐轮分类结果／值变动，备份也没有逐轮气焰流水，**不可由此断言是哪句话让气焰上升或下降**。不向公开仓库提交私密备份或诊断原文。
- 停止问题证实：普通聊天 PromptBuilder 在回复生成前写入用户本轮的气焰变动，用户按 Stop 会删除尚未提交的用户消息、留下仅供 UI 重编辑的中断展示；先前没有归还气焰。沉浸房间同样会撤回未完成用户消息。修复：状态记录本轮结算前热量/形态及上一回合；只有最新未提交回合且未被后续回合/手动形态操作取代时才允许还原；撤回普通或沉浸用户消息和还原气焰放在**同一 SQLite 事务**。已提交回复不能被较晚的 Stop 回滚；备份继续使用既有 `playful_form_state_v1` 键，兼容旧存档。
- 两房间仍保持各自聊天正文、小说现场和事实边界；共享同一个 PlayfulFormStore。沉浸回合单独用一次 Jev Choice 批量选 interaction/initiative，Jev Key 未配、402、网络/格式/低置信度转 DeepSeek Flash 不思考判断；复用普通回合 −2/−15 自然降温、加分枚举、0/100 切换。沉浸 Prompt 加载相同形态提示和轻量自主开玩笑机会，小说视角规则不变；实际可见回复经 Jev→DeepSeek 判断其自身玩闹，最终回复成功提交后才加自主分。沉浸 UI 读取相同气焰、共享玻璃管与手动互动，并以相同 qForm 选静态立绘；TTS 每次播放继续从同一状态读形态，不复制音调设置。草稿重试不重复结算用户回合；用户确认截断回复时按 none 完结临时回合。
- 工具历史：工具的 user-facing displayText 之前只通过运行时 callback 显示，`agent_tool_outcomes` 只保存调用次数／状态／时间，因此对话结束或悬浮窗刷新后丢失可读细节。现在用 200 条有界独立设置记录实际已展示的 displayText（每项至多 800 字），仍保留原有脱敏 Outcome 表；普通聊天从真结果读取并显示灰色高透明工具面板，悬浮窗也随消息加载并可展开查看。只写用户可见短文，不记录 promptData、工具参数、模型思考、密钥或诊断正文。沉浸房间没有 Agent 工具执行链，继续保留其工具权限边界；不能伪造不存在的工具调用，后续若单独授权为房间接入工具，必须先按总账唯一 continuation owner 设计调用/停止/存档。
- TTS 双档性能对照后续单独做，不在本批动已经恢复的发声链。先保持 +255 的自动核亲和运行、单个「试听发声」、轻量状态与原子诊断；未来对照在同一用户真实回复／音色／语言／分段上明确手动启动，串行无声生成两个档位，分别冷启动并记录核、PSS/RTF、每片段计时、子进程绑定/死亡和缺段；只在同批、两档都有效时比较，不在模型未就绪或播放失败时给出胜出档。另存最近两轮**真实播放**（不同形态）速度，用户可直接区分听感与纯推理测速。前次双档测速改动后真机出现子进程连接超时、资源未就绪、原生空指针；+255 回退到此前音频运行链后用户确认可发声。诊断只能证明故障与新增测试链共时，**没有证明**是哪行代码引发原生异常；下次须沿独立最小探针和真机栈定位，不靠恢复已撤的双档按钮猜测。保护固定签名、资源校验、媒体音量流和存档键。
- 预期验证：停止前后气焰、已提交后 Stop 不回滚、手动形态动作不被旧回合覆盖；跨普通／沉浸连续涨跌和 UI 立绘一致；无 Jev Key／402 的 DeepSeek 兜底；工具活动实文在普通和悬浮窗完结、重开后仍能展开；TTS 现有真人发声不回归。当前 `CI PASSED / APK READY / TRUE DEVICE PENDING`：Actions run `36041874888` 完整通过 125 项源码门、Kotlin 测试、Flutter analyze 与全量 tests、Release APK、固定签名、Genie/桌宠/塔罗资源核对；功能 head `84ec9af1dd4df93bb4b36b46d03d2fe794aadfe3`，tree `0226ce2225d28c9aead68855b4bcda69e31d46cc`；Artifact `10827521660`；未公开 Draft Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-d0809bb1e451a9b07625`；APK SHA-256 `be0d5f7a40f8ae5c5dd610e4a80d62fec9c1d4bdf25e5130b5908eda7b8b47bf`。真机仍需逐项核对：停止前后热量、跨房间立绘与数值、Jev 失败后的 DeepSeek、工具实文完结与重开、现有 TTS 真人发声；CI 不视为真机验收。

## v0.42.14+258 · 可回看的规划过程与本地命运之轮（2026-09-25，开工登记）

- 证据：+257 已持久化工具的 user-facing displayText，但截图中的 `THINKING` 是 DeepSeek `reasoning_content` 的实时流，工具运行状态是另一条链。`generateInternal` 会向界面转发规划推理，最终消息却只保存最后一次 `generated.reasoning`；跨规划回合的真实可见推理在提交后丢失。普通聊天已有 ReasoningPanel，悬浮窗有独立渲染。双模型模式会抑制内部规划推理的实时转发。用户明确要求两边可看到并在完成后回看实际呈现的内容，不以“工具活动”短文代替。
- 上游冻结：`https://github.com/29-Cu/Ruota-della-Fortuna`，commit `8d62036de5c3e0cdb18ac082c77a7051b55ce43a`，MIT；独立页面 `index.html` 内嵌 DIMS 与 `src/tags.json` 内容一致，7 维共 502 标签（其中 GORE 62，初始锁定）；独立 `Math.random()` 等概率选中每个启用维度并支持单列重抽。CSS/SVG/Web Audio 实现暗金机器、灯框、卷轴、拉杆与结果卡。用户要求保留这些视觉与动效，以本地 Flutter 重建而非 WebView/服务端/MCP。
- 产品合同：抽取是完全虚拟的幻想装置。用户在轮盘界面确认最终结果后才绑定新沉浸房间；结构化结果与上游版本持久化，给模型的房间提示只列选中标签与虚构规则，允许超现实混搭、分幕展现，不要求现实物理一致，也不把未输入的用户动作、台词、同意或态度写成事实。房间之外的记忆、AI Self 与自主 Agent 不因结果改变；后续房内重抽沿同一 Outcome 扩展，首版不另建循环。
- 保护边界：不增加模型调用或改变 DeepSeek 内部/Gemini 最终回复计费链；存储给用户实际可见的推理，但不得泄露私密 Prompt/密钥或将过程注入模型历史/公开诊断；失败与 Stop 不伪造成完成结果；不改 TTS、Cedar 游戏规则、形态温度、Live2D、`main`、正式 Release 或用户旧房间。保留上游 MIT 声明并审核字体许可。
- 验证门：单/双模型的规划流、工具 Outcome、最终回复三段显示与重开后回看；Stop、崩溃恢复、重复轮次不乱序；轮盘多维启停、均匀取样与单列重抽、默认 GORE 锁、确认前无房间注入、确认后房间隔离、进退场、备份恢复；Flutter analyze/tests、仓库 validator、Android release、固定签名与 APK 真机外观/动画验收。当前仅开工，`CI PENDING / APK PENDING / TRUE DEVICE PENDING`。
- 实现（本地，未完成 CI）：`VisibleReasoningTranscript` 按完成的规划回合和最终回复收集真实 provider reasoning，内部 DeepSeek 规划在单/双模型中均实时展示并 checkpoint，提交后沿现有 `reasoning_content` 在普通聊天与悬浮窗回看。历史提示构造不重放 reasoning；工具 Outcome 仍使用独立的 +257 附件。Gemini 最终仅显示被接受的 reasoning。
- 轮盘（本地，未完成 CI）：复制上游 `src/tags.json` 502 条、LICENSE/NOTICE；纯 Flutter 灯箱、暗金机身、七轮停靠、拉杆、单轮重抽和 GORE 解锁确认；只有确认抽签再填写房间表单后才创建房间。JSON 中保存源 revision 和选中维度/标签于房间 `entry_context`，房间顶部可回看；系统背景将其解释成幻想装置的创作素材，允许超现实搭配，不伪造用户行动或同意。不新增模型调用、独立循环或 schema。原创字体和网页音频未移植，待真机对照视觉精度。
- 本地验证：`git diff --check`、JSON 内容计数（7 维 / 502 标签 / 单一 GORE 锁）通过；125 项校验清单结构通过，前 24 项通过后因稀疏检出缺少仓库原有 `dafeiyu_reference.webp` 而停止，不是功能失败。Flutter SDK 不在本地，需完整检出的 CI 执行 analyze、test、release APK。`CI PENDING / APK PENDING / TRUE DEVICE PENDING`。
- 远端验证（2026-09-25）：功能 tree `6efaa1d699cc73f92b9108f1e220e990db2f17e8`，GitHub head `001c3cf43883032b47ce0224259777c15ce45c27`；Actions `36094383066` 全绿，125 项源码校验、Kotlin 测试、Flutter analyze/test、release APK、固定签名/资源核验全部通过。Artifact `10846946684`（14 天），APK SHA-256 `3fab6379553866a1bc3a4b61a5fde1b0a6dbcd1cfe450d8eb149e0e63d720efa`；signer `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。未发布 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-478e1a10f9514d22b372`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`；真实设备尚未校验轮盘像素/手感、普通聊天与悬浮窗跨回合过程显示以及房间续写。

## v0.42.15+259 · 原版命运之轮视觉回归（2026-09-25，开工登记）

- 用户截图证据：网页为完整黑金主题、Rye 装饰字发光招牌、七轮三行窗口同屏、四边动态跑马灯、独立 GORE 翻盖、圆形 SPIN/竖向拉杆、自定义标签和搜索。+258 的 Flutter 仿制版用了紫色横向滚动单行标签轮、扁平滤镜片和小拉杆，关键比例与动效均不一致。先前回答“能够按原样画出”未兑现，用户质疑后明确选择直接复用原页面外观代码。
- 本轮目标：本地离线嵌入原版冻结提交 `8d62036de5c3e0cdb18ac082c77a7051b55ce43a` 的 HTML/CSS/JS；只加入可见的“确认结果并创建沉浸房间”入口和安全数据桥。保留原有灯框、卷轴、停靠动效、拉杆、GORE 翻盖、Add Tag、Search、History，并让页面字体可离线使用。轮盘仍不运行 Agent/模型或外部服务器，房间只读取用户确认的有限字段；从 +258 沿用结构化房间设定，不动聊天 THINKING、TTS、Cedar 或 schema 61。
- 验证路径：原网页代码与打包页面的差异限于离线字体、App 结果桥与作者署名链接；检验桥消息格式、维度/标签匹配、确认前不创建房间、WebView 外部导航隔离及持久化。Flutter analyze/tests、125 项验证、APK 签名和上机视觉/动效仍各自区分；远端结果见下。
- 用户同轮补充：沉浸房间页面底部必须和普通聊天一样展示“她／聊天／更多”三个导航按钮，并让这些按钮能真正回主界面相应标签；输入框左侧增加“推进”按钮，单击只令现有剧情自然推进一个节拍，不生成固定台词、不记录为用户扮演的动作或许可。实现需使用已有沉浸房间请求、Stop 与独立现场账，不开第二续写循环；按钮引发的控制事件需在时间线与模型提示中与用户原话区分，不能更新用户身体互动的气焰值。
- 本地实现：打包 `index.html` 原始机台和 3 款 OFL 字体，WebView 只加载本地页面并将确认后的选中标签通过受限桥传回 Flutter；允许原作者署名链接由 Android 浏览器打开。普通聊天与房间大厅、房间内共用相同底部 NavigationBar，离开活动房间按原有流程暂停。推进作为保存在时间线的房间控制事件送入现有生成链，跳过用户肢体捕获、用户轮人格判断和用户自主行为推断，停止的控制事件不显示为用户消息；下一轮模型历史明确标注该操作不代表用户发言或同意。
- 远端验证（2026-09-25）：功能 tree `18b856e14a573a844bc6a3f1afef1b655997b1f1`；GitHub 功能 head `d580ed694ef9ae75017e1c231d95eb59033d0fd1`；Actions `36105651518` 全绿：源码校验、Kotlin 测试、Flutter analyze/test、release APK、签名、既有资源核验均通过。Artifact `10851237002`（14 天）；APK SHA-256 `a2316fa38b323ec725323186d32df019e0cda914a0649c130cc835f9a4ce4fac`，签名指纹 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。未发布 Draft Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-c2d726ee49c01198c248`。状态 `CI PASSED / APK READY / TRUE DEVICE PENDING`；手机端仍需确认原版轮盘的像素与动画、WebView 本地标签存储、导航跳转、推进生成质量。

## v0.42.16+260 · 房间导航、思考分段翻译和轮盘振动（2026-09-25，开工登记）

- 用户决定：沉浸房间底部中间显示“房间”且选中后不用重新导航，左右两端仍能去主界面；去掉人工添加的“【规划 N】”标题，仅展示 DeepSeek 实际返回的过程文本；翻译应分别判定规划和“【最终回复】”的英文比例，仅翻译英文占优的段落。确认在线轮盘已在每轮停靠调用 `navigator.vibrate(18)`，Android manifest 缺失 `VIBRATE` 权限。
- 现有账本与代码证据：+258 之前就有“DeepSeek 工具规划，无工具后再由第二通道回复”，+258 只是把已有规划过程显示出来；只要 Cedar 已配置，旧 `cedarStageToolIds()` 对任何普通聊天均返回 `gatewayToolIds`，为零游玩需求的闲聊附加游戏厅工具，导致备份末轮零工具仍先调用 DeepSeek。修复此确定性门：仅本轮游玩意图、共玩待接续，或本轮确有 Cedar Outcome 时暴露游戏厅工具；其余按现有相关工具路由，不加额外 Jev 网络请求。
- 实施与验证：在新功能分支补齐 Android 振动权限、导航选中行为及文案；只清除新消息上人工规划编号并兼容旧存档文本；规划英文占多时翻译完整思考链，否则最终回复英文占多时只翻译最终回复，保留原文与整个记录的缓存身份。保留原网页动画与逐轮 `buzz(18)`，不凭模拟器/CI 声称已证明真机手感或帧数；完整 CI 构建可供实机核对。schema 61 与备份协议不变；不合并 `main`、不发布正式 Release。
- Jev 专节（2026-09-25 的源码与官方文档核对）：现有 `JevDecisionGateway` 在 OpenRouter Decisions API 发送最小 `state` 和多个独立 Choice，验证答案/信心后使用，否则调用原 DeepSeek Flash；`PlayfulTurnJudge`、`ImmersiveNsfwRouter` 已实装，不复用聊天完成接口。官方 Jev 是结构化决策而非生成文本，Choice／Score／Noul 可在同一请求中并列短问题；官方强调各问题聚焦一个判定，复杂权衡拆问、由代码组合。适合对话意图分类、闭集工具候选/场景路由、主动消息是否适时、情绪或房间事件评分（需验证本项目真值）；不适合继续剧情、生成答复、核验 Cedar 合法动作/真实 Outcome 或单纯读设置/计数。置信度是分布集中程度，不代表具体场景正确率；每项新增任务须有独立标注样本阈值、误判代价、脱敏用量、费用和延迟对照，且 **DeepSeek 为任何 Jev 失败/不确定的必经兜底**。本轮游戏厅误开启是明确布尔条件，直接在代码中修复；若后续希望让 Jev 负责模糊的“是否值得进入 DeepSeek 工具规划”，先在影子对照验证对自然游玩、联网和记忆请求的漏判，再在启用时落地 DeepSeek 兜底，不能用一个低信心的“闲聊”吞掉真实工具意图。官方出处：https://docs.typesafe.ai/introduction 、https://docs.typesafe.ai/api 、https://openrouter.ai/typesafe/jev-1.13/ ；本项目现有路线详情参看上文 §6.25。
- 本地实现：中间导航“房间”和门图标，选中中间项不离开房间；新消息与流式规划不再添加编号；翻译遵循用户两级判定并支持旧存档；仅游戏请求/待续共玩/实际 Cedar Outcome 暴露游戏厅工具，普通闲聊已配置 Cedar 时不触发 DeepSeek 规划；Android manifest 补齐 `VIBRATE` 供网页现有每轮停靠震动调用。新增独立翻译分支与 Cedar 空工具门回归测试。
- 本地验证：总账交接校验、Agent v2、图像可靠性、主观搜索回归和 `git diff --check` 已通过；第一次 Actions `36117923678` 在旧 +219 静态契约校验第 99/125 项失败：它硬编码要求 `cedarStageToolIds()` 直接引用旧的常驻 gateway/engaged 字样，与本轮修复冲突；更新检查为实际 `toolIdsForUserTurn` 行为和回归测试后重跑。Flutter analyze/test 与 Android APK 交由完整远端 CI；原网页视觉、动画帧率、振动强度仍需真机。
- 远端验证（2026-09-25）：功能 tree `3ad68dd178bd6d474bb534038ecf829bd2ef426b`，远端构建 head `156743912284dd896434857ce46f32e8cc6364f5`；Actions `36118441665` 全绿：125 项源码校验、Kotlin 测试、Flutter analyze/test、release APK、签名和资源核验均通过。Artifact `10856307246`（14 天）；APK SHA-256 `607a2d1c84546b0f2364e47f8db1e049f77c1ed8908778fdbc9f01ac5088fb8f`；签名指纹 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。未发布 Draft Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-c92a839f0ea079a1b17c`。状态 `CI PASSED / APK READY / TRUE DEVICE PENDING`；手机仍需检查逐轮震动、动画流畅度、翻译分段和真实零工具回合的用量变化。

## v0.42.17+261 · 满气焰触发与命运之轮细节（2026-09-25）

- 双形态：本体自然达到 100 时只蓄势，下一次真实用户消息是一次触发判断机会。Jev 阅读最近 3～5 轮和本轮消息，按最新互动是否让她明显绷不住选“触发／等待”；Jev 不可用、不确定或失败时 DeepSeek Flash 同题兜底，两者均失败不消耗机会。触发时先更新共享状态和角色提示，再生成回复；若否，这轮保持满值，其后正常衰减。严肃求助不能作为触发。弹额头仍直接变身，安抚、锁定与手动按钮不变；小豆丁只有 0 自动还原。普通聊天与沉浸共用状态，Stop 回滚蓄势与形态。
- 视觉：真实切换到小豆丁时立绘跳两下，不加烟雾。命运之轮 WebView 关闭 Android 边缘拉伸和可见滚动条，仍可正常上下滚动；网页默认声音开启，在首次手势音效时创建 Web Audio；跨卷轴重复 tick 限速，跑马灯仅更新实际变动的灯泡，保留原机台外观与逐轮振动。帧率改善需同机对照网页和 APK 验证。
- 验证：状态和 Jev/DeepSeek 兜底专项测试、JS 语法、总账门、Flutter Analyze/Test 与 Android Release 已由 Actions `36138316955` 全绿确认；真机观察普通／沉浸跨房间、Stop、锁定、双跳、声音、拖动边缘及帧数。状态 `CI PASSED / APK READY / TRUE DEVICE PENDING`。
- 构建交付：GitHub 构建提交 `3a9fd3091970ba132e9261575f212f709ee32613`，内容树 `66eb5939a2cc3bd013b508ebc24998587dd71bf6` 与本地提交 `d85d2f5` 完全一致；Artifact `10866132151`（14 天），Draft Release `396618220`，APK asset `588394207`，大小 `546205928` bytes，SHA-256 `2d5ccfc8d3508c093b11c60759cf12c9e46e07e128b1ccbf7ef23c997e21c4a7`。草稿页 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-d10092c51d058bdfdfb3`；未发布正式 Release。

## v0.42.18+262 · 主动聊天最终通道、满气焰持续判断、轮盘虚拟卷轴（2026-09-26）

- 用户澄清：自然升到 100 的当轮不判断；至少短暂保持一轮 100。此后只要本体仍在 100，每条真实用户消息都可让 Jev 判断突破，Jev 不确定或失败时 DeepSeek 兜底；判断“等待”不直接扣到 85。持续互相玩闹把数值维持 100，就应继续判断；一旦普通交流实际降到 100 以下才停止。旧存档若在 100、非小豆丁且 `breakthroughReady=false`，下轮也要恢复判断。突破语义提示暂不放宽，先真机观察。
- 2026-09-26 01:39 用户备份与脱敏诊断证据：最后状态 `heat=100/qForm=false/breakthroughReady=false`；此前约 01:31“晚安”一轮有唯一一次 Jev `playful_breakthrough` 用量，此后数轮打趣没有再次调用，因旧代码把第一次等待当成永久用尽机会。当前数据库状态不外传、私密正文不进公开诊断。
- 主动聊天：仅此回复路径在双模型设置下将现有内在状态、已选来源、真实 Outcome、时间和语境合并后一次交 Gemini 写可见正文；DeepSeek/Jev 仍负责已有内部短判断、维护与工具。Gemini 缺 Key、网络/格式错误或中途截断时用 DeepSeek Flash 自然生成；事实校验需重答时只由 DeepSeek 纠正，不第二次向按次计费的通道请求。保存最终实际生成模型和其真实 reasoning，英语摘要不再丢弃，沿普通聊天的思考链翻译入口按需翻译；没有独立 DeepSeek 规划回合时不伪造规划思考链。单 DeepSeek 设置保持原流。
- 轮盘：真机反馈 APK 明显掉帧、手机浏览器原版较顺畅；本地代码的每卷轴按标签集复制至少八份，七卷轴合计产生很长的运动 DOM/合成层，同时 SVG 灯带逐帧动画滤镜、机台灯频繁切换发光阴影。改为每卷轴固定五个可见/预备 cell，按跨行更新文字，仅对短 strip 做 transform；停止中心仍与抽签结果对应，保留文字/灯箱、拉杆、单列重抽、默认音效和每列停靠振动。移除卷轴运动 blur 与灯带逐帧滤镜脉动，把跑马灯运动更新从 55ms 降为 95ms。此为源码判断，不声称已证明特定 Android WebView 的 GPU 瓶颈或真机帧率收益。
- 验证：`git diff --check` 和打包 JS 语法通过；Node 卷轴运动探针按 1、2、7、50、90 个标签核对五格 DOM 数量和停止中心选中值。仓库 125 项验证在稀疏检出下第 27 项因未检出 417 件桌宠旧素材停止，前 26 项通过；本机无 Flutter SDK，Flutter analyze/test 和 release APK 待完整 CI。schema 61、备份协议、普通/悬浮/沉浸正文、Cedar 游戏房间、TTS、Live2D 不变。状态 `IMPLEMENTED LOCALLY / CI PENDING / APK PENDING / TRUE DEVICE PENDING`。
- 首次完整 Actions `36171693729` 在第 86/125 项遇到旧 +209 静态断言（主动引擎不得读取第二通道 Key），它与本轮明确的新路由相矛盾；前 85 项通过。把该断言改为检查 DeepSeek 内部 Key、双模型开关、Gemini 只尝试一次以及 DeepSeek 兜底，本地单项通过，待完整重跑；不是实际 Flutter 编译错误。
- 最终远端 head `3aa281d25bbc50ba174c2b145d5e08b6423127a2`；Actions `36173105843` 源码回归、Kotlin、Flutter analyze/test、release APK、签名和资源核验全部通过，Draft Release 上传成功。Artifact `10880534317`，APK SHA-256 `7d869d4d678cd82d9dddeb3f1624658c9633a48fbe5e91aeab4f532a384cc083`；Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-454347b060d2df3185c9`。上一轮 Actions `36172168049` 因修正发布名称的新提交而取消，不能当成测试失败。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`；待真机观察满气焰连续判断与自然变身、主动正文模型及思考翻译、命运之轮帧率和停靠/振动。
- +262 真机回报（2026-09-26）：七列卷轴优化明确生效，视觉无明显损失；自然变身测试未见问题。变身标记 `TRUE DEVICE PASSED`，卷轴视觉与性能改善已确认，但流畅度仍待进一步验证。页面下方点击搜索/自定义标签输入框时输入法弹出仍慢，尚无逐帧数据；本轮只读核查：Android Activity `adjustResize`、Flutter Scaffold 默认随键盘缩小 WebView，HTML 同时使用 `100vh`、固定背景/全屏暗角和常驻灯光，可能让键盘动画期间反复布局与绘制；搜索框空值 focus 不执行标签搜索。后续若值得优化，先分别测系统键盘启动与 WebView 视口变化，优先试焦点期间暂停跑马灯/灯带及减少固定背景重绘；不得直接全局关闭 `adjustResize` 以免下方输入框被键盘遮住。主动聊天 Gemini 正文与思考翻译仍待真机确认。
- +262 后续真机澄清（2026-09-26）：用户观察到慢的是系统输入法从底部上滑的动画，轮盘页面在同一时刻帧数较高；不得把该现象直接判作网页掉帧或焦点搜索开销。打包轮盘 HTML 无 canvas/独立粒子系统；可见动态光效是 44 个边框灯泡、SVG 标题灯带和少量 CSS 发光/脉动。删除所谓“粒子”不构成明确优化点。下次若处理键盘，须分别测 IME 动画、WebView 平台视图合成与页面重排；优先做受控对照，不凭推断改全局输入法或删掉外观。
- +262 再次真机澄清（2026-09-26）：同一网页在手机浏览器里卷轴与输入法动画都非常流畅；App 内卷轴虽明显提升、外观无损，仍远未达到流畅，输入法展开持续而明显变慢（展开途中可使用），属于性能 `PARTIAL / NEEDS INVESTIGATION`，不能把上面的“卷轴已优化”误记为完全真机验收。源码确认为原 HTML 经离线字体/结果桥和卷轴虚拟化改造后由 Flutter `WebViewWidget` 加载，Android 硬件加速开启，未设置页面帧率上限；插件默认 Texture Layer Hybrid Composition（WebView 渲染到纹理再交 Flutter 合成），与浏览器直接显示存在明确架构差异。键盘期间 `adjustResize` 和默认 Scaffold 缩放整个 WebView；持续变慢而不冻结说明需要记录真实 IME 动画时长与各层帧时，不能只凭视觉归为页面掉帧。后续先对照同一 APK 内原生 Android WebView / 当前 Flutter WebView，再在隔离测试包比较插件的 Hybrid Composition 与当前纹理模式；测量 JS rAF、WebView/Flutter 帧时、输入法开始到结束的时长。不要先删光效或切全局输入法模式。变身真机测试仍无问题；主动 Gemini 回复待测。

## v0.42.19+263 · 同页原生 WebView 性能对照（2026-09-26）

- 开工依据：用户同机对照发现浏览器原 HTML 卷轴及输入法均流畅，App 内经 +262 虚拟卷轴改善仍未流畅，IME 展开持续但显著变慢；允许试用另一种 HTML 承载方式。优先检验 Flutter 平台视图合成这一具体差异，不先删特效、关闭键盘调整或重写轮盘。保护边界：保留现有 Flutter WebView 作为基线；原生路径加载同一打包 HTML 与字体、沿用原 JS 确认协议及 Dart 的七维校验；返回现有模式不丢当前结果，未确认不建房；不改普通/沉浸聊天、模型、TTS、人物或备份。
- 实现：轮盘 AppBar 增加“原生对照”，开启独立 Android Activity 的 WebView；原生顶部返回可回到当前 Flutter 版，确认抽签后经专用 MethodChannel 返回原 Dart `FateWheelResult.fromBridgeMessage` 校验再建房。两条路径使用相同 `file:///android_asset/flutter_assets/assets/fate_wheel/index.html`；原生禁用越界反馈/滚动条并保持 `adjustResize`，只许可本地页面导航，外部署名用系统浏览器。以隔离对照为主，不凭代码声称流畅度已提升。
- 验证计划：本地源码范围、JS 和总账门；完整 CI 的 Kotlin/Flutter 分析、测试、APK 签名与资源校验；真机分别测旧入口和原生对照的转轮顺滑、输入法完整展开耗时、搜索/自定义标签、静音、单列重抽、确认入房与返回。若原生显著更顺，再讨论设为默认；若两者都慢，检查 WebView Provider 和页面本身。
- 构建结果：本地提交 `50b860c`，远端同一 tree `45e40af287ba1554c5004bcfd0d51c7859f6e526` 的提交 `9cff7c2845a1c04379dd8adfc48e07a1c2512c2b`；完整 Actions `36181810605` 的 125 项源码检查、Kotlin 测试、Flutter analyze/test、Release APK、签名与资源校验全部通过，Draft Release 上传成功。Artifact `10884699335`；APK SHA-256 `8976dd8be4443325f4148c230686ba5d4ea05a273794062ff8bef70f179780b2`；Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-405b62659a85f46c2693`。本地 125 项前 26 项通过，第 27 项因稀疏检出缺少既有 417 件桌宠资源停止，CI 在恢复完整资源后全部通过。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`；仍需真机确认原生页面实际性能与键盘动画、确认入房及返回。

## v0.42.20+264 · 原生轮盘默认化与历史记录展开（2026-09-26）

- 真机依据：用户安装 +263 后确认原生对照明显更顺，输入法展开恢复正常；指定将原生路径设为默认、删除旧 Flutter WebView 对照和顶部返回/对照栏（手机返回键退出），历史记录默认展开。+263 的源码/CI/APK 通过；其原生转轮与键盘性能标记 `TRUE DEVICE PASSED`，确认建房/全部边缘操作仍待本批复验。
- 范围与保护：沉浸大厅入口直接开启独立 Android WebView；同一打包 HTML、标签、音效、单列重抽、JS 确认协议及 Dart 结果校验不变；取消返回只返回大厅且不建房。删除旧 `FateWheelPage`、其 Flutter 插件依赖与对照顶部栏；不修改全局 IME 模式、其他 WebView（若有）、人物/模型/TTS/游戏。网页历史记录初始面板与箭头为展开状态，仍可手动折叠/清空。
- 验证：核对唯一入口/无旧 WebView 引用、HTML 历史展开标记与校验桥；CI 源码、Kotlin、Flutter、APK 签名与资源核验；真机检查全屏顶部、安全区、返回键、历史记录、确认建房与原生性能。
- 构建结果：本地提交 `4793129`，远端同一 tree `0e36ee794d1f15596797e4ad75aa579470af657d` 的提交 `d6b46d0c5c8b07c66ab4dc801ad7f1eb3b4ce1cf`；Actions `36186064758` 的 125 项源码检查、Kotlin 测试、Flutter analyze/test、Release APK、签名及资源校验全部通过。Draft Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-b0f4bd22f8a953143130`；Artifact `10886706105`；APK SHA-256 `3d9ed89b830798c6226796c3be227819f67a2f9e4de3df6534ca064f82f1fa71`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`；待真机核对顶部无额外栏、返回键、历史初始展开及确认建房，+263 已通过的原生性能仍需确认无回归。本地稀疏检出缺旧桌宠素材使全套检查停在第 27 项，CI 恢复资源后全套通过。
- +264 真机回填（2026-09-26）：用户安装最新版后反馈“没问题了”“没有在真机里发现大问题”，承接上一轮针对默认原生入口、顶部栏、系统返回和历史默认展开的验收请求。将这些外观/导航小项以及原生性能、输入法无回归标为**用户报告通过**；不把概括性反馈扩展为确认建房、搜索/自定义标签、音效/振动、备份恢复的逐项通过。后者自然使用时顺带观察，不阻塞下一任务。最近可见脱敏诊断属于 `v0.42.17+261`，早于 +264，不用于证明新版；+262 自然变身真机已通过，主动消息 Gemini 最终通道及思考翻译仍无单独新证据。整体 `TRUE DEVICE PARTIAL PASS`。
- 下一任务方向修订：曾在隔离的 `agent/v04221-real-reminder` 上短暂推送 `+265` 相对时间提醒实验，用户提出日历手写方案并要求回退。已将本地应用代码复位到 +264，远端实验分支撤回至 +264 内容，不把该实验 APK 作为候选。日历全天事项如何自然参与当天话题，以及到点强提醒的系统通知/闹钟式呈现，继续讨论后再实施；禁止从旧相对时间原型直接续写。

## v0.42.21+265 · 手写日历提醒与模拟手机自然记录（2026-09-26，开工登记）

- 用户决定：日历条目只保存在伴侣本机；“今天”、日期、闰年和时区使用手机系统本地时间，不读取或修改系统日历。入口位于左侧栏“她现在的状态”下面。纯日期可在当天自然提起；日期加时间的提醒到点独立响铃、可振动，手动关闭或五分钟自动停止；停止后按事件生成一次不占每日主动次数的真实对话。提醒的现有相对时间语句实验已撤回，不续写。
- 同批内容：记忆库全文搜索；心情与塔罗“她的解释”从已有真实状态/牌面生成第一人称短评，避免固定套句；愿望单和日记新增与相册/随笔一致的已更新红点；核查随笔 2026-09-14 后每日约一条。愿望单生成与自主相册来源本批不改，相册候选网站未来另议。
- 已定位随笔真实结构问题：`noteDailyLimit=6` 且六个时段存在，但 `_refreshNotes` 把整个 `DailyContinuityRecord.id` 当唯一已使用源。通常每日只结算一份 continuity，生成一条后其余真实子事项被一并排除；本批改为不同事项独立去重，保留最多六条、近期重复拦截与失败不强塞固定文案。
- 实施保护：响铃与模型生成解耦；停止事件幂等，生成失败保留待处理记录供后续重试，不伪称已送达；重启/升级、时区变化从本机条目恢复。原生 Android 通知与精确定时权限以真实设备授权为准，CI 不等于真机验收。
- 实现：左侧栏“她现在的状态”下新增手写日历；日期/每年重复/全天或定时由用户直接编辑，按系统本地日期与时区计算，全天条目作为当天主动对话的可选资料。定时条目保存至 SQLite 并镜像到 Android AlarmManager，系统精确闹钟权限可由页面打开；若未授予则使用可能延迟的系统调度。前台服务以闹钟音频通道循环播放、振动，通知与锁屏全屏入口均有手动停止，服务和独立 timeout 兜底最长五分钟。可在日历页打开系统“日历响铃提醒”通知通道设置音色。停止事件先存本地待处理，后台脑/前台聊天按同一 lease 和确定性消息 ID 生成一次事项对话，完成后才确认；不写入主动次数的 `proactive_history`。
- 模拟手机：愿望单新增或内容/完成状态更新、日记新增时按“已看”时间显示红点；不改愿望来源筛选。心情以当下欲望、情绪片段与日常真实摘要生成第一人称短评；塔罗的两张当日牌以牌义生成各自第一人称“她的解释”，旧固定解释在当天迁移时移除。生成失败不使用旧套句伪装自然表达。随笔按 continuity 中的具体事项独立使用，保持六个时段、每天最多六条及重复质量门；实际条数取决于真实可用素材。记忆库搜索在状态/类别筛选内查内容、标签和事实键。
- 验证：首轮 Actions `36213477925` 在 125 项中的第 24 项停于旧总账门只接受 `+264` 版本，前 23 项已通过；已扩展该门的目标版本，本地至第 24 项通过，之后本地缺稀疏检出的旧桌宠/相册资源。第二轮构建提交 `aad9786124e6bc619ee15acb0a55f8a0489fd46b`，tree `d79c05b1003776997435e9df24ee3161b050414b`；Actions `36213673166` 的 125 项源码回归、Kotlin 测试、Flutter analyze/test、Release APK、签名与资源核验全部通过。Artifact `10896772812`（14 天）；未发布 Draft Release `397052898`：`https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-093807583d5693f8eb90`；APK asset `589821283`，大小 `546300815` bytes，SHA-256 `23b0be3ea95322bf89a27d22e9ce7e52da6d63ac42afa6d48410b230d9a2df7e`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。
- 真机待测：创建全天/定时/每年重复、系统精确闹钟权限与通知权限、锁屏/前台响铃及振动、手动停止和五分钟自动停止后的唯一主动消息、重启与时区变化的恢复；心情和塔罗短评、红点清除、不同日常素材下随笔多条与记忆搜索。CI 不能证明系统在具体设备上准点或全屏权限必定获批。联网相册来源仍留给下次讨论。
- 用户 2026-09-26 接班时明确决定“上一个窗口的真机测试默认成功，因为这些真机测试容易捕捉，有问题再说”。据此停止把 +265 整包作为待用户逐项验收的阻塞项；这不是对每个闹钟场景已实际复现的独立诊断证明，若日后反馈仍按具体场景排查。

## v0.42.22+266 · 代办提醒名称、节日与天气感知讨论（2026-09-26，开工登记）

- 目标：把新入口“日历提醒”的可见名称及相关通知文案统一为“代办提醒”；保留既有日期、重复、定时响铃、停止后一次对话、存储键/数据库及 AlarmManager 行为。节日与天气只形成可核验设计，桌宠/表情包等用户提供参考项目后再定实现范围。
- 证据：+265 APK 已交付；当前 UI 在左栏、页面、Android 通知和后续对话标题仍称“日历提醒”；MCP 客户端是 Streamable HTTP，现只专门接 Cedar，Android 15 尚无可直接用于天气的定位权限流程。
- 保护边界：不因改名迁移持久数据或闹钟渠道 ID；不把天气 MCP 工具返回当成设备传感器观察；不硬写固定节日问候/天气台词；内部事实和最终可见回复仍遵守 DeepSeek/第二通道现有分工。新感知若带自主触发，需先确定唯一 owner、Stop、缓存、去重和首版脱敏诊断。
- 本地实现：左栏、编辑页/空状态/提示、Android 响铃通知与通道展示名、停止后会话标题改称“代办提醒/代办事项”。保留 `CalendarReminder` 类/数据库与 AlarmManager/通知 channel ID；内部“今日手写日历事项”事实标签仍说明来源，生日等全年日期不被误称成待完成任务。改名不修改提醒内容与触发语义。
- 节日感知设计（讨论阶段）：由手机本地日期/时区推导当天节日候选，地区与历法由用户偏好/可核验来源决定；法定休假安排、农历公历转换、跨时区和每年浮动日期需具备年份与来源，不写死在角色规则里。作为有日期、地区、置信度和来源的短期环境事实进入现有 DeepSeek/最终回复链，是否提起由她自然判断；不得定点塞固定祝福、冒充用户庆祝或当天每轮重复。手写代办/生日属于用户事实，与公共节日分层。
- 天气感知设计（讨论阶段）：MCP 可以沿用现有 Streamable HTTP 客户端，但 Cedar 目前是专用协议入口，天气仍需独立只读适配器、工具/主动情境入口和来源核验。`cyanheads/open-meteo-mcp-server` 提供 Streamable HTTP 公共实例及自部署实现，实际取数来自 Open-Meteo；MCP 并不提高预报精度。首版建议用户手动选城市/区域或经明确授权的粗定位，记录 `place / source / valid_time / fetched_at / timezone / units / current_vs_forecast`；缓存和过期门避免旧预报被说成当下观察。温感使用体感温度与场景阈值，降雨区分当前估计、未来小时概率和雨量，不以概率声称已经下雨。日本地区若追求分钟级降雨，JMA 高频雷达临近预报是单独数据源与接入问题，不能把 Open-Meteo 的 15 分钟插值冒充雷达实时雨情。
- 雨量事实：Open-Meteo 的小时 `precipitation` 为此前一小时总量 mm，`precipitation_probability` 为此前一小时超过 0.1 mm 的概率；日本等非其原生 15 分钟模型覆盖区的 15 分钟值由小时插值。JMA 官方 1 km 降水临近预报最多 1 小时，每 5 分钟发布；这两类预测均不能承诺用户站位的必然降雨。准确率没有项目实地样本，暂不量化。
- 后续顺序：收到桌宠/表情包参考项目后先定点分析，与节日/天气接入方案合并排期；未获城市/区域与节日地区偏好时保持这些项目为设计，不默选用户所在地。天气 MCP 公共实例先做协议/可用性验证，再决定自部署或直接 API。自主天气提醒若启用，先登记唯一 owner、节流、Stop、去重与脱敏诊断。
- 本地核验：`git diff --check` 通过；用户可见旧名称已在 `app/lib` 和 Android 主源码逐项检索，剩余“日历”仅为内部事实来源标签。当前机器无 Dart/Flutter SDK，未进行 Flutter/Android 构建。本批尚未推送/触发 CI/交付 APK，状态 `NAME IMPLEMENTED LOCALLY / HOLIDAY-WEATHER DESIGNED / CI PENDING / APK PENDING`。
- 2026-09-26 用户追加本批目标：节日以中国传统节日为主，兼收圣诞节等知名国外节日；天气优先考虑用户已有和风天气 API；桌宠先试三段新待机动画与参考项目点击动画/果冻反馈，测试期间取消原有头/尾/身体分区点击，移动动画不动；表情包参考 `moonlin1213/cove-sticker-mcp`，先查“零 token 自动识图”是否成立再决定接入。
- 开工证据：参考桌宠 `MerZlin/dsh-pet-indesktop` 的 `shenshen/videos/random` 与 `click` 为 640×360 VP9 透明 WebM（10 秒/24 fps），Android 现有播放器读取 PNG 帧并要求动作注册，因此需有界转换和隔离测试开关。素材与代码 MIT，移植时保留作者与许可证。现有表情包系统以 ZIP/index 的 `tag/caption/keywords` 选图；Cove 的 `VisionConfig.enabled` 需配置图像模型、Endpoint 和密钥，自动标注 POST 图像至视觉模型。无模型时只有手动元数据/检索，并非免费自动看图。和风天气官方提供全球实时/小时天气，以及仅中国地区的两小时 5 分钟降水；优先复用用户自己的 API，地点、身份凭据与时效门仍需独立设计。
- 本批边界：节日只给日期事实，不移植参考项目固定祝福/定时刷屏；桌宠实验开关在测试 APK 默认开启、用户关闭即回原链，且不变更走路素材/移动物理。表情包没有无成本真实视觉理解可直接移植，本轮先评估，不接入独立 Python MCP/图库，不替换用户现有表情包。和风天气未提供当前 Key/Host/地点，不在公开仓写凭据，本轮给出取数方案而非伪造连接成功。
- 本地实现：`lunar 1.7.8`（MIT，无第三方依赖）按本机日期计算春节、元宵、清明、端午、七夕、中秋、重阳、腊八、除夕及常见公历节日（含圣诞）；仅在普通聊天/主动上下文提供当天事实，排除角色扮演和新网页话题隔离路径，绝不制造固定问候或额外主动调度。桌宠将参考仓 `2786c15` 的哼歌、伸懒腰、玩魔方和点击挥手四个透明 WebM 以 10 fps 采样成 400 个 300×300 静态 WebP（合计约 6.1 MB），保留 MIT/来源/转换说明；利用现有播放器注册仅供测试的四个非循环动作。桌宠选项“实验动画”默认打开，开启时新增三段待机候选、统一单击挥手并附短时阻尼果冻缩放；关闭恢复旧点击分区与旧待机候选。拖动、双击菜单、移动动画、睡眠/语义高优先级仍走原链。
- 本地验证：FFmpeg 确认原片 VP9/alpha、每段 10 秒；所有 400 个生成帧可解码、300×300 且命名 000～099；Dart 农历包下载 SHA 与 `pubspec.lock` 一致，并核对 `Lunar.fromDate/getMonth/getDay/getJieQi` API；新增农历/圣诞事实和测试开关移动候选回归。`git diff --check` 已通过，Flutter/Android 编译仍待 Actions。Cove `vision.py` 的自动标注明确要求视觉模型与密钥、压缩图像会发送外部服务，因此不接入零 token 幻想；现有用户表情包 ZIP/index 与选择概率暂不改。
- 天气决定建议：用户已有和风天气 API，优先直接接其 REST，而不绕第三方 MCP。实况/小时预报可覆盖全球；`/v7/minutely/5m` 仅中国地区，未来两小时每五分钟的雨量 mm。下次接入前需要用户的可用 API Host/授权方式和天气地点选择；Key 只存本机私密设置。降雨只按 provider 的 `updateTime/fxTime` 表述“预报”，不拿外部实况说成实际接触雨水。
- 首轮 Actions `36219333507`：源码回归通过，Kotlin 编译在实验素材帧路径处报 `Unresolved reference 'padLeft'`；这是将 Dart 字符串方法误用于 Kotlin。已改为 Kotlin `padStart`，同版重跑完整构建，首轮 APK 未产生。
- 修复后功能 head `fef1bb8fb1ab6b7530a16ada0ce744064c43dcdd`、tree `177ea7732e1044e46f4e502ecc8c70cce5d101b9`；Actions `36228578087` 全绿（125 源码门、Kotlin 桌宠/桥接测试、Flutter analyze/test、release APK、签名与素材包核验）。Artifact `10902126662`；APK SHA-256 `8ae68d4ac60cf78488b2de4b1b23d156eb8b443b5fda6175d741ff617f799ac2`，大小 552551239 bytes；未发布 Draft Release `397094347`（tag `v0.42.22-holiday-pet-clip-test`）。真机实验尚待用户观察，桌宠除移动动画外的三待机与点击反馈可在“实验动画”中关闭恢复旧链。天气未接凭据、地点及接口，不将设计写成已接入；Cove 零 token 自动视觉标注不成立，本轮未移植。

## v0.42.23+267 · 桌宠新素材对齐、曲线与独立溢出显示（2026-09-26，开工登记）

- 用户真机反馈：+266 新素材能播放，但人物本体比旧桌宠小；点击动画进行时再次点击无反馈。用户先讨论后明确授权本轮只保留三个待机动画、补一段原项目站立动画与现有点击素材进行测试，不全量导入；新素材允许绘制在原窗口宽高之外，但原桌宠窗口仍是位置、贴边、物理和触摸的唯一几何真值。
- 实现目标：App 内双层半透明对齐原站立/新站立，人工调新组缩放、平移和提亮曲线；这组参数用于所有新动画，原桌宠不变。实验播放使用不接收触摸的附加显示层跟随原窗口，移动/贴边仍据原窗口。点击同一动作可重播并重触发果冻；三个待机与站立 224×224、4 fps，点击 240×240、6 fps；统一 1.5 倍速，保留实验开关和旧动作回退。
- 依据与验证：原 640×360 透明 VP9 固定中心裁切；七段样本的 224×224/质量 65/4 fps 帧包约为 +266 300×300/质量 78/10 fps 的 24%，3 fps 约 18%；本轮先取 4 fps 以保留人形辨识，点击用 6 fps。独立显示层必须在 attach、drag、投掷、自动移动、resize、配置变化、bringToFront、隐藏与 release 各路径同步/移除，绝不以扩宽原 WindowManager.LayoutParams 冒充溢出。曲线应只改变新素材 RGB，不改透明度或打包第二套帧。
- 保护边界：不加入其余 92 段动画、move/drag/balance；不改原移动帧、活动范围或触摸热区，不重构聊天/提醒/人格；schema 61、Snapshot protocol 6 和既有签名身份不变。本批先本地静态/素材核验再 Actions 全构建，完成后补 head/tree、CI/APK 和真机状态。
- 实现：四段实验待机（原三段和新站立）各 40 帧 224×224、4 fps；点击 60 帧 240×240、6 fps，按 1.5 倍速度播放；220 帧共 1,999,720 bytes，保留透明度和 MIT 归属。App 内“调整新动画 · 对齐与曲线”页叠加旧 `IDLE` 和半透明新站立，提供旧尺寸三档预览、新组统一缩放、X/Y 平移及 gamma 中间调曲线；参数保存至原桌宠设置，实验开关关闭即返回旧动作。新素材在独立不可触摸、跟随旧逻辑窗的 WindowManager 层播放，可溢出旧宽高；拖动、贴边、投掷、尺寸、可见性仍由旧窗口决定。为 Android 12+ 的透传触摸限制，新增层窗口 `alpha=0.79`；点击同一实验动作可以重新起播并重触发果冻，双击菜单语义保留。
- 验证：源视频 640×360 透明区域在 x=140～500 裁切内无截断；本地格式/帧数/体积与 `git diff --check` 通过。首轮 Actions `36232084731` 在第 24 个旧总账版本白名单停下；补 `+267` 后功能 head `07142df2f01f15b5e4770fb6d17b48150770f422`、tree `aa16c6405f87967191dcb5b99662c53302983c52`，Actions `36232295089` 的 125 项源码回归、Kotlin 桌宠测试、Flutter analyze/test、release APK、既有签名和包内 220 帧检查全部通过。Artifact `10903136887`（14 天）；APK SHA-256 `956812613c1fb00123e2ab2e6a3f5f3ccc1d320743c7bd6b866c4e0365b09ab2`，548,423,007 bytes；未发布 Draft Release `397169363`：`https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-b3268e928cac05b343d3`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE FEEDBACK PENDING`。
- 后续观察：真机查看不同动画人物大小与脚底对齐、曲线亮度、超出旧范围的效果、贴边/拖动/熄屏时显示层清理，以及单击动画进行中再次单击的重播；若有问题按具体动画和场景反馈，继续保持实验可关闭。天气仍未接用户和风天气凭据与地点，本批无天气连接改动。

## v0.42.24+268 · 桌宠全帧、不透明播放与校准补项（2026-09-26，开工登记）

- 用户中途校准修正（待 CI/真机验证）：Photoshop RGB 输入色阶指定 `0 / 0.86 / 230`、输出 `0 / 255`，替换原单参数“提亮曲线”。App 内新增黑场、中间调和白场控制，默认采用该数值；逐像素对 RGB 应用输入色阶并保留原 alpha，饱和度仍独立可调。旧版保存的 gamma 不强制沿用到新色阶，以避免混用两种不同定义；缩放、位置和饱和度存档保持读取。此项已推送测试分支，仍待成功构建与真机确认。
- CI 失败路线：远端首次构建 `36235711293` 在工作流“Verify clean source baseline”因仍核对旧 `0.42.23+267` 而中止；改为 `0.42.24+268` 后，`36237371443` 进入 Kotlin 编译，暴露 `clip.durationMs` 可变属性不能智能转换及三处 Float 传入 `dp(Int)`。已分别固定局部时长与明确四舍五入，等待下一轮 CI 验证；不得将上述运行视为编译通过。
- CI 最终证据：分支提交 `45d030292f806c05050f540f76444471bade70ca` 的 Actions `36237804671` 完成且全绿；源码回归、Kotlin 桌宠测试、Flutter 静态检查与测试、release APK、签名、实验帧包校验均通过。测试 APK 为 `AI-Companion-v0.42.24-268-Opaque-Fullframe-Pet-APK.apk`（556153250 字节），上传到未发布测试 Release `v0.42.24-opaque-fullframe-pet-test`。色阶显示、全帧速度及外扩层透传触摸仍待真机验证；此条为构建证据，不代表真机通过。

- 用户反馈：+267 的“半透明”只应出现在 App 内双层站立对齐预览，不应作用于桌面新动画；还需独立变宽/变窄和饱和度校准。抽帧造成播放视觉不对，改为完整原片帧数，在像素尺寸与 WebP 质量上压缩，保留 1.5 倍速。
- 根因：+267 的新 WindowManager 显示层设置了 `alpha=0.79`，整段桌面播放的实际不透明度被降低；`PetSkinManifest.frameDuration` 对所有动作强制至少 70 ms/帧，完整 241 帧若不修此门，6.667 秒动作只能展示约前 95 帧。当前原片五段均为 24 fps，0～10 秒含末帧共 241 帧。
- 实现计划与边界：桌面实验层 `alpha=1`，仅校准页叠层维持 52% 新站立透明度；新增相对宽度 50%～150% 和饱和度 50%～200%，与统一缩放/位置/gamma 同组保存、原素材 RGB 变换保持 alpha。五段各保留 241 个透明 WebP（224×224，点击 240×240），按长度前缀封装并分成顺序小包，不移除动作帧；时间进度按 `elapsedMs * 241 / 6667` 定位，原桌宠低帧动作保留原有时钟。逻辑窗口和触摸范围仍由旧桌宠决定，附加显示窗口按校准后实际绘制边界收紧并跟随移动。Android 12+ 对 `FLAG_NOT_TOUCHABLE` 且全不透明的悬浮层会限制其覆盖范围内对其他 App 的透传触摸；本测试版优先纠正用户指定的不透明画面，并缩小新窗口范围，真机需重点检查人物外缘覆盖到 App 按钮时的触摸行为。若需要同时保证边缘完全不透明和跨 App 透传，须改用可信悬浮窗权限/实现再单独评估，不伪称当前已解决。
- 保护范围：三旧待机候选加站立、点击素材；不接其余动作、move/drag/balance，不改旧位移、贴边、点击热区、schema 61、Snapshot protocol 6 或已有签名。实验开关关闭仍走旧链。验证含五包每包 241 帧完整性、透明度/尺寸/总量、Kotlin 与 Flutter、release APK 内封包逐帧结构、签名及真机反馈。

## v0.42.25+269 · 桌宠 96 段完整动作与整轮气焰结算（2026-09-26，CI 完成）

- 来源与边界：用户上传的原始 `dsh-pet-indesktop-main.zip` 保存在未发布 Draft Release `397377805` 的 asset `591363139`，85,049,410 字节，SHA-256 `ad94e2aa8829ddb5b8f0640e383b29bbccfbb5a77d9a957559e34cff17aea489`。只取 `random`、`click`、`sleep`、预览用思考等 96 段，排除 `move/drag/balance`；五段点击进入点击轮换，三段睡眠仅供预览，原睡眠链不动。删除自主思考动作，保留会话思考表现；自主动作打乱轮换，保留走路候选权重及连续静止限制。实验关闭可退回旧桌宠链。
- 实现：91 段新增 VP9 透明 WebM 连同五段既有实验片段构成 96 段、23,013 帧；GitHub Actions 从固定 Draft asset 下载、验 SHA，安装 ffmpeg 后转完整透明 WebP 并打包，按 1.5 倍时钟播放。运行时以有限 LRU 缓存帧包；点击有五段随机轮换；睡眠和思考预览不进入桌面自主动作。正式桌宠保持不透明，思考/说话装饰按尺寸贴合，预览页可滚动并按类别选片。校准新默认缩放 121%、宽度 93%、X=0、Y=-2dp、输入色阶 0/0.95/230、饱和度 110%；已有设备保存值不会被默认值覆盖。
- 气焰：用户分类暂存；可见助手回复落地时合并双方贡献、固定每轮 -18 与严肃话题额外 -12，再一次 clamp 0～100 和切换形态；Stop 撤回尚未完成的用户回合。普通 15+0+3-18→0；相互挑逗 15+30+3-18→30。手动互动、锁定与既有数据结构保留。
- 云端证据：功能分支 `agent/v04225-pet-full-clips-heat`，构建 head `b9f854e960bca401c861b769cda2576b79ef9d9c`、tree `74d27843c419da0e36e2de122fb092b0fa8129bf`；Actions `36271743353` 完成且结论 success。125 项源码回归、44 项 Kotlin 桌宠测试、Flutter analyze、Flutter tests、release APK、既有签名与包内素材校验通过；包内实核 96 段、23,013 帧、实验帧包 189,260,382 字节。Actions Artifact `10915967838`；APK `AI-Companion-v0.42.25-269-Full-Clips-Heat-APK.apk`，722,612,227 字节，SHA-256 `0830c3e6d36a9ac0d5b94628cf6fac9564e02d8d8d6d0b4ae784d7f8d2dd9453`。未发布测试 Draft Release `397385083`：`https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-f66fe79c212e315b1d35`。
- 状态：`IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。真机需看人物大小、脚底对齐、五种点击重播、随机动作和走路频率、三段睡眠预览、预览页面滚动、桌面不透明、外缘覆盖其他 App 时的透传触摸，以及 189 MB 新帧包对安装体积和运行内存的影响。当前并无真机通过证据，未合并 main，未发布正式 Release。
- 跨窗口素材维护：新增 91 段的原始 ZIP 只在受权限保护的 Draft Release `397377805`，Git 保存固定 asset ID、哈希、96 段目录和转换脚本，最终 APK 带有转换后的帧包。既有五段实验帧包在 Git；更早的桌宠本体 417 文件由仓库 `app/asset_packs/dafeiyu_private.parts/` 的分片及 `app/tools/restore_dafeiyu_asset_pack.py` 还原。新维护者只需读本节、清单和工作流，无需聊天上下文；要复现完整 APK，须能访问仓库及此草稿附件。删除或替换附件会使未来构建失败；草稿不是公开仓库代码的一部分，也不应把上游当前版本视为等价备份。


## v0.42.26+270 · 桌宠显示层与新版待机范围（2026-09-26，CI 完成）

- 真机证据：用户在新片段持续播放时关闭“实验动画”，片段没有立即结束，却瞬时由半透明变不透明；现代码开时用额外 `FLAG_NOT_TOUCHABLE` WindowManager 画面，关时用原主窗口画同一帧。色阶保留源 alpha。优先收敛到主窗口播放，避免新窗口合成差异；检查校准后边界，深度思考碎碎念源裁切可直接不入待机。
- 产品范围：改名“新版动画”且默认勾选；关闭使用旧版动作选择；打开只保留旧 IDLE/眨眼/散步/睡觉/拖放着陆晕眩/哈欠及对话思考、说话等基础动作。旧 GLANCE/HAPPY/SWEEPING/EATING 等自主表演不进新版待机；三段新睡觉与新版工作、思考短片加入随机待机，不能挤掉散步。正式对话仍由旧思考、说话动作负责。校准入口从悬浮菜单移到播放器预览首位；两页均适配系统栏和可滚动区域。
- Draft 整理证据：用户明确确认永久删除版本不高于 +265 的 AI Companion 旧测试 APK 草稿。人工删除 +265/+264/+263 三份；维护分支 `maintenance/cleanup-old-apk-drafts-20260927` 的 Actions `36275819669` 先干跑、`36275881299` 后删除 191 份，仅匹配带 APK 且附件都是 APK/SHA/TXT 的旧候选；两份无 APK 候选保留。+266～+269、桌宠源 Draft `397377805`、签名 `ai-companion-private-signing-v1` 与 Genie `genie-tts-private-runtime-v0.7.6-jiuhu`/`v0.6.4` 等输入未删除。构建工作流仍从上述 Draft 下载并校验，接班索引 +269 与上一节已写明。
- 验证门：Kotlin 动作选择/切换测试、源码门、Flutter 分析与测试、APK 内 96 段帧结构及签名；真机核对不透明/大小/边界/触摸、新旧切换、走路频率、睡眠/工作/思考待机和两页布局。

- 实现与验证：主桌宠 View 接管全部动画绘制，移除额外 WindowManager 显示层；模式切换立即回待机，会话思考/说话抢占新片段；新版随机池仅保留原散步及新素材，三段新睡眠和“工作状态-思考冒泡”可随机待机，“深度思考碎碎念”因源内容裁切不使用。新版勾选默认开启，旧版随机逻辑未改。校准入口在播放器最上方，两个 Activity 消费状态栏、导航栏和刘海安全区；校准页按钮固定指向哼歌/伸懒腰/魔方动作 ID。
- 云端证据：功能分支 `agent/v04226-pet-opaque-ambient-preview`，构建 head `4b205aee8f8e27a50ee4a87f5f1060fbf1dc4b7d`、tree `eb72b9f79f4e93bd210856cf7faadb88e5d7ca2a`；Actions `36276798640` 的 `build-apk` 全绿。素材 Draft 下载与 SHA、417 文件、125 项源码回归、Kotlin 桌宠测试、Flutter analyze/test、release APK、签名与包内帧均通过。APK `AI-Companion-v0.42.26-270-Pet-Opaque-Ambient-Preview-APK.apk`，SHA-256 `8e8a0b3c2809bb53efa9bd9e53e3d058ec0126231a736213fe69d395623cb85b`；未发布 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-c838b8c01ac127dd5d71`。签名证书 SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。
- 状态：`IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。真机必须核对新版身体是否持续不透明、宽大特效是否截边、覆盖其他 App 时能否正常触摸、新旧即时切换、睡眠/工作待机与两页上下控件完整可见；构建成功不能替代上述视觉与交互验收。

## v0.42.27+271 · 自主聊天后台提醒通道阻断热修（2026-09-27，CI 完成）

- 证据：用户上传的 +269 私测存档与 2026-09-27 16:04 中国时间脱敏诊断相互吻合。存档最后一次 `proactive_history.decision=sent` 在 09-26 11:14:33，09-26 23:28 用户回合后至 09-27 16:03 仍无主动发送；诊断 `autonomousBehaviors.eventCount24h=0`、`recovery_orchestrator_next_heartbeat_at=0`、`background_error_count=677`，最近错误 `MissingPluginException(No implementation found for method pendingStoppedReminders on channel ai_companion/system)` 发生于 09-27 16:02 左右。Active Brain 已开，transfer lock、当前阻塞生成、chat/proactive/orchestrator 租约均未占用，日间疲劳 0.3358 且 hard veto=false，频率档自然、24 小时用量 0；并非夜间限额、疲劳或频率策略自然静默。诊断里 `recovery.state=waiting_generation:running` 是早前留下的状态，不能据此断言当前生成任务卡死。
- 根因：`RecoveryOrchestrator.runOnce` 在进入自主心跳前无隔离地调用 `CalendarReminderFollowup.deliverOne()`，后者从 `AndroidBridge.pendingStoppedReminders()` 调用 `ai_companion/system`。前台 `SystemBridge` 实现了此方法，独立后台 FlutterEngine 的 `BackgroundSystemBridge` 却未实现，于是每次后台循环在心跳前抛错，后台入口仅记录错误并十分钟后重试。正常聊天仍走前台，故用户回合正常不代表后台可运行。
- 实现范围：后台桥接补 `pendingStoppedReminders` 和 `acknowledgeStoppedReminder`，复用前台同一 `CalendarReminderAlarm` 状态；提醒单独失败时记录脱敏分类/时刻并继续后续自主循环，转移冻结异常仍传播。保留 21:00～次日 09:00 一条成功投递上限、10 分钟对话静默窗、Cedar/联网竞争、模型通道、schema 61 和现有桌宠构建素材。构建 +271 测试 APK 后，以同样自然使用观察后台错误是否停止增长、心跳时间是否推进，以及日间是否产生真实主动行为；不把“立刻发一句”当唯一正确结果。
- 云端验证：构建 head `5860cd54238e77ec65e6b911decee71020ae5316`、tree `273ca6ab88ef1eee7d0daa0bde657f9c4154ffc5`；Actions `36305352339` 全绿。素材草稿恢复、源码回归、Kotlin、Flutter analyze/test、release APK、原签名和包内素材校验通过。Artifact `10926944052`；APK `AI-Companion-v0.42.27-271-Proactive-Background-Bridge-APK.apk`，SHA-256 `a2236878e9234570ee6e90f6e288cb25b4f9186653b2b09ef54a147f3b49e879`；未发布测试 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-fb80911e6438a3a7d7d3`。签名证书 SHA-256 仍为 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。

## v0.42.28+272 · 天气认知、桌宠裁剪、余额与自主链路复核（2026-09-27）

- 用户授权本窗口后续推送/构建；本批仅显示 DeepSeek 官方账户余额。OpenRouter 的 Key 限额不等于账户总余额，千问百炼模型 Key 无法读取阿里云财务余额；`wy.aiwangyou.cc` 未找到可核验的公开余额接口，本批不猜测接口、不向中转站发送 Key 探测余额。
- 天气由用户在“模型与联网”填写和风天气 HTTPS API Host、API Key 与城市，Key 存本机安全配置，不写入仓库或备份。按需每十分钟同步当前实况，缓存四十分钟内的事实和读取时间；先用 Geo v2 查城市坐标，再调用当前 `/weather/v1/current/{latitude}/{longitude}`，使用 `X-QW-Api-Key` 请求标头，避开即将弃用的旧版 `/v7/weather/now`。提示词只在非角色扮演且非纯新鲜话题模式附加简短事实，选择是否提起仍由模型决定，不生成额外主动任务。网络刷新异步且错误可省略，不能阻塞自主心跳或用户回复；没有提供凭据与城市前不声称连通。
- 新桌宠继续沿用 +270 的单 WindowManager 绘制路径，绘制比例预先计入新版动作的二次缩放和宽度校准，以统一画面安全边缘减少左右裁剪。进一步发现原转换脚本把 640×360 WebM 固定 `crop=360:360:140:0`，构建时先丢弃左右各 140 像素；本版从受保护源 ZIP 重新生成 91 段完整横画面帧，缩入透明方形画布，保留左右特效与文字。旧版逻辑和触摸区域不变；宽画面内人物可能比旧裁切版小，真机需核对，原视频自身已切掉的内容仍无法恢复。
- 左栏两种布局均显示 DeepSeek 官方余额查询结果或清楚的失败状态；联网请求只到 `api.deepseek.com/user/balance`。设置页将各小节保存/测试反馈放回按钮下方、统一左对齐；Agnes 测试按钮“测试整理效果”，公开网页发现“保存本小节”并新增固定公开词联网测试，单次请求可能消耗 Tavily 额度。
- 自主代码复核：+271 已补齐后台日历提醒桥并隔离提醒失败；本批额外隔离后台心跳前的模拟手机维护、待续生成恢复、记忆整理和 Cedar 下一次执行间隔读取失败，保存脱敏错误分类/时间，转移冻结与租约保护继续生效。真实阻塞中的生成仍由既有检查阻止重复可见回复；真机仍需观察心跳推进、错误计数和自主消息送达，代码审查和 CI 不等于一夜自然使用验证。
- 维护依赖：完整 96 段桌宠帧在构建时从受保护 Draft Release asset `591363139` 下载源 ZIP 并校验 SHA-256 `ad94e2aa8829ddb5b8f0640e383b29bbccfbb5a77d9a957559e34cff17aea489`，再恢复仓库分片的旧桌宠包；CI 同时拉取受保护签名、Genie 等载荷。只检出 Git 工作树无法独立复现最终 APK；接班者须读取 `.github/workflows/build-apk.yml` 的恢复步骤，保留这些 Draft 输入。
- 云端验证：功能 head `dab608917f8b8c219bf182e5c68a666ba03b9b4b`、tree `fa253be5c84232c3601e1302cb6587a28f6b51d3`；Actions `36310019305` 全绿（125 源码回归、Kotlin、Flutter analyze/test、release APK、原签名和包内素材校验）。Artifact `10928946322`；APK `AI-Companion-v0.42.28-272-Weather-Pet-Balance-Autonomy-APK.apk`，SHA-256 `ac358f8a59e5852cc32dc331350997612fbb50398d282649ce68252a0e675f7b`，大小 630066527 bytes；未发布测试 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-a2af492aaa765a999aa2`。签名证书 SHA-256 仍为 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`；真机重点核对所有新版动作左右内容、人物视觉尺寸、天气首次同步和随后自主消息，夜间自然运行仍需用户观察。

## v0.42.29+273 · 新桌宠高度与天气 Host 保存热修（2026-09-27）

- +272 真机反馈：新版人物显著变小。根因是把 640×360 横画面缩到 224×126，再放入 224×224 透明方形帧；方形悬浮窗按宽度适配后人物只剩原高度约 56%。本版按原 360 高度缩为 398×224 透明 WebP，保留完整 16:9 左右内容与旧版 224 像素的画面高度；单层悬浮窗仅增加横向宽度，小/中/大三档高度仍为 112/152/200dp，渲染按高度等比适配，预览同步按宽画面适配。升级旧位置时把宽度增量分到左右，人物中心位置保持不变。宽窗边缘可能覆盖更多触摸区域、极窄屏和贴边时左右特效可能仍被系统屏幕边缘裁掉，真机需要核对。
- 同批真机反馈：天气 Host 只填域名时，设置页严格要求 `https://`，而实际取数适配器接受裸域名，导致保存前误报泛化的“Host、Key 和城市”缺失。本版保存时将裸域名补成 HTTPS，校验 Host 仅含域名，分别提示缺 Host、Key、城市；立即同步使用保存返回值，不依赖提示文字一致性。原 Key 与城市继续仅本机保存，旧数据无需迁移；用户应使用和风天气控制台分配的 API Host。
- 构建仍从受保护 Draft Release asset `591363139` 复原完整桌宠源并验证固定哈希，恢复 Genie/签名等受保护输入；不要把原素材 ZIP 或签名提交到公开仓。待补充本版 Actions、APK 哈希、签名和真机结果。

### 同批阻断项：明确游玩请求未调用 MCP（2026-09-27 18:13 中国时间）

- 真机备份与脱敏诊断对应：9 月 27 日 18:12～18:13，用户承接她对钓鱼海沟的邀约，依次表示有空陪她去、现在出发、去买所需物品；她连续三轮只用对白推迟。最后真实 `cedar_toy.play` 为 9 月 26 日 23:27，三轮没有新增工具 Outcome。此前同一备份在 9 月 25 日记录“直接开呗”等自然承接语后的成功 Cedar 调用；用户指出自然语义执行曾正常工作，不能把当前失败归为从来不支持。
- 定点版本比较：+221、+222（桌宠接入前）、+223 与 +224 到 +272 的 Cedar 规划器主路由均为 `cedarExplicitRequest || cedarState.hasUserTurnContinuation`；这些版本没有因桌宠代码直接改动该路由。当前游戏为 `solo/active`，其后台续玩由独立时钟负责，`hasUserTurnContinuation` 不开启普通聊天工具；短句缺少直接游戏名，关键词路由也未打开工具定义。确切首次失效的版本尚未由单次备份证明，不能将原因武断归到桌宠渲染或 MCP 服务端。
- +273 修补迭代：最初本地尝试按短句动作词和上一句游戏词开放工具；复核发现人物常说“鲸鱼尾巴”，词面判定会误认为钓鱼上下文。该路线已撤回，未作为交付方案。现只用真实活动单人会话和紧邻上一条助手消息不超过 15 分钟作为工具可用的边界，模型在原有 DeepSeek 规划请求中读取实际对话自行判断是否调用；普通闲聊/延后不得调用，不因仅有工具可用而强制二次无调用重试。仅上下文触发的回合收紧为最多 3 次规划/3 次工具调用，明确游戏请求仍沿用 6/10 上限；真实写操作后立即收束、唯一后台续接、重复动作与租约保护均未放宽。执行仍须通过真实指南、服务端 Outcome 和本地权限门，不直接猜动作或伪造已完成。测试覆盖本次三句、历史成功短句以及无活动会话和过期上下文；单元测试只能验证工具可达，语义判断和真实推进仍待真机。活动单人会话的普通对话可能多一次 DeepSeek 规划请求，需以 `modelUsage.byLane.agent_tool_planning` 观察实际额外成本；如果偏高，再改成一次短语义判断，不回到关键词封锁。状态 `IMPLEMENTED LOCALLY / CI PENDING / APK PENDING / TRUE DEVICE PENDING`。构建前保护 +273 桌宠高度和天气 Host 修复；CI 须跑 Flutter 测试、源码校验、完整 APK 和签名门。
- 云端交付：最终功能 head `29934e9c44040404830f76514e6834aa9a4d5052`，Actions `36313602993` 的 `build-apk` 全绿；源码回归、Kotlin、Flutter analyze/test、release APK、包内素材与原签名校验通过。Artifact `10930480783`；APK SHA-256 `4fca5f9115113af59ec6902b3ff7dd7a14d526a2d362f570bfacd6c8849ee138`；签名证书 SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`；测试 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-cb69e7c8292398fa4fc8`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。真机验证短句是否触发真实 Cedar 工具、一次写操作是否收束、日常闲聊额外规划用量；同时核对新版桌宠高度/左右边缘与天气 Host 保存。不要把模型语义判定标为 CI 真机通过。

## v0.42.30+274 · 自主游戏检查点续玩、桌宠默认缩放和工具活动折叠（2026-09-27）

- 证据与目标：用户真机发现单人局经常只玩几步就停，期待偶尔凭自身兴趣持续玩约半小时，但不能再次占满分享。源码路径：`continueDue` 在检查点先推迟续接时钟，`RecoveryOrchestrator` 后发起竞争，`resumeOptions` 要求时钟已经到期，导致续玩候选在这次心跳被过滤；往后到期时又先延期。现有 `GameEngagementPolicy` 已根据真实游戏 Outcome 的近期动量、显著结果、饱和及心境调整游戏分数，无需增加一项固定半小时独占候选。
- 实施：检查点发生时保留已到期时钟，调度器在同轮发起正常 Desire/Thought 竞争；若未续玩，`finally` 再将时钟推迟 8 分钟，防止后台高频重试或 token 循环。服务端防沉迷锁定继续按 `resumeAt` 延后；用户已续玩、游戏已完成或前台换局时不重推时钟。一次唤醒仍至多执行一个自主规划动作，保留夜间休息、疲劳竞争、原 3 次状态变动/25 分钟检查点、现有饱和与分享独立计数；需要真机观察偶发持续游玩和网页/其他分享是否平衡，再决定是否调整局次阈值。
- 同批桌宠：仅更改实验动画无本机保存值时的缩放默认 `1.21→1.47`，显示 fit 的参考基准固定 `1.21`，避免新默认被 fit 公式抵消。用户已手动存过的设置不覆盖；宽动作与屏幕边缘实际视觉待真机验证。透明 WebM→逐帧 WebP 管线与品质参数不变。
- 同批 UI：普通聊天里工具调用过程可展开，回复正文首次出现自动收起；已完成消息的工具活动初始折叠，点击仍可复查真实 Outcome，不修改工具执行、结果、可见思考或沉浸回复。测试新增真实数据库中的单人检查点时钟／竞争资格／未选中退避回归；CI 继续跑源码门、Flutter analyze/tests、Kotlin、带受保护资源的完整 APK 与签名检查。
- 真机追加诊断：用户 20:13 截图显示保存备份因“另一项备份、恢复或设备接管”占用失败；脱敏报告 `transferLock=true`、无待处理接管快照，Cedar 动作租约在游戏执行状态结束后仍有约 91 秒；最近一次用户 `cedar_toy.play` 因 `cedar_action_in_progress` 阻止。源码发现前台工具和后台自治的 `finally` 都先 `finishExecution` 再释放租约，若前者抛错会跳过后者，最多残留原 5 分钟租约。两条路径改为嵌套 `finally` 保证尝试释放；备份占用说明按实际操作类型标明，等待写入超时不再误称“重新发送状态包”。该诊断不能证明截图中的首次锁定一定源于租约清理异常，也没有街机厅 MCP 错误正文；用户随后确认街机厅已正常游玩，因此不改远端动作协议，待新版真机复测。
- 云端交付：最终功能 head `17541e0d069bcf65e40b10e3d48549fb8a88be5f`，Actions `36319265641` 的 `build-apk` 全绿；源码回归、Kotlin、Flutter analyze/test、Release APK、包内资源与原签名校验通过。Artifact `10932156599`；APK SHA-256 `64654f6009da96677168f45b45b9aba261d6ac0c919e8cdf9c263eb2ee057ba0`；签名证书 SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`；测试 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-188cba037acbc197f5ea`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。用户确认旧版一次错误后街机厅可正常游玩，稍后备份亦成功；新版仍需真机验证偶发连续游玩与分享竞争、147% 尺寸、工具正文折叠，以及游戏／备份并发时租约能及时释放。

## v0.42.31+275 · 菜菜原生 Live2D 自主待机与桌宠说话状态（2026-09-27）

- 用户决定分步接入，首批只做原生 Live2D 与自主待机，并特别要求保留菜菜实验项目已经验证的“接入方式”，不要自行重写渲染。参考仓库 `nanlingyin/soullink-emotion-sdk` 用于后续 Jev 决策方向；本批实际原生实现来自 `catkiss62/caicai-live2d` 提交 `fb04512f940d159ebe13bebc13d2eda5cb54fc9c`，其官方 Cubism Java Framework 子模块固定 `c2d420012d004b8e61d4c589bd5c34513122f0ea`。源码与二进制出处、许可见 `app/docs/third_party/caicai-live2d/`。
- 移植原生 `SenCompanionView`／`SenRenderer`／Cubism Framework、Core AAR、默认 profile、参数语义与 EV clips/vocab。正式宿主只加 PlatformView、生命周期、文件选择和本机导入薄适配层，不带实验 Activity 与系统 TTS 测试壳；保留原来的双模型 `loadModels`、三配件组合、几何约束、前发锚点、EV faithful 动作模式及原生参数混合。沿用先前验证过的无 mipmap 纹理过滤修正，否则缺失 mipmap 的模型纹理会黑屏。完整运行时由源码与资源哈希门固定，不将模型权重加入公开仓或 APK。
- 用户在聊天画面设置导入带 `accessory-lab.json` 的菜菜女仆／Sen 三配件 ZIP，保存到应用私有目录，并可选启用主形态 Live2D；小豆丁仍用旧立绘。导入有路径与容量边界、临时目录、旧版回退；真正渲染报错时尝试恢复旧包。舞台可拖动／缩放。没有模型时提示导入。语音嘴型、表情与动作 Jev 判断、手选装扮及双形态 Live2D 不在首批开放，后续须根据真机画面和真实参数逐项加入；不能把原生自发动作当作 LLM 已控制参数。耳鳍眨眼和尾巴效果仍需真机核对菜菜源实现。
- 桌宠说话动作的静态机制：`TALKING` 单次动画 2.9 秒返回 `IDLE` 后，若上游会话 cue 仍是 `playing`，空闲重检会立即再播。前台 TTS 真正播放时每 2 秒续传状态；服务端 8 秒收不到心跳就让失联 `playing` 过期，同时真实结束仍即时发 `idle`。当前没有同一时刻的真机 TTS 诊断来证明旧版“卡住”唯一来源，修复针对可证实的无限重播条件。
- 保护边界：不改 Cedar、自主游戏/分享竞争、DeepSeek/Jev 工具规划、气焰及 schema 61；+274 的 147% 默认值、工具正文折叠、备份租约修复仍保留。原模型 ZIP 需用户从自己的仓库持有并在设备上导入；不在聊天中索取私有模型。验证包括 126 项源码套件、Kotlin／Flutter、签名和 APK 内完整原生资源；真机还需验证渲染叠层、前发与三配件、待机动态、重复开关及长时说话后的桌宠回到空闲。
- 首次 Actions `36328977449`：126 项源码门已通过，Android Kotlin 编译首次报错为实验项目在 CI 应用的 Cubism `drawable-filter` Framework 补丁尚未随移植带入。按实验项目原补丁精确补齐 `CubismRendererAndroid` 的三配件 drawable 筛选，源码门将该补丁与无 mipmap 补丁分别固定哈希，等待重新构建；不是模型纹理或真机驱动错误。
- 构建收尾：修复后 HEAD `968ca7cc8dad89cd345b6188472ba0e5517aa6eb`，Actions `36329874552` build-apk 全绿；Artifact `10935547935`，测试 Draft `397702273`（`untagged-a69fc367fb8a880a9ac7`），APK 726,018,970 字节。状态 `IMPLEMENTED / CI PASSED / APK READY`；SHA-256 与签名证书尚未在此账核实，不填猜测值。
- 真机失败：2026-09-28 用户截图显示再次导入时报 `上一模型包尚未在 Live2D 画面完成验证，请先打开画面`。导入器的 `pending` 只在画面 renderer onReady 时清掉，而设置页允许画面未建立时导入并忽略成功返回；二次导入遂被错误拒绝。尚无真机画面证据，Live2D 渲染／三配件仍未通过。

## v0.42.32+276 · 菜菜模型重试导入与桌宠触摸范围（2026-09-27）

- 开工证据：+275 真机截图二次导入触发 `pending` 门；源码 `CaicaiModelRepository.importZip` 在解压前直接拒绝未在舞台完成验证的包，且设置页导入成功未给可见提示。菜菜原生渲染源码哈希未动，仅调整宿主导入事务。
- 桌宠触摸证据：旧版 `PetOverlayWindow` 的系统窗口为 `windowDp × windowDp`；新版为 `visualWidthDp × windowDp`，中号从 152×152 dp 扩为 270×152 dp。虽然事件分类以旧方形坐标计算，`ACTION_DOWN` 在整个 270 dp 窗口触发自主中断、拖拽或点击。保留现有单窗口不透明宽幅渲染，先将宠物手势起点限制回旧方形；系统窗口两侧透明区域是否透传到其他 App，仍需真机判断，不把 `return false` 冒充系统透传。此前独立非触摸绘制层在真机导致半透明；Android 12+ 不可信遮挡策略也可能阻断底层点击，因此不在本批恢复双窗口。
- 保护边界与验收：保留原生双模型及 EV 待机、+275 TTS 心跳、147% 显示和 Cedar/气焰/schema 61。验证同一模型 ZIP 首次／重复导入、无效 ZIP 不丢当前候选、渲染成功／失败回退、桌宠方形内点击拖拽与左右空白处不触发；真机尤其检查旁侧底层点击是否透传。
- 实施：新 ZIP 完整解压并确认 `accessory-lab.json` 指向两份模型文件后，若上一包仍为 pending，先恢复已验证备份再开启新事务；无效 ZIP 在触动旧包前失败。设置页不再吞掉成功结果。`ACTION_DOWN` 在旧方形之外不再启动宠物手势、停止自主动作或拖动；新增方形边界 Kotlin 回归。
- 本地验证：菜菜运行时哈希门与总账接班门通过，`git diff --check` 通过。完整 126 项源码门在本地到第 28 项因受保护的 417 个桌宠源素材未恢复而停下；该素材仅由 CI 固定 Draft 资源补齐。Kotlin/Flutter 编译、APK 签名与真机仍待 Actions/设备确认。
- 本地提交 `053675a`。两次尝试推送明确开发分支均被自动审批拒绝，拒绝理由为公开仓库源码披露授权未被系统认可；已核对仅 15 个文本文件、无二进制或明显凭据，远端分支不存在。不得以连接器等间接方式绕过拒绝；等待用户对这一具体公开推送及常规 Actions 测试 APK 给出明确批准，再重试原始推送。
- 用户于 2026-09-28 00:41（中国时间）明确授权将本地 `053675a`、`2347961` 推送到公开仓库的 `agent/v04232-caicai-import-pet-touch` 并运行常规 Actions/Draft APK，且授权本窗口后续 AI 伴侣推送与构建。环境无 GitHub CLI 凭据，改由已连接的仓库 Git 数据接口重建两提交；远端 `8d574b28c75b5dbb316b77e05162984a1af0d7c5`、`a6193533b85b19ecccebfca771c85fc5e5e63ec0`，对应本地两提交的 tree 分别逐字节一致为 `cfe255cb530a4716c53e4d85b54c51720e5e5910`、`5485c44b48864642932d3d4cc89c27d8c7e1bf83`。
- Actions `36334400381`：源码门、Kotlin 桌宠测试、Flutter analyze/tests、Release APK、受保护资源和原签名检查全绿。Artifact `10936764488`；未发布 Draft `397733803`（`untagged-ee25d52fcd975a9a0068`），APK 726,018,934 字节，SHA-256 `4a4540dbd8b9196435c597d8558e2a09e7fc2be4267b7a8a892925dab63fe82c`，签名证书 SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。
- 状态：`IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。真机优先验证原 ZIP 再导入、画面真正加载/三配件、自主待机与桌宠旧方形内点击拖拽及两侧透明区；CI 不证明系统触摸透传。

## v0.42.33+277 · 菜菜加载诊断、桌宠真实方窗与 Jev 气焰复核（2026-09-27）

- 用户真机证据：+276 导入后仍无可见 Live2D，桌宠点按和拖动范围没有变化；启用菜菜 Live2D 时输入框唤起输入法明显卡顿。Jev 最近五轮有四轮回退 DeepSeek，旧报告只记状态/费用，无法还原选项与气焰。用户要求质量优先，同一批处理，不将先前 CI 绿色等同真机成功。
- 源码对照：桌宠新动作前 `b656d06^` 的 `WindowManager.LayoutParams` 宽高均为 `windowDp`；中号 152×152dp。新版 `98f42ac` 是 270×152dp，+276 只拦事件起点，透明左右区域仍属于系统窗口。菜菜实验室 `catkiss62/Caicai-Maid-Live2D-Accessory-Lab` 的 `fb04512f940d159ebe13bebc13d2eda5cb54fc9c` 以 `accessory-lab.json` 中 `mainModel`/`accessoryModel` 读取 ZIP、UI 显示导入/加载、同一 `SenCompanionView.loadModels` 回调 `onReady/onError`；宿主此前构造 PlatformView 时先加载模型、之后 Flutter 才注册回调，可能丢失结果。缺真实 ZIP/真机日志，不能断言这是唯一导入故障。
- 实施：桌宠物理系统窗恢复为方形，已有宽窗位置按半幅差迁回，缩放、角标与默认停靠同步；宽动作会按方窗 fit 显示，边缘宽特效可能裁切，需真机验视觉。菜菜解压/清单/暂存/渲染/失败回退每阶段记录到本机诊断；两处导入入口展示进度及保存后的验证指引；Flutter 注册回调后显式 `start`，原生状态可查询；旧 EGL surface 的 `onReady` 不提前确认新包。原生仓库事务跨适配器实例共享锁。聊天输入获得焦点时原生 GL 改为按需绘制，输入法关闭恢复持续帧；这是针对持续渲染的降载，实际厂商输入法速度待真机测。
- Jev 临时策略：移除本地 `confidence < 0.55` 强制 DeepSeek 回退，有效分布按已返回的最高概率选项；前两项差值 `<=0.10` 时气焰互动=ordinary、自身玩闹=none、主动开玩笑=closed、突破=wait；模式本身仍取最高项。如果 API 只报告被选项概率，则沿用该选项、不假造第二概率，诊断标 `probabilities_complete=false`，近似平局无从判定；待真机报告核对是否发生。技术失败/禁用仍回原 DeepSeek。用户更正小豆丁每个已完成回合固定减 18，和正常形态同为 -18；近似平局仍执行固定衰减。每轮本机 `jevShortUsage` 导出状态、请求上下文/问题/选项、Jev 原选项/confidence/返回的概率、最高项/中性与实际采用、用量/费用/耗时；`playfulHeatTrace` 导出用户及助手分类、各加减项、前后气焰及形态。包含有界对话正文，用户保存诊断时属于私密材料，绝不上传公开 Git/Draft。
- **Jev 持续观察，直到明确验证成功**：每次后续有存档或诊断，按当轮用户与助手语义逐项评价 Jev 分类对错，识别 `used`/`used_neutral_close_probability`/技术回退和对应 DeepSeek 调用，用 `playfulHeatTrace` 复算每轮 -18、互动加分与形态变化；比较误判率、近似平局比例、用量和延迟。不能凭单一 `confidence` 当作正确率；没有真实样本时状态保持 `TRUE DEVICE PENDING`。尤其核对用户反馈五轮四次回退在新包是否消失及真实玩法是否被过度记分。
- 验收：CI 测 Kotlin/Flutter 与完整 APK；真机需导入原 ZIP，记录 `file_selected → unpacking → manifest_validated → import_staged → render_loading → render_ready → render_verified` 或具体失败阶段；复导不丢上包；查看三配件动作及唤起/输入/关闭输入法，桌宠左右空白透传和视觉尺寸；同一份诊断检查 Jev 两人分类和气焰账。开工状态 `IMPLEMENTATION IN PROGRESS / CI PENDING / APK PENDING / TRUE DEVICE PENDING`。
- 首次更正后的 Actions `36340823563`：源码回归通过，但 Kotlin 步骤的 Flutter 预编译发现设置页 Jev 连接测试仍传已移除的 `confidenceFloor` 参数，故在编译阶段失败；按编译日志移除该参数，扫描全部源码无其他调用点。GL 按需绘制时再导入模型显式请求一帧，确保排队的模型加载能够消费。
- 第二轮 Actions `36341488592`：源码、Kotlin、Flutter analyze 均过；Flutter tests 954 通过、3 失败。两项旧 Jev 用例只给被选项概率，新解析器误将其视为无效而转 DeepSeek；新近似平局用例的 mock 辅助函数错误地强制每批都有 `route` 问题。修复为接受有效稀疏概率、仅在至少两个概率已返回时判近似平局，并在诊断注明概率是否完整；测试 helper 改为验证问题集合存在，不预设单题。
- 最终功能 head `6029aec55c6dcbaf9ca0ca35d499fbdaf8021a9f`，tree `60cf73cb5fd706ddd7632ca16984dbfab4da18b9`；Actions `36342200023`：全部源码门、Kotlin 测试、Flutter analyze、957 项 Flutter 测试、Release APK、完整资源与原签名校验全绿。Artifact `10939257571`；未发布测试 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-99f8ed3dbab5914d561d`，APK 名 `AI-Companion-v0.42.33-277-Caicai-Render-Pet-Jev-Audit-APK.apk`，SHA-256 `aa4b74609c9a008a5e9e1cde3ab4d383ccdd2c5b8a40e9cdf429e6d7c0c60fa1`，签名证书 SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。成功监控 `.ci/v04233-monitor.txt` 已核对。最终状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING / JEV ACCURACY PENDING`；真实 ZIP 渲染、三配件、输入法手感、桌宠透明侧区透传与 Jev 语义正确性尚未由设备证明。下次拿到诊断和备份必须逐轮评估，不因本次构建通过解除持续观察。


## v0.42.34+278：停止尺寸倒退，修复 Live2D 宿主并接动作

### 用户验收事实与边界

+277 的绿色 CI 不代表手机成功。用户确认新桌宠动画重新变小；导入提示成功但舞台仍要 ZIP；**没有模型也只要启用 Live2D 就卡输入法**。本轮用户重新授权实施/推送/常规 Actions，要求独立 Live2D 分类、侧栏入口替换、删除确认。保护批准的动画尺寸/素材/147% 校准，保护菜菜已经调好的配件与可动参数，保护 Jev 气焰最高概率/近似平局中性/每轮 -18。

### 证据与实现

完整来源、包哈希、宿主与原始算法边界见 `app/docs/LIVE2D_HOST_AND_PET_TOUCH_v0.42.34.md`。实际检查菜菜 fb04512、两份桌宠参考、SoulLink Jev 文档及用户定版素材包，未重新猜测配件运动算法。+277 方窗口导致宽动画适配缩小；onError 自动 rollback 可能删掉首次导入候选；旧 Flutter AndroidView 无模型也创建原生子树。这些均有代码路径证据，具体手机渲染错误尚无新版诊断确认。

实现：宽绘制/窄系统输入区域分离、输入区域实测状态诊断；导入成功 revision 单次重建，渲染错误留包；空模型零 PlatformView；直接 Hybrid Composition/原生禁焦点/IME 暂停连续绘制；独立设置与二次确认；原装预设、形态、Jev 四帧动作、现有 AudioTrack 口型。原始 26 文件经剥离明确标记宿主增量后校验仍等于上游基线。

### 验证状态

已加入无模型/IME、删除确认、参数边界/一次 Jev 请求、原生计划退出与口型所有权测试。当前工作环境缺 Flutter/Kotlin 编译器及 CI 才恢复的受保护素材，不能声称本地编译通过。常规 Actions 将执行完整素材还原、源码门禁、JVM/Flutter 测试、分析、APK 与稳定签名。提交、Actions、Draft 及结果在实际完成后回填。

**Jev 持续观察**：之后每份诊断/存档同时检查语义最高概率选择、近似平局处理、实际气焰结算与固定 -18，新增外观动作 lane 不替代气焰诊断。未经明确手机验证不得标 `TRUE DEVICE PASSED` 或 `JEV ACCURACY VERIFIED`。

### +278 构建与交付回填（2026-09-27 UTC）

- 功能远端提交 `499584371fe073c92484434966b2611ade4aaf80`；后续版本门禁修正 `f872f682c43d32c1c8272c20d2fb7c0d9276fb89`；最终构建提交 `cf69e61ee44c39e9ee35f0f28de81412194c9f19`，源码树 `fb6c2fa6f9596ec70c873020c56109e7b589f905`。本地最终功能提交 `96e46ebb` 与远端树完全一致。
- 首轮 Actions `36347437027` 因漏更新六个历史版本号允许列表失败；第二轮 `36347824045` 因新 Hybrid Composition 文件漏导入 `PlatformViewHitTestBehavior` 失败。均未生成 APK。补齐允许版本与导入，没有跳过功能断言或测试。
- 最终常规 Actions [36348468407](https://github.com/catkiss62/ai-companion-build/actions/runs/36348468407) **全绿**：127 项源码门禁、Android 编译与选定原生单元测试（含新增参数计划）、Flutter analyze（沿用非致命 info/warning 策略）、**961 项 Flutter 测试通过**、Release、稳定签名、Genie/全部桌宠/LingChat 等打包资源验证。
- 未发布 [测试 Draft](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-6ed4643eeffc9f1affc5)：release `397797809`；APK asset `593748006`；文件 `AI-Companion-v0.42.34-278-Live2D-Settings-Pet-Touch-APK.apk`；726,041,646 bytes；SHA-256 `0c9669b808bd1edc002f375a6bb918d59a947de869c6d90bd5a5b061ebdb4f5e`。
- Actions Artifact `10940644751`；APK 校验文件及 CI Monitor 同在 Draft。状态 **IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING / JEV ACCURACY PENDING**。
- 真机尚未接入本工作环境。下一次验收先查空模型开关与键盘、定版 ZIP 后实际画面、动画大小、触摸空白透传；然后查原装预设/形态/语音口型。诊断中的 `overlayPetTouchRegion` 必须是实际 applied 矩形；内部 API 的 ROM 兼容失败不能称为已收紧。模型渲染错误保留完整堆栈且不得再次自动删除包。Jev/气焰继续按顶部持续观察协议分析。

## v0.42.35+279 · 定版 ZIP 与原生宿主／站立图触摸核查（2026-09-27 UTC，开工）

- 用户最新要求先读菜菜原项目、实际定版 ZIP、伴侣的导入/渲染宿主与桌宠绘制/触摸完整链路，确认真正问题再改。用户明确桌宠仅按**原始站立立绘的可见边界**设触摸，不缩动画。持续授权该窗口开发分支推送与常规 Actions/Draft APK。
- 基线：当前远端 HEAD `6869255`，最近五提交 `6869255 / cf69e61 / f872f68 / 4995843 / 32ec831`，Actions `36349661753` success；+278 仍未有真机通过证据。实际用户 ZIP `菜菜女仆三配件-定版素材-v0.1.38.zip` 的 48 项含双模型、贴图、物理、清单、binding profile；`mainModel` 和 `accessoryModel` 所指均真实存在。最新 ZIP SHA-256 `e0406d0679caf2484edf6703763b8d50bcdc4164689fc836c3a2cf5dc291bc28`，与先前同名包 `7ee62838…` 的条目集合一致，只有 `sen-accessory/SenAccessory.2048/texture_16.png` 的 CRC/内容变化。README 明确这是两模型由 Android 渲染器叠合的私有素材，不允许放公开仓。菜菜实验室 `fb04512` 的 `MainActivity.importPackage/loadModels` 为参照；原生渲染算法保留来源校验。
- 已确认宿主范围：`CaicaiLive2DBridge` 的 SAF、`CaicaiModelRepository` 的 staging/current/prefs、`CaicaiPlatformView` 的启动与 GL 回调、`CaicaiLive2DStage` 的 PlatformViewLink 与聊天页面 stage 位置。桌宠范围：`PetSkinManifest` 的 `IDLE → idle_front`、`PetAnimationPlayer` 帧、`PetFrameView` 的缩放/锚点/位图绘制、`PetOverlayWindow` 宽系统窗口、`PetTouchableRegion` 的内部 insets 注册。现触摸只取旧方形，不依据站立图的 alpha 边界；内部 insets 在某些 ROM 可能不可用，只有诊断 `applied` 能证明实施。
- 保护边界：不改定版双模型纹理、moc3、运动参数与 Java 原生算法；不改桌宠贴图、帧数、宽窗口、147% 缩放；不改 Jev、TTS 结算和 schema。具体实现和验证结果待回填，不能将 CI 绿色或 ZIP 结构通过称为真机渲染成功。
- 查明的失败路线：Sen donor `model3.json` 声明 26 个纹理槽，定版 ZIP 仅含 `06/16/19` 三张有效图；菜菜原生 `requiredTextureIndices()` 按三配件 drawable/遮罩只选择必要槽。不能照主模型把全部 26 张强制校验，否则会错误拒绝已在实验室使用的定版包。主模型七项引用和 Sen 六项运行必要引用均在最新 ZIP 内存在且非空。
- 已实施：导入事务在切换当前包前校验真实引用；Sen 按原 selective loader 的 `06/16/19` 校验，保留其它槽缺省。原生宿主设置媒体 Surface 的层级，加载中保持 GL 连续帧，记录 `surface_created/changed/destroyed` 及尺寸，出错保留包；原生 Java 运动与双模型投影未改。桌宠以 `IDLE → idle_front` 第一帧 alpha≥32 的像素行合成系统输入 Region，本机手势用同一 Region，缩放重新生成；宽视觉窗口、资源、147% 校准均保持。内部 insets 接口对 ROM 的兼容仍必须看实际 `overlayPetTouchRegion=applied:…:alpha` 和底层点击。
- 本地验证：新旧 ZIP 逐项 CRC 对比仅 `texture_16.png` 不同；按代码校验集合重放最新 ZIP 全部主模型七项/Sen 六项均通过；`git diff --check`、YAML 解析、+278 宿主门、菜菜资源来源门和总账门通过。完整 127 项套件本机前 28 项通过，在第 29 项因 417 份受保护桌宠原始帧未在公开仓而停下；本环境无 Android/Flutter 编译与用户手机，CI 编译/真机显示状态仍待验证。版本与常规 Actions 配置已准备为 `v0.42.35+279`。构建结果另行回填。

### +279 构建与交付回填（2026-09-27 UTC）

- 功能与宿主远端提交 `cbac8b81b77bf1a84adee11cb368fe98df967b49`；历史桌宠门禁同步修正 `3af8e3944a5b315c0af7645c3bc3f773e6d43cf0`，构建源码树 `b823f3ed…`。最初 Actions `36352030673` 在第 30 项旧门禁上失败：门禁仍断言方形触摸坐标表达式，与新的站立图 alpha Region 冲突；修正门禁要求后重新全套构建，未跳过功能实现或该门禁。
- 最终常规 [Actions 36352508874](https://github.com/catkiss62/ai-companion-build/actions/runs/36352508874) **全绿**：127 项源码门禁、Android 原生编译及相关测试、Flutter analyze/测试、Release APK、稳定签名、Genie/完整桌宠和其它固定资源打包校验均通过。签名证书 SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。
- 未发布的 [测试 Draft](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-51cf4439c183e4442fdc) 已完成上传；APK `AI-Companion-v0.42.35-279-Caicai-Host-Standing-Alpha-Touch-APK.apk`，SHA-256 `04b4b8f086dd10bc91080734097a655895dd88b5c998c4a0c5fdbcfea248eac7`。Actions Artifact `10943216129`，另有同名 `.sha256` 及 CI Monitor。监控记录 `.ci/v04235-monitor.txt` 写入 `ci-monitor-v0345`，状态 `success`，构建 HEAD 与签名、校验值均一致。
- 状态 **IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING / JEV ACCURACY PENDING**。本环境未连接用户 Android 设备，不能从绿色 CI 推断菜菜在用户手机实际出画、口型/动作、键盘共存、桌宠 alpha 透传在目标 ROM 生效。真机重点：导入这份 SHA `e0406d06…` 的最新 ZIP；检查两模型与三配件显示、键盘开合、桌宠透明区域底层点击及站立轮廓点击/拖动。诊断 `overlayPetTouchRegion` 必须出现 `applied:…:alpha`，若为 `failed`/`pending` 则记录设备和日志以继续定位系统 insets 兼容。Jev 预测准确性需实样对照，继续按顶部观察协议。

## v0.42.36+280 · 真机失败证据驱动的导入、桌宠与 Agent 调用修复（2026-09-28 中国时间，进行中）

- 用户 +279 真机诊断 `ai_companion_diagnostics_2026-09-28T00-57-57-591331Z.txt`：六次导入有选取、解压、清单校验与 `import_staged`，没有 `import_failed`，最后 `available=false / pending=true / render=not_open`，说明设置回调没有把模型带进 PlatformView；未记录正式目录究竟哪条索引或文件失败。桌宠状态 `unavailable:NoSuchFieldException`，表明 +279 隐藏 `OnComputeInternalInsetsListener` 方案在 REDMI K80 Ultra / HyperOS 15 未注册。上述是 **TRUE DEVICE FAILED**，不能以 +279 CI 绿色代替。最新 ZIP 的结构检查已通过，不能继续猜“用户没导入”或“ZIP 缺资源”。
- 已审阅当前 `CaicaiModelRepository → CaicaiLive2DBridge → CaicaiLive2DStage → CaicaiPlatformView` 和菜菜实验室的双模型启动；导入切换正式目录后逐个读回主/配件模型，索引无效时从 `accessory-lab.json` 的相对路径恢复，仍失败则直接报真实读回错误并回滚；状态向界面传递具体 detail。原生 Cubism 动作/投影不动，私有 ZIP 不进入公开仓。
- 桌宠对照 `d8d4417` 旧双窗口与 +278/+279 的宽单窗：旧非触摸可视窗 `alpha=.79` 使主体半透明，`alpha=1` 会挡掉下层点击；+279 的隐藏系统 insets 在本机报 NoSuchFieldException。当前改为 112/152/200dp 的物理系统触摸窗，宽动画由已连接的现有无障碍服务承载 `TYPE_ACCESSIBILITY_OVERLAY / FLAG_NOT_TOUCHABLE / alpha=1` 的独立可视窗；无服务、添加失败或服务失联时退回矩形内绘制，并把 `visual_clipped` 后的具体原因写进诊断，不能称为视觉/透传验收。历史 alpha Region 与失败反射类已移除，窗口位置与 147% 校准保留。
- 追溯旧 `v0.35.7+82`：明确命令本地快路由，其余需要工具的轮次在同一次 DeepSeek Chat Completion 附原生函数 schema，由主模型语义选择；无工具调用时不增加规划请求。后来项目新增 DeepSeek 内部规划 + 可选独立最终回复模型，旧单请求方法仅能原样用于 DeepSeek 单通道，不能让第二通道越过既定内部工具权限。9 月 27 日 `be9bbf5` 把“15 分钟内活跃单人游戏”放宽成任意紧邻助手消息都开放 Cedar，导致普通聊天也进入 DeepSeek `agent_tool_planning`；诊断最近样本为该 lane 11 次、`final_reply` 17 次，不能说每轮都加，但频率明显过高。前一个 `98f42ac` 固定短语候选又漏掉“那就去吧，我陪你”。
- +280 路由修正：宽话题词不再使普通提及“记忆、相册、天气、游戏”启动规划；游戏自然续话只在真实可继续单人会话、15 分钟内、上一条助手消息明确谈游戏且用户为短回复时成为候选。DeepSeek 单通道直接把 Cedar schema 放在正常请求中，让主模型判断；独立最终回复通道先用已有 Jev 短判断判断最新话语是否授权现在推进游戏，Jev 判无则不发 DeepSeek 规划，判有再交 DeepSeek 选动作；Jev 不可用时仍交给原有 DeepSeek 工具规划，不静默丢失邀请。工具执行仍经真实指南/权限/Outcome 门。测试覆盖“那就去吧，我陪你”、普通鲸鱼尾巴/抱抱、过期会话、Jev 正反判定及不可用回退。此方案的语义准确性和调用成本待真机样本验证；不会把静态候选测试冒充模型判断效果。用户新指出的“说话动作停不下来”另需对真实播放状态核实，不凭模型调用统计猜改 TTS。
- 构建前本地 127 项门禁中 124 项通过；其余 3 项依赖私有 417 帧素材、LingChat 素材或本机没有的 `kotlinc`，已由下述 Actions 在恢复固定资源后执行。
- 构建过程：首轮 Actions `36367245272` 在 Kotlin 编译失败，`PetOverlayWindow.kt:1253/1255/1257` 把 Float 校准偏移传给只收 Int 的 `dp()`；127 项源码门禁已通过，但 Flutter 测试和 APK 尚未运行。修复提交 `437f0c8e6cccadb23ac1fb7de57872250ebcdf47` 将偏移按 `displayMetrics.density` 保留浮点精度换算，再由现有 `roundToInt()` 合并边距。失败报告作业本身未成功上传监控，故以 Actions 作业步骤与日志为准；不能把首轮状态当成功。
- 修复后 Actions [`36370446031`](https://github.com/catkiss62/ai-companion-build/actions/runs/36370446031) 全绿：127 项源码门禁、Kotlin 原生编译与测试、Flutter analyze/测试、Release APK、签名与固定资源打包校验、Draft 上传均通过。Artifact `10949561191`；签名证书 SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。测试 [Draft](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-a43ab3029f8301924603) 文件 `AI-Companion-v0.42.36-280-Caicai-Index-Pet-Rect-Agent-Route-APK.apk`，SHA-256 `e9f745e445fa7db50b6f63c2697cd96e797f62ca04e86674560384aff0a8e659`；成功监控 `.ci/v04236-monitor.txt` 与 head、SHA 一致。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING / JEV ACCURACY PENDING`。真机仍需确认导入后出画、键盘共存、桌宠框外触摸透传与绘制层是否 `trusted_visual`、自然游戏续话与闲聊的调用统计；说话动作停不下来另列待排查，尚未在 +280 修复。

## v0.42.37+281 · 桌宠残影、固定待机触摸范围与 Live2D 背景穿透（2026-09-28 中国时间，进行中）

- 真机证据：+280 的模型导入已经成功；聊天页 Live2D 背景显示上一次操作页面；“更多”页顶部有两层、随后三层相同桌宠，旧画面冻结且手指穿过；用户进一步给出稳定触发路径：进入小米系统文件界面（存档/读取）时产生假图片，说明不能简单当作两个可交互桌宠。桌宠视觉也再次缩小。+280 的 `TRUE DEVICE PENDING` 由此更正为 `TRUE DEVICE FAILED`。
- 根因检查：+280 的桌宠主触摸方窗和辅助可信宽绘制窗同时存在；`bringToFront` 又在悬浮聊天的输入模式切换时对主窗执行 remove/add；更直接的是系统文件界面进入时 `retireBubbleForSystemCover` 在 `removeViewImmediate` 成功前清空窗口所有权，失败后恢复会追加新窗。聊天 `IndexedStack` 保持原生 `GLSurfaceView`，切页时透明像素可能显示已离开的页面缓冲。以上为源码对应的风险，不以 CI 代替真机因果证明。
- 保护边界：旧版已确认宽动画显示尺寸不缩水；小中大按原 `IDLE/down` 第一帧 alpha 定义静态触摸范围，新动作、特效和自主动作不扩张命中。透明区域由系统输入分发直接透传，失败时整窗不可触摸，不退回宽矩形；不使用隐藏 insets 反射。Live2D 保持已成功导入的模型、Hybrid Composition 和模型 ZIP 私有性。
- 实现：单一宽且留出大动作绘制边距的 `TYPE_APPLICATION_OVERLAY` 负责桌宠显示和输入，保持 +278 的宽绘制缩放基准及原逻辑高度，按旧待机帧原始 alpha 像素映射到窗口局部 `Region` 并调用 API 33 `AttachedSurfaceControl.setTouchableRegion`；初始及重挂载、尺寸变更先 `FLAG_NOT_TOUCHABLE`，mask 成功后才解锁。系统文件界面进入时先隐藏旧窗口，移除成功才释放并清空所有权；重建时移除失败保留旧引用并有界重试，避免生成孤儿图层；移除悬浮聊天输入状态变更中的重复 remove/add。聊天页不处于当前 tab 或 route 时释放原生 Live2D，dispose 前立即隐藏 GLSurfaceView。
- 验证：+281 初始提交 `f883811` 的 Actions `36374983658` 在旧版本静态校验处停下；六个历史校验器只允许到 +280，已补充 +281 并逐个本地通过。下一次 `36375657702` 的 Kotlin 编译发现浮点偏移误传整数 dp，已修正。最终构建 head `203ee46721285f0776b8225419e05c1b5efc99cd`、Actions `36376305397` 全绿（127 项源码校验、Kotlin 桌宠测试、Flutter analyze/test、签名及素材校验），Artifact `10951905935`，APK SHA-256 `38ea4ccaaf3247ba3faecfc5fa2d1108b41267f89fca56345223b3631c569f77`，未发布 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-fb9ac196917098c4e4f2`。用户实测：旧待机范围外虽不能拖动，但底下 UI 点不到；贴边距离变远；Live2D 主后台变黑、切页重新加载、键盘拉长。故明确更正为 **TRUE DEVICE FAILED**；上述静态 mask 不能被当成透传证据。

## v0.42.38+282 · 旧桌宠逻辑尺寸、可信透传与 Sen 稳定宿主（2026-09-28 中国时间，进行中）

- 用户验收标准：小中大三档均以旧 `IDLE/down` 可见像素为固定输入范围，超出范围必须由底层 App 真正收到点击；新动画可以超出这个范围显示，不允许缩小身体取巧；旧版关闭新动画时同样遵守早期贴边与输入规则。小米系统文件界面进出不产生冻结残影。菜菜在主后台、切 Tab/侧栏仍保持同一个模型实例和正确背景，输入法弹出时不被拉长。
- 追溯：删除 Sen 的 +244 前代码为普通 `AndroidView` + 无 `setZOrderMediaOverlay(true)` 的 `SenCompanionView`，聊天舞台 `Positioned.fill`；当前菜菜的 `PlatformViewLink/initExpensiveAndroidView`、媒体 Z 层、切页销毁/重建、输入法额外高度均偏离该路径。旧桌宠逻辑方框 112/152/200dp 被 +281 的宽绘制窗口尺寸代替作为运动/贴边边界；Android 12 起不可信应用悬浮窗的遮挡判定使仅调用 `setTouchableRegion` 仍可能拦住底层点击。
- 本次实现：有连接的无障碍服务时，改为**单个** `TYPE_ACCESSIBILITY_OVERLAY` 可信绘制兼输入窗口，用原待机 alpha Region 给系统输入分发，窗口管理器在系统文件界面移除路径保持一致；逻辑方框独立于可视溢出计算重力、运动、贴边、旋转迁移和尺寸调整；输入 Region 在位置更新后重应用。无障碍服务不在时退回旧尺寸方窗，避免宽应用悬浮窗吃掉大片点击，这条降级路径仍需实机验收。菜菜恢复普通 AndroidView 与无媒体 Z 层，聊天 Tab/route 不销毁平台视图，键盘时舞台保持布局高度。原生模型算法/私有 ZIP 未动。
- 构建前状态：**IMPLEMENTED LOCALLY / CI PENDING / APK PENDING / TRUE DEVICE PENDING**。必须在用户手机实测三尺寸旁边按钮、贴边、文件界面多次开关、主后台黑屏、Tab/侧栏返回加载次数及输入法；CI 不能替代这些验证。
- 构建回填：初轮 `36380024118` 在 20/127 旧版版本白名单失败，五个遗漏门禁补充并本地逐项通过；最终功能 head `56e628f25ebd133fa9d2c38ffcf005281e610162`，Actions [36380517278](https://github.com/catkiss62/ai-companion-build/actions/runs/36380517278) **全绿**（127 项源码门禁、Kotlin 编译与桌宠测试、Flutter analyze/test、Release、固定签名及资源校验）。未发布 [测试 Draft](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-0130fd8887312ddd45ff) `397962996`，APK `AI-Companion-v0.42.38-282-Pet-Trusted-Touch-Sen-Stage-APK.apk`，726,053,350 bytes，SHA-256 `f320fc1f3c029124d807286d8a33227a03696055f512c8660c2ee2ff67dfaef4`。状态更新为 **IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING**。真机特别验证：开启无障碍服务时三尺寸桌宠范围外点底下按钮是否真实生效；贴边是否恢复；小米系统文件界面多次进出无冻结层；Live2D 后台返回无黑底，切 Tab/侧栏不重载，输入法不拉长。

## +283 正式记录（2026-09-28，中国时间）

- 授权：用户批准先推送 `catkiss62/ai-companion-build` 当前分支、完成本批修改后构建一次 APK。当前环境最初的本地 +279 分支落后远端 +282；保存旧分支到 `backup/local-v04235-before-sync`，本批从远端 `3dcc96b` 接续。HTTPS git push 无凭据，采用已连接的 GitHub 写入能力更新同一分支。不得强推、合并 main 或公开用户附件。
- 私密证据：2026-09-28 08:56 `.aibackup` 与诊断只在本机分析，绝不进入仓库。诊断近 120 次模型使用的 `agent_tool_planning` 21 次，累计 429,189 input / 19,480 output tokens；`cedar_toy_no_call_recheck_count=23`。16:49 对“怎么还有这么奇怪的游戏啊，买菜做饭……感觉还是钓鱼更实在”做了两次有工具 schema 的规划但零调用；16:50 对“但是你最近钓鱼很欧呢”又做两次规划才实际 `cedar_toy.play`。该样本的 Jev short usage 无 `cedar_context_intent`：误触发来自 Cedar 标题/钓鱼宽泛入口及 no-call 重查，不是 Jev 输出错误。备份里 `messages.model` 曾将第二通道正文记成内部模型，单看字段不能证明真正生成者。
- 实现：Cedar 明确指令入口要求动作语义；“你最近钓鱼”不再命中陪伴单人游玩；陈述/随口讨论可直接进入普通最终回复，真正游戏请求和已有会话的语义跟进仍保留。Gemini 首稿需事实或重复修正时，最多一次 Gemini 修正并直接发送；第二通道传输/配置/完整性失败才用 DeepSeek。主动消息及 Cedar 房间发言同样遵守第二通道优先，保存可见正文实际模型。限制修正次数为一次，保留真实操作事实强校验。
- Live2D：导入状态只显示“已导入模型”或“未导入模型”；增加十九种持久情绪与正常状态的预览按钮，Jev 在同一批动作问题里选择对话情绪，不再固定映射回复关键词；调皮的本地持久参数采用 wink+吐舌。原模型、用户素材与旧 Sen 冻结资源保持隔离。
- 验证与交付：本地针对性源码门通过；Actions `36411092518` 源码门、Kotlin、Flutter analyze、966 项 Flutter 测试、release APK、固定签名与素材校验全绿。远端提交 `a6834a368e7179ccf342bc269951e4335e191f55`；Draft `v0.42.39-gemini-cedar-caicai-test`（release 398130580）含 APK、SHA 文件和 CI monitor；APK SHA-256 `abe13d897590698cab52e7d2c829414028e76f2b79a573da8f5fc4ed9d5ee06b`。状态 IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。真机仍需观察 Gemini 调用日志、Cedar 零调用规划、情绪持续与触摸。


## v0.42.40+284 菜菜专项表演与聊天舞台

状态：CI PASSED / APK READY / TRUE DEVICE PENDING。

- 实现：新增菜菜专用可见轴待机、局部重心短语及十九情绪的实际女仆参数；Jev 四段语义选择加强 X3/Y2/Z 与身体 XYZ，摆胯/wink/吐舌增加同段释放，不增加模型调用。
- 舞台：TextureView 单 EGL owner，窗口表面与 context 生命周期分离；30 FPS，不因输入框停帧；键盘仅裁切固定比例的舞台。原菜菜 renderer、配件投影和 shader 通过原始哈希校验。
- 操作：控制后回聊天；聊天内舞台/摸头区域编辑、确认/取消；摸头区域按模型参考边界存储，连续抚摸触发点头/歪头/笑眼；Activity 观察触点不消费控件事件，头眼有平滑跟随和释放。
- 时限：手动表情/原装动作采用单次租约，4.12 秒发起 0.38 秒原生退场，总时长目标 4.5 秒；替换动作不会遗留旧定时器。衣装保持，聊天情绪保持。
- 气焰：普通形态不再固定扣 18；小豆丁保留 −18，严肃额外 −12 和每小时 −3 保留。补充普通累计、普通中性保持和小豆丁独立扣减测试；不修改存档历史。
- 桌宠缩小未获得确切原因，不改桌宠代码。附件未上传。
- 当前限制：尚无本版本真机录屏，无法认定“幅度/速度已达到用户预期”或“切后台/输入法设备问题已消失”。构建和设备证据将分别补记。

- 本机验证：源文件差异无空白错误；菜菜原始 renderer/配件/Framework/资源哈希通过；127 项正式 gate 前 28 项通过，第 29 项因本工作区未恢复 CI 专用 417 文件桌宠资源停止，交给固定资源齐备的 Actions 执行剩余 gate。没有把未执行的 Flutter/Android 编译及测试写成通过。

- 补充实现：动作参数索引/限值按模型缓存，避免每帧线性扫描完整参数表；聊天不可见时暂停绘制；清除手动预设保留装扮；显示失败提供重试。
- 本地执行 Java/JUnit：`CaicaiParameterPlanTest` 与 `CaicaiPerformanceTest` 共 5 项通过（实际时间 0.04 秒）；覆盖短计划释放/受保护参数、60 秒待机幅度/连续性、注意力抢占释放、菜菜真实参数表情。
- 首轮 Actions：36422468888，功能提交 104db6c；构建进行中。交互回归与专项设计文档随收尾提交补齐，最终 APK 以最后一次成功 run 为准。

- 重载交接复核发现并修正：CubismFramework/Shader 是进程全局状态，新旧 TextureView 的 GL 线程不能并行初始化/释放。用单一全局租约在 GL 线程交接；旧 renderer 完成 release 和 EGL 销毁后才释放租约；从未创建 context 的旧 view 不调用全局清理。UI 线程不等待。此项为本次新宿主必须具备的保护，随最后构建重验。
- 第二轮 Actions 36424013404：源码回归、Android 原生编译/测试通过；Flutter 970 通过、1 失败。失败为新加的导航测试在新路由首次 build 之前等待 SQLite，随后 pumpAndSettle 推进虚拟时钟导致加载超时。补上首次 pump 与有界真实 IO 等待，保留导航断言；两项确认/取消测试已通过。不得把此轮记为 APK READY。

### +284 最终交付核验（2026-09-28）

- 最终功能提交：`b7b578a3e06a7630b22062c4805c83f307900b8d`；tree `b6045d7b07d1457069e6a1bd1608a27e88a90f5b`；分支 `agent/v04232-caicai-import-pet-touch`。后续总账提交不改变 APK 功能。
- Actions：`36426075648`，build job `108940275928`，全绿；127 项源码回归、Android 编译及原生测试、Flutter analyze（既有非致命提示不作零警告声明）、**971 项 Flutter 测试**通过；包括自动返回聊天与调整确认/取消。稳定签名、Genie/桌宠/塔罗等固定资源完整性检查通过。
- Draft Release：`398253913`，tag `v0.42.40-caicai-performance-test`，保持 draft；链接 https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-6c1bbb4fd7e86a6bc5ce 。
- APK：`AI-Companion-v0.42.40-284-Caicai-Performance-APK.apk`，726,078,514 bytes；asset `595463873`；SHA-256 `232ae45bf50ddfd5c7643f65d35584e9114ffd39899f201acf7cc40a2f1f98ff`。构建输出与 Release asset digest 一致。
- Actions artifact：`10972990521`；校验文件 asset `595463874`；最终成功 CI 记录 asset `595463881`。没有发布正式 Release、没有合并 main，没有下载整包 APK 到本工作区。
- 设计及逐项验收：`app/docs/CAICAI_PERFORMANCE_DESIGN.md`。主要覆盖菜菜可见轴大动作、Jev 四段表演与局部释放、手动原装预设 4.5 秒、自动回聊天、同屏舞台/摸头框编辑、全界面触点观察、真实摸头、键盘固定比例、EGL 保持与交接、普通形态不固定扣 18。
- 尚待真机：实际幅度/速度是否符合参考 APK 观感；输入法延迟、前后台/页面切换与重导入/重试稳定性；摸头框与模型大小/位置的实际吻合；连续对话的 Jev 原始选项、动作采用与气焰账。不能将 CI 全绿写成 TRUE DEVICE PASSED。
- 桌宠缩小：没有确切尺寸变更因果证据，依用户要求未改桌宠行为代码。


## +285 Live2D 恢复、完整第二通道路由与截图默认值（2026-09-29）

### 范围与实现

- 用户授权修复 Live2D，并明确三项不能遗漏：导入/显示；所有可见正文及真实性修正使用配置的第二通道 Gemini，实际请求失败（含 HTTP 400）才允许 DeepSeek 兜底；桌宠只改截图可见默认值。网页显示卡住的问题暂不处理。
- Live2D：恢复 GLSurfaceView，修复 TextureView 构造异常；规范化导入根目录与相对索引，保留暂存提升/回滚/损坏包保护；处理暂停、临时重挂、先 detach 后 dispose、全局 Cubism 所有权交接。加载状态不再把素材存在当成画面已就绪，增加失败诊断和前台加载超时重试。生产原始 renderer/配件数学和资源哈希不变。
- 保留 +284 大动作/Jev、4.5 秒临时动作、回聊天、舞台与摸头框编辑、全界面视线、摸头、TTS 口型、衣装/配件、19 情绪、气焰修正。原生测试使用空场景 EGL 和结构假模型事务，没有私有模型绘制证据。
- 正文：普通/后台/悬浮桌宠、主动对话及所有分享 intent、Cedar 房间、沉浸、日历入口共用明确第二通道策略；真实性/重复/截断修正仍走第二通道，失败兜底不跨轮继承。系统消息专用请求增加明确“内部表达任务、非真实用户发言”的传输封装；不写假用户历史。DeepSeek 工具规划前言及规划检查点不进入正文。旧截断草稿历史 model 字段不作为供应商证据。
- 桌宠默认：新动画缩放151%、宽度91%、水平0dp、垂直1dp、黑场0、中间调0.86、白场230、输出0/255、饱和度100%；已有自定义值和截图外设置保留。桌宠偶发缩小仍缺因果证据，不猜修。

### 最终交付核验

- 状态：**IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING**。之前 CI 失败及修正原因保留在顶部 +285 记录，不能将前次失败改写成通过。
- 最终功能提交 `6cfca5ae303f384283a653d1627ff4a548150322`；tree `158f220a851934fe91c786c5cfa92f7ddcc225a0`；分支 `agent/v04232-caicai-import-pet-touch`。本次总账收尾提交不改变 APK 功能。
- Actions https://github.com/catkiss62/ai-companion-build/actions/runs/36455411205 全绿。原生 smoke job `109040444025`：API35 的2项 instrumentation 测试通过，生命周期连续4轮，覆盖暂停恢复/重挂/替换/释放以及导入事务。结果 artifact `10984649347`。API29曾发生JIT线程崩溃，旧平台真机兼容性仍未确认。
- build job `109042465341`：128项源码验证、Android/Kotlin单元测试、Flutter analyze、**979项 Flutter 测试**、release APK构建通过。已有非致命静态提示仍在，不声称零警告。原签名、Genie/桌宠/塔罗资源门通过。
- 版本 `0.42.41+285`，schema61保持。稳定签名 SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`；可覆盖安装，无需卸载。
- Draft Release `398368739`，仍为 draft；tag `v0.42.41-caicai-repair-test`；最终链接 https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-56cc9ee2419fc27a69e8 。注意草稿 untagged 链接已变化，不沿用此前失败轮的旧链接。
- APK `AI-Companion-v0.42.41-285-Caicai-Repair-APK.apk`，726,078,982 bytes，asset `595975495`，state=uploaded。SHA-256 `0f28b4dd43a2b5ffe00bedcd21878984c086cbe077d22d3433199f6b454968c6`：构建校验输出、成功 CI Monitor、Release asset digest 三者一致。
- APK workflow artifact `10987060772`；校验文件 asset `595975493`；成功 CI Monitor asset `595975504`，记录对应最终功能提交和成功 run。未下载整包到本工作区。
- 下一步仅为用户真机回归：覆盖安装后确认聊天模型可见、已有包重载/确需时重导、切页和前后台/键盘、动作摸头/TTS；观察主动/分享及修正的实际通道与失败记录。第二通道400根因未被现有附件证实，不能把请求形状修复写成已消除所有400。Jev原始选项/气焰账继续按既定要求观察。
- 不合并 main、不发布正式 Release；私有存档/诊断/模型不上传。原工作区和未提交的 `part-075.bin` 保持不动，未纳入此次提交。网页卡住分析继续暂缓。

## v0.42.42+286 实施记录（CI 前）

- 主要代码已实现：resize同步主/配件Cubism render target；Flutter舞台缓存区分宽度变化；Jev四拍独立幅度/整模意图及全局节奏，同一次批量请求；头身待机加快，头眼/身体跟随增强。
- 整模位移与小腿支点旋转在最终drawMvp共同执行，校准数学保持原哈希；命中走逆变换。摸头由露出舞台Listener转发，短时lease阻止视线/晚到Jev覆盖。设置新增幅度/速度/支点与四项组合预览。详见app/docs/CAICAI_PERFORMANCE_V04242.md。
- 本地JDK可通过模块调用编译器；纯几何/待机检查已执行生产CaicaiRootTransform、CaicaiIdleMotion和CubismMatrix44（使用临时接口/非执行数学依赖桩）：像素比例、支点、不同行列标定后的共同矩阵与逆命中通过；60秒头X原始范围-29.32..29.40、头Y-22.89..27.31，30FPS最大相邻X差2.71。原始值仍须模型限幅，不是设备实测视觉角度。
- 本地源门初检118通过，7项失败是新版本未进历史白名单，已补286；另3项依赖CI恢复资源/kotlinc，不降门禁。新版本尚未CI通过/APK就绪，不声称真机修复完成。

### +286 构建进度

- 功能提交 `8293c7b7851bd54bde29294a041437ba31da8c03`，随后显式转换滑块clamp结果为double，最终待验证提交 `0627376f4f787a072cdabe94c8f25ab78da8b445`。
- 首轮 `36467891844` 因新提交由工作流自动取消，不是测试失败；已完成Java宿主编译并开始3项模拟器测试。
- 当前 Actions `36468439975`；原生门 job `109084683320` 成功，3项测试覆盖实际SurfaceView连续缩放、4轮生命周期/交接与导入事务。结果artifact `10990742490`（沿用旧测试工具名称Caicai-v04241，实际源码为本轮0627376）。完整APK job `109086799034` 已通过129源回归，Android/Flutter编译测试继续中。
- 回退保留的是 +285 的功能源码和原始APK。若后续要回到其功能并覆盖安装，应从该源码重打更高versionCode的恢复包，不依赖Android允许旧APK直接降级，不要求用户卸载数据。

### +286 最终交付核验

- 最终代码提交 `0627376f4f787a072cdabe94c8f25ab78da8b445`；Actions `36468439975` 于2026-09-29 03:17中国时间完成，conclusion=success。129源码/回归门、Android/Kotlin单元测试、Flutter静态分析、982项Flutter测试、release构建、稳定签名与资源完整性均通过；原生3项测试及4轮生命周期证据见上节。
- APK：`AI-Companion-v0.42.42-286-Caicai-Performance-APK.apk`，726090274 bytes；SHA256 `2838c8967924de7144b892c73915f9f283725659909210cb35af9f75943c7da6`。构建日志hash与GitHub asset.digest一致。APK asset `596202913`，sha256旁件 `596202912`，CI monitor `596202930`，均uploaded。
- Draft Release `398534068`，tag `v0.42.42-caicai-performance-test`，target=0627376，draft=true；URL https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-6536c4ec9e8814a55b44 。Workflow APK artifact `10991456188`；未合并main、未正式发布、未下载大APK到本地。
- 签名 SHA256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`，与+285一致，支持从+285覆盖安装。保留模型与既有设置；原先脏的part-075.bin未进入提交。
- 验收顺序：默认幅度100%、速度100%、支点88%下，反复开关输入法观察比例；头眼跟随/触摸摸头；左右探身与小腿支点倾斜预览；最后观察普通对话与主动分享的Jev选项和实际动作。需要时调幅度/速度/支点；第二通道正文及400兜底、桌宠默认继续保留。
- 状态边界：IMPLEMENTED / CI PASSED / APK READY；尚未取得本版私有模型真机录像或诊断，不能称输入法拉伸、延迟、摸头命中或动作观感已真机通过。真实Jev新增问题的服务端选项分布也仍需设备日志验证。+285仍为用户确认的功能基准。


## 2026-09-30 美术与存档完整性后续方案（DISCUSSION / DEFERRED）

用户要求暂时保留本轮六项方案，加急修复后继续讨论；此记录不等于实施许可扩展。背景替换已单独纳入 +299，其余只保留方案。

1. 白天图使用夜景同一房间构图改日光；当前生成工具不能指定/核验用户提及的 gpt-image2.5，预览已告知版本限制。新图需检查普通聊天、沉浸与原生 Live2D 的同资产显示、昼夜切换及裁切。
2. 旧桌宠素材主要为 `app/assets/lingchat/deepseek/`（21张含头像）与 `app/assets/portraits/large_whale/`（20张）。后续整理透明 PNG 与角色/情绪/原文件名对照给用户 PS；保持每张画布尺寸、人物位置与透明通道，回收后转换并按原路径接入，不搬迁资源或改变锚点。
3. 删除七大规则右上角文件导入/导出、剪贴板设定包入口和页面专用逻辑。`AndroidBridge.savePromptPack/openPromptPack` 仍被“模型与联网配置”页面使用，不连带删除；保留规则编辑/搜索/重置、codec 与完整存档的 rule_layers。
4. 左侧栏“代办提醒”上方增加“记住事项”快捷入口，复用 `RememberedUserFactsPage` 和既有 settings 数据；原记忆库入口保留，不改变重要性/提醒机制。
5. 小腿支点整体旋转：Jev/自主待机共享默认1.0、范围0.65～1.6倍速度。待机平滑理论上界默认19.6°/s，幅度/速度最大约47.1°/s；Jev没有独立角速度硬上限，最快节奏最大左右反向场景的理论起始速度默认约137°/s、全部满档约328°/s，属于代码估算而非真机实测或全场景最大值。建议后续单独给 Jev 整体倾斜约30°/s限速，并检查接管、反向、清理归零及回到待机的衔接；用户尚未要求本轮实施。
6. 存档完整性专项：记住事项已在 settings 中；原生 `caicai-live2d` 模型/配件文件与 `caicai_stage` 布局、摸头框、幅度/速度/支点尚未纳入 SnapshotService 的 DB/attachments/album/media 通道；SecureConfig 中部分非 Key 的 provider/endpoint/model/开关亦需单独白名单导出。后续目标为用户数据与可迁移设置完整恢复、API Key 排除、旧存档兼容，采用导出→新安装环境导入→逐项比对；保留已有 Active Brain、运行任务中断与写入围栏，不能用复制设备运行态代替恢复。此次仅修现有导出崩溃，不在加急版扩展协议/原生模型备份。


## +298完整接班记录（从快速索引原样移入）

## 当前实施 · v0.42.54+298 指定时长游戏任务与过程分享（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 用户 2026-09-30 批准直接授权“现在去玩半小时白色房间，看看结果”，并指出游戏过程新进展不能套用45分钟普通主动分享间隔；不能每一步都分享。澄清：旧45分钟、24小时6条、2小时3条按mcp/cedar_game来源统一计数，刚发生与延后分享都受限；普通回忆旧游戏内容不必然走此源通道。
- 基线+297源码6524f3e、结果总账114c97e；独立分支agent/v04254-explicit-game-task-sharing。新增明确时长本机任务入口，模型按语义选择工具、核对真实目录和完整指南；任务仅在正式回复落库后激活，复用唯一Cedar后台执行器/lease/fence，用户聊天暂停计时，时限到/服务器限制/等待人类/换游戏/关闭/重启终止并保留真实结果回报。默认持续竞争仍由Desire决定；任务回报绕过普通欲望抽选而保留Active Brain与写入围栏。
- 分享判断合并到既有下一步原生工具规划，用已存Outcome和已分享内容判断新发现/明显变化，连续结果合并、事件去重；结构化quiet保持执行真值核验快速，不新增每步DS判定。游玩过程值得分享的结果直接排队，移除该路径45分钟/6条/3条额度，不设半小时最多2次；旧经历自主分享保留原普通竞争规则。真实时间、防剧透、MCP凭据、终局/结果快照防重放、暂停/Stop与+297其它六项功能保持回归覆盖。
- 验证计划：时长引用与边界、失败/Stop不激活、已落库恢复、有效计时、提前结束回报、重复投递、结构化过程分享及事件去重；专项源码门、132项完整门、Flutter analyze/test、Kotlin/native smoke与签名APK。未构建/未真机验收前不写PASSED。


- 实施及验证完成：新增cedar_toy.start_timed_play用户专用原生工具，逐字核对1至30分钟时长引用，真实指定目录/完整指南后登记；仅已落库assistant ID激活，过日或超过2小时未启动则过期。同一回合至多一次真实mutation；若先play再登记，后续schema只开放本机时长任务，不重复远端动作。明确暂停清除待启动授权、结束任务并暂停释放该活动；有效时长计数与服务器/疲劳/夜间围栏保持原权威，进程/导入不延长旧授权。
- 回报保留持久outbox，固定message ID与提交前writer/Brain/沉浸围栏防重复；有任务结果即优先交付，不参与普通欲望抽选、不被游戏分享开关屏蔽；报告请求时长与实际usedMs、已确认进展及提前结束原因。过程分享判断合并到已有后台native play规划，结构化quiet继续即时入库；只用已保存事件，排除get_result/状态查询/前台已展示与已分享部分，待发期间合并新事件。旧经历的普通Desire分享规则仍保留；过程direct队列不套45分钟/6条/3条硬额。
- 最终源码869a117ebbd71a2d6cb2e049d3e23af3f1133771，tree6693a12440b12afdb608442b471ea30014446e8e；[Actions 36703913197](https://github.com/catkiss62/ai-companion-build/actions/runs/36703913197) success：原生烟测、132项完整源码门、Kotlin、Flutter analyze/test、arm64 Release、资源/稳定签名全绿，11项新行为回归通过。本地可运行119项通过，13项依赖未恢复资源/Android工具链，已由完整CI补齐。首轮36702658130因加入暂停补强被新版替代取消，不记作源码失败。
- [未发布+298测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-73dccee8ef74735b707f)，Draft399945262，target869a117e，asset600714919，AI-Companion-v0.42.54-298-Explicit-Game-Task-Sharing-APK.apk，726471818bytes，SHA-2569a2ec0b07e556ee270cb32102c5337fbc0267ce0ec654e88784e7d19b4937fc2；Artifact11092411285。CI monitor源码/digest一致，签名30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48与+297相同，可覆盖安装保留数据；未合并main、未正式发布。
- 真机待验：自然说“你现在去玩半小时白色房间，看看结果”无需Desire抽选开始；重要新进展能自然分享，小额重复不每步播报；聊天暂停会顺延有效计时，结束/限制按实际回报；“先别玩了”停止任务；重启/导入不自行重授30分钟。讨论示例和笼统“你可以自己玩玩”不建立固定时长任务。导出诊断仍需持续核对Jev原始概率、实际路由与fallback，未获得本轮真机样本不能标TRUE DEVICE PASSED。+297沉浸冻结、独立情绪层/语音开关、记住事项与圆形原图球作为关联回归保留。

## +299完整接班记录（从快速索引原样移入）

## 当前加急 · v0.42.55+299 存档 CursorWindow 与白天背景（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 用户 2026-09-30 20:37 明确只做两件事：修复现有存档失败、替换已生成并认可的白天背景；授权直接推送并构建测试 APK。上一轮其余方案暂缓，详见正文“2026-09-30 美术与存档完整性后续方案”。
- 截图证据：普通备份在 `SELECT * FROM settings` 报 `Row too big to fit into CursorWindow requiredPos=294 totalRows=295`。确定是 settings 的单条大值读取故障，尚无本机数据库证据可确定具体设置键；不凭行号猜键，不清空、截断或删除用户记录。
- 基线 +298 源码869a117e/总账2ebe1d6；独立分支 `agent/v04255-backup-cursor-window-day`。计划在既有导出事务中按字节分段读取大 settings，重组后仍导出原 key/value；常规 getSetting 同用有界读取，长值保持事务一致性。兼容现有 schema61/protocol6；不扩大本轮到 Live2D 全量备份补齐。
- 背景：仅把本窗口日光预览转换为 WebP 并替换公共 `assets/lingchat/background/day.webp`，沿用 Flutter/原生同路径、cover/IME/EGL 恢复机制；夜图、人物、配件、模型路由、游戏与界面其余项保持原实现。
- 验证：多 MiB 中文/emoji/NUL 字节重组、受限 CursorWindow 查询、完整数据库 JSON 导出/导入、Android 真 SQLite 游标烟测；完整源码门、Flutter analyze/tests、原生烟测、Kotlin、arm64 签名 APK。CI 与真机分别回填，不提前标成功。
- 实施：新增 SqliteSettingsReader，首段和后续每次查询最多64KiB BLOB；完整拼接后一次UTF-8解码，支持中文/emoji跨段与NUL，空值保留。导出在原全库事务内读取；单项小设置一次查询，大设置重新在事务内读。短段/字节不一致报错，不返回部分成功；无数据迁移/删除，无协议变更。实际背景1672×941 RGB，原预览无损WebP转换，1,606,718bytes，SHA-256 `6b4296044fd5b882f459e3f66cb586f67d59949a3a49a786a343619149781fb7`。本地真实SQLite 3.85MiB中文/emoji/NUL无损往返通过，新增4项Flutter回归和1项Android游标烟测（已由最终CI补齐，见下文）；本机无Flutter SDK。局部快检中6项历史版号白名单已补+299；120项本地源码门通过，13项因未恢复私有资源/稀疏未取出Android测试或缺Kotlin工具链留给完整CI补齐。

- 首轮CI [36724790798](https://github.com/catkiss62/ai-companion-build/actions/runs/36724790798)，源码3a7d2007/tree c9d615a6：Android15原生6项烟测通过，含512KiB CursorWindow读取3MiB以上settings完整字节；前132项源码门通过。第133项发现CI恢复LingChat原素材覆盖已提交的新day.webp，哈希门正确阻止错误APK，未进入Flutter。修复素材恢复函数：仅day按已批准SHA-256保留，缺失/损坏则失败，其余61项仍按上游LFS校验；增加实际恢复函数的正常/损坏/缺失回归及APK内day哈希核验，保留原严格门。后续完整CI结果见下文。

- 第二轮36728003121，源码144776f3/tree d96cef6f：原生6项再次通过，build-apk在已通过资源/基线检查后，14:23:32Z进入既有桌宠素材生成步骤，至14:43Z超过20分钟未完成，尚未进入后续源码门/Flutter；上一轮相同步骤约5分钟。仅为构建恢复补该步骤15分钟超时、下载连接/总时长及停流超时，源码与素材完整性校验不变；同分支推送替代旧运行以取得取消日志并重跑，产品仍仅两项。未把未完成流水线记为通过。

- 最终源码a2341425dfd6192551e3a5470eed89b5038165f4，tree dbd8558ecbc53f1a720bec82358ccb7f5c3bc63c与本地一致；[Actions 36731605271](https://github.com/catkiss62/ai-companion-build/actions/runs/36731605271) conclusion=success。Android15原生6/6（报告Artifact11105103500，CursorWindow新用例实际执行且0失败）、133项源码门、Kotlin、Flutter analyze及1018项Flutter测试通过，包含4项新设置/导出/导入/损坏分段回归；arm64 Release、稳定签名及资源检查通过，APK内day哈希与批准预览完全一致。analyze沿用仓库非致命info/warning策略，未宣称零提示。第二轮被新版替代取消，取消日志无动画生成进度，无法确定下载/apt/转换哪个子步骤停留；最终这一步约6分钟完成，不归因为产品代码失败。
- [未发布+299测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-96970c13c85e77efbdd1)，Draft400107673，target a2341425，asset601202681，AI-Companion-v0.42.55-299-Backup-CursorWindow-Day-APK.apk，727738166bytes，SHA-256 8f848e1ceeaf992a3f54fb2bd1a5721d2316a478515906cf8be4f19302c242d3；APK Artifact11107390635。ci-monitor-v0345/.ci/v04255-monitor.txt的run/head/digest与Release一致，签名30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48与+298相同，可覆盖安装保留数据。真机仍待：先保存备份确认不再报settings CursorWindow错误，再看白天背景；未用本机数据库定位具体大键，未声称Live2D原生模型/舞台偏好等后续全量备份审计已完成。其余六项后续方案继续暂缓。

## +300实施记录 · 游戏间隔、持续摸头与完整存档（2026-10-01；CI PASSED / APK READY / TRUE DEVICE PENDING）

- 功能清单含用户中途追加的持续摸头，彩蛋时长已按02:04最新决定恢复原2.8秒，原任务未丢。普通单人推进统一至少120秒，10/5/1轮按实际成功状态变更累积，选择持久化、默认5轮；实际消息提交后才重置过程分享间隔，多轮真实结果合并生成，既有规划判断复用。终止/指定时长回报单独必达；报告提交后清理此前的过程队列，保留后续恢复游戏的新事件。过期Thought不能永久阻塞新分享。
- 自制小腿支点rootTilt从当前显示值限速，默认25°/秒，对比待机上界约19.6°/秒；跟随同一gain/speed设置，最高60°/秒对比待机约47.1°/秒。只限draw transform，不改模型BodyXYZ。有效摸头达到原手势门后持续到UP/CANCEL，头部移动出判定框不能提前释放；彩蛋原2.8秒且重复触发不重置/覆盖。原概率10%、原生表情和顺滑恢复保留。
- 记住事项快捷入口在左栏代办提醒上方，复用原页面/数据库。旧桌宠素材清理暂缓，七大规则删除放弃。
- 新状态包协议7包含相对路径Live2D模型/配件、原生舞台/悬浮显示位置偏好、完整表情包文件、SecureConfig九项非密钥配置；API Key、Cedar Token、密码不导出且目标凭据不覆盖。绝对模型索引从验证后的包重建；旧1～6包不覆盖新原生/secure配置。文件/偏好/secure配置激活后若DB导入失败，回滚原本状态。原有Brain/代次/ACK/lease/旧游玩授权失效规则继续保留。
- 逐项核查CREATE TABLE与exportAll：六个既有例外仅为迁移临时、运行审计/维护记录、设备转移回执（maintenance_runs/memory_retrieval_audit/messages_v20/proactive_policy_events/provider_health_events/transfer_receipts）；settings含记住事项、日历、Jev开关和其余可迁移用户状态。身份/权限/任务租约不跨机恢复。本轮不改变 schema61。
- 新增有意义行为测试：5/10/1轮及失败/只读排除、队列幂等/积压聚合/过期恢复/报告清理；v7本机与新安装往返、原生部分失败及DB失败回滚、文件损坏/缺失/穿越拒绝、v6兼容、空模型域、凭据排除；原生实际headpat/rootTilt行为及模型租约/索引恢复。运行结果待CI，不把仅添加测试宣称为通过。
- 本地Dart语法、YAML解析、diff检查、专项门/总账门通过；有序全套因缺Cubism AAR在第2项停止。依同一有序清单逐项诊断129/134通过，其余5项为未恢复私有AAR/立绘/桌宠/LingChat特效或未安装kotlinc。完整资源与Flutter/Kotlin/Android测试交给既有Actions，尚未构建成功。

### +300第二轮CI回归与模型存档边界补正

- 本地ce809c1/tree92090584对应远端99ee9512；补齐get_result/wait/poll不计轮数、实际Release说明后，本地b16b9ae/treebcdc3051对应远端a07f3d4。首轮36750751460被新版替代取消。
- [36751155364](https://github.com/catkiss62/ai-companion-build/actions/runs/36751155364) Android15原生9/9成功：CaicaiInteractionCadenceSmokeTest两项、真实模型租约/索引恢复、CursorWindow与既有生命周期/背景均实际执行且0失败；Artifact11113874815的XML已核实。134项源码门通过。Android完整单元测试在CaicaiInteractionTest.rarePatCompletesEvenWhenFingerRemainsDown失败：旧用例180帧（3秒）断言结束，与本次4.5秒冲突；不是新增4.5秒行为失败。更新旧用例同时断言3秒仍活动、普通摸头无法覆盖、接近4.5秒仍活动及随后结束。未把此流水线记为成功。
- 审计模型导入事务时补两条边界：尚未渲染确认的pending模型事务不与存档同时进行；导出验证当前已安装模型完整性，恢复验证incoming模型而允许替换原本损坏的目标模型，避免“需要恢复却因本机旧模型损坏而无法进入恢复”。失败仍保留旧树及索引用于回滚；增加实际原生用例覆盖pending租约拒绝和损坏目标路径。未复制渲染器，不提交模型权重，不改变BodyXYZ。

### +300最终彩蛋时长决定与一致构建

- 用户2026-10-01 01:59决定采用原摸头彩蛋时长，02:04再次强调代码与APK必须一致。直接核对+299原CaicaiHeadPat淡出公式（age-2.2）/0.6，原总时长是2.8秒；前次口头2.3秒已纠正。最终只把自制摸头彩蛋时长恢复2.8秒，按住到UP/CANCEL、彩蛋内不覆盖/重置保留，其它情绪/原装临时表情4.5秒不变。同步源码门、Java及Android实际行为用例、Release说明，重新完整CI，禁止把旧4.5秒APK作为本轮最终交付。第三轮36754213000由新推送替代，结果继续如实保留。
- 补正结果回报时间精度：Thought行保存毫秒、游戏事件保存微秒；回报清理覆盖完整的已记录毫秒，避免同毫秒已报告的最后一步再次分享。既有回归明确覆盖带微秒的旧结果，同时保留下一秒恢复游戏的新事件。

### +300最终构建、APK与真机边界（2026-10-01 02:37）

- 最终功能源码620e08852283d6a5389d307e161d02166443785d，tree85471e6f48418947e81b3ca225d0b801c4fdfe94；本地fe10a850773bab10d4253156cf0a824eca7df1d3同tree。第三轮36754213000因用户最终彩蛋时长决定被新推送替代取消；第四轮[36756872531](https://github.com/catkiss62/ai-companion-build/actions/runs/36756872531)已完成且conclusion=success。最终彩蛋原总时长2.8秒，2.2秒开始0.6秒淡出；按住持续/松开恢复及彩蛋期间不覆盖/不续期保留，其它4.5秒情绪/临时表情不变。
- 134/134源码validator通过；Kotlin/Android单元测试BUILD SUCCESSFUL（4m40s）；Flutter analyze沿用仓库非致命info/warning策略通过，Flutter实际1033项通过（原1018项+本轮7项分享与8项存档回归）。普通单人至少120秒、10/5/1等宽/默认5/只计真实成功推进、积压合并/实际消息提交后计间隔、报告清理带微秒结果/保留后续恢复事件均有回归；旧45分钟仅保留历史经历分享原政策，实时过程分享使用轮数门。到轮数仍须值得分享，终止/指定时长结果回报单独必达。
- Android15原生9/9、0失败/0跳过，实际报告Artifact11116749248（XML已下载核实）；CaicaiInteractionCadenceSmokeTest两项覆盖持续摸头/松手、2.8秒彩蛋防抢占/防重新计时、25°/秒rootTilt反向/暂停/待机接管；另含模型租约/索引重建、pending导入互斥、损坏旧模型可恢复、CursorWindow大值、既有生命周期/背景用例。该报告不是私有模型真机绘制观感证据。
- arm64 Release APK通过稳定签名、Genie/完整桌宠/tarot/shader资源核验；APK内白天day.webp与批准SHA-256 6b4296044fd5b882f459e3f66cb586f67d59949a3a49a786a343619149781fb7完全一致，未重新生成或回退背景，+299大settings无损读取保留。
- [未发布+300测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-509ccfd78b2217c9fdc2)，Draft400290010，target620e08852283d6a5389d307e161d02166443785d，asset601559245，AI-Companion-v0.42.56-300-Game-Share-Portable-State-APK.apk，727767998bytes，SHA-256 c6049f59ccaec150d26d71bcdaf1ff5b28272a025aee1f8658832a7ec851fcbf。APK workflow Artifact11116914259；其ZIP digest876a81c8fcdcb9e890037df6bd88fd743f872792a69a0c71bc2e0aa484f41a3d是压缩归档哈希，不混作APK文件哈希。sha256附件asset601559246、CI Monitor附件asset601559250。
- ci-monitor-v0345/.ci/v04256-monitor.txt为status=success、run36756872531、head620e0885；Release target与monitor一致，GitHub上传资产digest与monitor APK hash一致。稳定签名30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48与+299相同，可覆盖安装保留现有数据；不合并main、不正式发布、不提交私有模型、旧桌宠图片清理暂缓、七大规则删除放弃。
- 真机待验收：按住摸头后头部移动不提前恢复，松手恢复；彩蛋2.8秒内继续摸不会覆盖/续期；自制小腿支点左右旋转不再瞬跳且身体XYZ不变；左栏记住事项直达原页面；默认5轮在值得分享时概括多轮结果，1轮/10轮是最少间隔而非强制播报，直接指定时长与半小时竞争共用该门；本机及另一设备实际存档还原Live2D/记住事项/表情包/非密钥配置，目标API Key仍留本地。本轮自动化已完成，TRUE DEVICE PENDING。

## v0.42.57+301 · 记忆星谷实施记录（2026-10-01）

用户批准纯视觉查看功能，外观沿用所附galaxy-template.html / 记忆银河搭建教程。不存在“星谷维护记忆”或模型重写；RememberedUserFacts仍走原入口，不参与星谷。全部active记忆由MemoryBrowseRepository同一数据库事务按created_at/id分页读取，投影只映射标题、类别、重要度、钉选、记录日期和原文；保留不确定推断标签。文本作为私有JSON文件而非拼进HTML，以textContent显示，HTML/emoji/NUL均不作为脚本执行；日期按本地年月日显示，UTC用于排序。

NativeMemoryGalaxyActivity以本地HTTPS虚拟域名拦截JS/字体/JSON，不走外网；无JS写入桥接，CSP约束本地资源，关闭file/content访问。Intent只传经规范路径校验的cache/memory_galaxy快照路径，避免Binder大JSON；返回、异常和释放清理临时快照。独立Activity退出销毁WebView，暂停取消动画帧，恢复续播；保留既有Flutter舞台生命周期。模板所有有效记忆展示；空数据正确显示空提示，加载失败展示失败信息而无演示故事。连线为模板原按类别的视觉聚合，并不等同精确话题关系。

MemoryPage保留原编辑/保存/归档，并新增折叠同话题条目和只读详情切换；查询只匹配非空现存topicKey+active，不使用主体或类别作假关联，不触发相关记忆检索计数。新增记忆星谷AppBar入口。“她”页原去找她按钮替换为MemoryGalaxyButton，局部CustomPainter渐变星空+流星；TickerMode与应用生命周期及减少动画选项共同暂停，控制器dispose。

桌宠PetEdgeDockPolicy在同一旧吸附阈值下优先上/下角落，其余维持最近边缘；纯策略JUnit覆盖非等距四角、等距、普通边缘、范围边界和窄屏重叠。未改抛掷/重力/半屏/沿边行走等机制，未触碰Jev兜底、Live2D身体XYZ或原2.8秒彩蛋时长。构建身份0.42.57+301，各历史源码门的版本白名单只新增本版；快照协议与schema未变。

当前状态：IMPLEMENTATION IN PROGRESS / CI PENDING / APK PENDING / TRUE DEVICE PENDING。后续仅在实际Actions及release资产验证完成后回填提交、run、SHA和APK链接。冻结归档保持原SHA。
