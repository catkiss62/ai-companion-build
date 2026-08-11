# True Overlay Chat Audit · v0.13

## 目标

v0.12 的小悬浮球已经是 `TYPE_APPLICATION_OVERLAY`，但展开聊天依赖透明 Activity。v0.13 的目标是让“查看/回复她”本身也发生在真正的 WindowManager overlay 中，同时保持现有 Dart Companion Core 不分叉。

## 架构选择

没有把 `FlutterView` 直接放进 Service WindowManager。v0.13 采用：

`WindowManager native chat panel -> MethodChannel -> service-owned headless FlutterEngine -> ChatController`

原因：这能让 Android overlay/window/focus/IME 留在原生层，同时完整复用 Dart 的聊天、Memory、Desire、Thought、Proactive 与 TTS 逻辑，并避免为了浮窗维护第二套 AI 业务实现。

## Window 模式

### Read mode

- `TYPE_APPLICATION_OVERLAY`
- `FLAG_NOT_FOCUSABLE`
- `FLAG_NOT_TOUCH_MODAL`
- `FLAG_WATCH_OUTSIDE_TOUCH`
- `FLAG_LAYOUT_NO_LIMITS`

目的：浮窗自己可点击，底层应用继续持有主要焦点，窗口之外的触摸不被整块浮窗吞掉。

### Input mode

用户点击 EditText 后临时去掉 `FLAG_NOT_FOCUSABLE`，请求输入焦点和 IME。Back 或窗口外触摸后恢复 read mode。

因此设计目标不是“打字时底层游戏仍保持键盘焦点”，而是“阅读/等待时不抢焦点；只有真正输入时临时取得键盘焦点”。

## Chat runtime

服务创建的 persistent headless FlutterEngine 注册 `BackgroundChatCommandServer`。

Native overlay 支持：

- 最近消息读取
- 向上分页加载
- 发送
- reasoning 查看
- TTS replay/stop
- overlay-open hook

发送时仍调用同一 `ChatController.sendText()`，所以六层规则、本地记忆、关系、Thought、Desire、Active Brain lease、DeepSeek reasoning/content、post-turn memory job 都走原有主链路。

## 生命周期

- Collapse：只隐藏/缩小 WindowManager UI，不销毁 background engine。
- Screen off：收起 expanded panel。
- Locked show request：记录 pending，解锁后展开。
- Full App resumed：收起 expanded overlay，避免双 UI 竞争输入焦点。
- Service destroy：清 overlay windows、platform bridges、background FlutterEngine。

## 跨 Engine UI 一致性

完整 App 和 background service 是不同 FlutterEngine。SQLite 已经是持久真源，因此 full ChatPage 在 resumed 状态下低频同步外部写入，且本地正在发送时不刷新覆盖当前 streaming UI。

## 本轮代码审计发现

- 修复 `AppDatabase.insertMemory()` 的重复局部变量声明。
- 清除 v0.12 的 `/overlay-chat` route / `overlayMode` / overlay Flutter page 死代码。
- 删除旧 OverlayChatActivity Manifest/源码。
- 通知改为直接发给 OverlayBubbleService。
- 增加 background unread set/clear bridge 和 expanded-state runtime diagnostics。

## 剩余风险

1. OEM/游戏/输入法组合的焦点行为无法只靠静态代码证明，需要真机。
2. 整个 service 进程被系统真正杀死时，正在生成的 turn 仍会中断。v0.14 将引入 durable chat job。
3. Native overlay 当前不做 token-by-token reasoning streaming，只展示已经持久化的 reasoning。
