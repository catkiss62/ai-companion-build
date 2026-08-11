# Android 生命周期专项审计 · v0.12

本轮目标不是扩功能，而是检查“完整 App / 悬浮球 / 后台 FlutterEngine / 系统感知服务 / Nearby”在 Android 生命周期变化下是否会互相踩状态。

## 1. 常驻陪伴服务

`OverlayBubbleService` 现在区分两种状态：

- `overlay_user_enabled`：用户是否明确开启常驻陪伴；持久保存在 Android SharedPreferences。
- `OverlayBubbleService.running`：当前进程里服务是否真的活着；只用于诊断。

恢复策略：

- 用户在可见 Activity 内开启后启动前台服务。
- 系统杀进程后，如果 Android 对 START_STICKY 进行重建，服务会重新检查“用户是否开启 + 悬浮权限是否仍存在”。
- BOOT_COMPLETED / MY_PACKAGE_REPLACED 时，仅当用户此前明确开启且悬浮权限仍有效时才尝试恢复。
- 用户主动关闭、设备被另一台设备接管时，会把 user-enabled 状态关掉，因此重启不会把旧 Active Brain 的悬浮服务复活。
- force-stop 不尝试绕过。用户明确强制停止应用应保持停止。

启动失败不会崩溃进程，会记录 `companion_service_start_failed` 诊断事件。

## 2. 悬浮权限撤销

悬浮服务每 30 秒复查 `Settings.canDrawOverlays()`：

- 权限被撤销后停止悬浮服务；
- 保留“用户原本希望开启”的偏好；
- 用户之后重新授权并回到可见 Activity 时，由 `reconcileFromVisibleActivity()` 再恢复；
- `BubbleContainer.onWindowVisibilityChanged()` 记录悬浮层是否真正可见，便于诊断系统/安全 App 临时隐藏 overlay 的情况。

## 3. 屏幕、锁屏与显示变化

常驻服务运行时动态监听：

- SCREEN_ON
- SCREEN_OFF
- USER_PRESENT
- POWER_CONNECTED
- POWER_DISCONNECTED

只写入本地 `device_events`，由现有 Perception Engine 再决定是否值得转成陪伴上下文。屏幕旋转/显示尺寸变化时，悬浮球位置会重新夹回当前屏幕边界；拖动后的吸边位置也写入设备本地 SharedPreferences，因此 service/process 重建不会无故跳回默认位置。

这些系统事件不会直接变成 Prompt 指令。

## 4. 通知监听与 Accessibility

NotificationListener：

- `onListenerConnected()` 标记真实连接状态；
- `onListenerDisconnected()` 立即标记断线并请求系统 rebind；
- “系统设置里已授权”和“服务此刻真的连上”在诊断页分开显示。

Accessibility：

- `onServiceConnected()` 标记真实连接；
- `onInterrupt()` 记录系统中断；
- `onDestroy()` 清除连接状态；
- 不尝试由应用自己强行 bind AccessibilityService，生命周期继续交给 Android 系统。

## 5. Native callback 与跨设备冻结

Android 的通知/Accessibility/屏幕回调不属于 Dart lease 系统。

v0.12 增加两条硬保护：当 SQLite 中 `transfer_lock=1`，或本机已经 `active_brain=0` 时，`NativeEventStore.addDeviceEvent()` 不写入新感知事件。

因此：

1. 手机生成冻结快照时，不会被一条晚到的 SCREEN_OFF/notification 回调打破快照边界；
2. 平板替换数据库期间，也不会有 native callback 在旧数据库/新数据库之间插入一条不可追踪写入；
3. 旧设备被顶下线后，即使 NotificationListener / Accessibility 仍由系统保持授权，也不会继续积累“她的感知”；
4. 新 Active Brain 完成接管并解除 transfer lock 后，系统感知恢复正常。

## 6. 多 FlutterEngine 的 Nearby 事件

旧实现的 Nearby transport 只有一个 EventChannel sink。

完整 App 创建第二个 FlutterEngine，或者悬浮聊天 Activity 创建/销毁时，可能覆盖/清掉另一个 engine 的 Nearby sink。

v0.12 改为 process-wide `NearbyTransferManager` + 多 listener：

- 每个 `SystemBridge` 拥有唯一 owner id；
- onListen 注册自己的 listener；
- dispose/onCancel 只移除自己的 listener；
- full app 与 floating-chat engine 不再互相抢单例 sink。

同时修复了 v0.11 `NearbyTransferManager` 中一个重复 `Payload.Type.BYTES` 分支。该问题属于 Kotlin 编译级错误，是本轮中途审计实际发现的问题。

## 7. 后台 FlutterEngine

常驻服务持有一个无 UI FlutterEngine，入口为 `companionBackgroundMain`。

v0.12 补充：

- service/Activity destroy 时显式 dispose SystemBridge / TTS Bridge，再 destroy/detach FlutterEngine；
- NativeTtsBridge 现在保存 MethodChannel 引用，dispose 时先移除 handler；已经进入 native 推理的任务允许安全结束，但不会在旧 FlutterEngine 销毁后回调一个失效 result；
- NativeTtsEngine 的显式 initialize / speed 配置 / release 与 generateTTS 统一进入同一 process-wide ReentrantLock，避免三个 FlutterEngine 中一个正在 MNN 推理、另一个同时重配 native runtime；
- Android low-memory 回调会同时通知 Flutter framework 与 Dart VM；
- full app / floating Activity 生命周期不负责销毁后台 engine；
- `companionBackgroundMain` 不再把 `db.ensureReady()` 放在保护循环之外；错误诊断本身也 best-effort，设备转移造成的瞬时 SQLite lock/import 不会因为“记录错误再次失败”而终止整个后台 isolate；
- 本轮进一步发现：后台 isolate 即使业务 engine 自己会 return，循环末尾的 `last_background_error` 清理仍然属于写操作。现在循环和诊断写入都先读取 `brainWorkAllowed()`，standby/transfer-lock 状态下整个后台 isolate 只等待，不写任何诊断或 inner state；
- PerceptionEngine 的手动 capture 和 MemoryExtractor 的异步错误诊断同样补上 Active Brain/transfer guard，避免调试按钮或晚到 Future 成为冻结边界之外的 writer。

## 8. 通知被关闭

主动消息本身先写 SQLite，通知只是展示层。

Android 系统通知关闭时：

- 不丢 AI 消息；
- 不把通知失败当成主动消息生成失败；
- 写一条本地 `companion_notification_suppressed` 诊断。

因此重新打开 App/悬浮聊天后，历史消息仍存在。

## 9. Manifest / Nearby 权限审计

v0.12 重新核对 Nearby 权限边界，并修复了一个实际的 Android 12L/API 32 缺口：旧 Manifest 只把 `ACCESS_FINE_LOCATION` 留到 API 31，但 `NEARBY_WIFI_DEVICES` 实际从 API 33 才存在，因此 API 32 会落在两套权限之间。现在 fine-location / Wi-Fi compatibility 权限保留到 API 32，API 33+ 再切到 Nearby Wi-Fi。

Manifest 对新权限采用通用 permission name 声明，真正的运行时请求仍根据 Android 版本分别门控：

- 旧版 location / storage；
- Android 12+ Bluetooth advertise/connect/scan；
- Android 13+ nearby Wi-Fi；
- 新平台需要的 local-network permission 使用 permission 字符串进行版本门控。

READ_EXTERNAL_STORAGE 只在它仍可能生效的旧 Android 请求；当前 Nearby 状态包实际放在 app-private/cache 路径，不依赖公共媒体库读取。


## 9.1 Nearby 传输大小与恢复 UI

本轮又补了两个生命周期/恢复细节：

- Nearby FILE payload 在 transport callback 层检查 `totalBytes`，超过 512 MiB 会调用 `cancelPayload()` 并直接失败，不会先复制到 Companion cache 再等 ZIP 导入器拒绝；
- 接收设备导入后始终先保持 `active_brain=0`。如果 Activity 在 ACK 等待/断线后被 Android 重建，`TransferPage` 会从 SQLite 的 durable `active_brain` 恢复“本机待机 / 手动接管”按钮，而不是依赖已丢失的内存布尔值。

Snapshot import 本身不是删除/替换 SQLite 文件，而是在同一个现有数据库 connection family 中执行整组 table delete/insert transaction，再原子写入本机 `device_id`、standby、transfer lock 和 lease override。因此后台 FlutterEngine 持有的另一 SQLite connection 不会指向一个被换掉的旧 inode；真正要防的是 import transaction 前后的并发 writer，这部分由 transfer lock、lease wait、native callback guard 和 background `brainWorkAllowed()` 共同处理。

## 10. 当前已确认的架构缺口：聊天窗还不是真正的 WindowManager overlay

这是本轮最重要的审计发现之一。

当前：

- 圆形悬浮按钮是真正的 `TYPE_APPLICATION_OVERLAY`；
- 点击按钮以后启动的是透明 `OverlayChatActivity`。

所以它视觉上像悬浮聊天，但从 Android 生命周期角度仍然是一张 Activity。它可能让正在玩的游戏/QQ 失去前台焦点或进入 paused 状态。

这与最初产品目标“在其他 App 上面直接展开窗口，不切走当前 App”仍有差距。

暂时不在 v0.12 里强行改成 WindowManager-hosted FlutterView，原因是这种实现需要手动处理：

- FlutterView attach/detach；
- Flutter lifecycle channel；
- 输入法/焦点；
- Surface/Texture 渲染；
- WindowManager touch flags；
- 展开/收起时底层 App 是否继续响应；
- 多厂商 Android 的 IME/overlay 行为。

这些属于必须最终真机确认的交互链。v0.13 将把“真正的 overlay chat host”作为独立任务实现，而不是继续把透明 Activity 当作最终方案。

本轮还确认了这个临时 Activity 方案的第二个生命周期缺口：`MainActivity` / `OverlayChatActivity` 当前都使用 Activity 自己创建的 FlutterEngine。若 Activity 在一轮 DeepSeek 流式生成尚未结束时被 Android 真正 destroy，该 Dart isolate/engine 会随 host 销毁，本轮生成可能中断，而用户消息已经先写入 SQLite。普通 onStop/切后台不等于 destroy，因此这不是每次切 App 都会发生，但它是必须在最终架构中消除的边界。v0.13 的 service-owned 真悬浮 FlutterEngine 会先解决悬浮聊天这一侧；完整 App 的“跨 Activity destroy 仍可持续生成”将继续作为 durable chat-job hardening 任务。

另外修复了当前透明悬浮 Activity 的一个具体 UI 生命周期 bug：它是根 route，原来的 `Navigator.maybePop()` 可能没有可 pop 的 route，导致右上角关闭按钮无反应。v0.12 在没有 overlay-host callback 时改用 Android `SystemNavigator.pop()` 结束当前 Activity；v0.13 真 overlay 后将改为原地收起 WindowManager 窗口，不再 finish Activity。

Flutter UI 自身也补了一层 dispose 防护：`ChatController` 的异步路径统一通过 `_safeNotify()`，避免页面已经 dispose 后晚到 Future 再调用 `notifyListeners()`；`ChatPage` 初始化完成和 post-frame 自动滚动都会先检查 `mounted`。这不能解决 Activity-owned engine 被真正 destroy 时“生成任务本身被终止”的架构缺口，但可以消除同一 engine 内页面销毁/导航造成的一类 late-callback 异常。

## 10.1 长期跨设备快照的已知容量边界

当前状态包把本地表导出为一个结构化 JSON，再放入加密 ZIP/Nearby FILE payload。v0.12 已加入 transport 层 512 MiB 上限和 ZIP 解包上限，但“读取整个 state.json 到内存再解析”仍是长期运行后的潜在内存峰值。它不会影响当前小型数据库，但如果未来多年原始聊天累积到数百 MiB，应该升级为分表流式导出/导入或 SQLite backup/streaming snapshot，而不是继续提高整个 JSON 的上限。这个优化暂不改变 v0.12 数据格式。

## 11. 本轮未声称已经验证的事情

当前环境没有 Flutter SDK / Android SDK，因此本轮没有声称：

- `flutter analyze` 已通过；
- Gradle APK build 已通过；
- OEM 后台保活已通过；
- 真机权限撤销/重启/锁屏时序已通过；
- 真正 TTS 发声已通过；
- Nearby 双真机接管已通过。

这些保留到需要真实 Android 环境的里程碑。
