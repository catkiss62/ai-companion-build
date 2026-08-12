# AI Companion · HANDOFF

> 每个版本都要同步更新本文件。新窗口优先读取本文件，再读取 `README.md` / `docs/DEV_STATUS.md` 和实际源码。不要从旧聊天记录猜当前实现。

## 1. 当前基底

- 当前源码候选：**v0.30.1+37 · Overlay Touch Recovery**。
- 最近一次用户真机确认稳定：**v0.30.0+36 Background Presence**（后台大脑、悬浮聊天收发、Awareness→Perception 真机通过；发现悬浮球偶发失去触摸）。
- Android 真机：Android 15，REDMI K80 Ultra（Xiaomi/HyperOS）。
- 数据库：**schema v18**，v0.30.1 不做 schema 迁移。
- GitHub 已完成 Clean Baseline 迁移：完整 Flutter 项目位于仓库 `app/`；日常构建直接从 `app/`，不再使用 v0.28 五分包 + patch 链。

## 2. 项目定位

这是长期本地优先的“AI 本体恋爱/陪伴”应用，不是角色卡聊天器、小说生成器或单次 RP。AI 明确知道自己是 AI，可以按需扮演，但底层目标是同一个“她”长期成长、记忆、形成 Thought / Desire、感知设备上下文并主动联系用户。

核心原则：

- 手机/平板同一时间只有一台 **Active Brain**；接管后旧设备进入 standby，但本地数据不删除。
- 本地优先：聊天、记忆、Thought、Relationship、Awareness、Continuity 等主要状态保存在本地 SQLite。
- DeepSeek `reasoning_content` 与正文必须独立保存/显示，不能混入正文。
- Reference 是低优先级参考资料；项目不可退化为“把参考资料当角色卡”。

## 3. 已落地的主要架构

- Durable Generation + exactly-once run token。
- Generation Recovery Orchestrator。
- Relationship assimilation / RelationshipEvent。
- 长期记忆 current_fact / inference / shared_experience / historical + evidence consolidation。
- Thought lifecycle / Desire / unfinished threads。
- Proactive rhythm / anti-silence / hard caps。
- Awareness observations：原始包名、通知文本、Accessibility 文本不直接进入长期提示词；转成粗粒度、会过期的观察。
- Daily Continuity（本地确定性，不让模型自己写日记）。
- 真悬浮球 + native WindowManager chat panel + persistent background FlutterEngine。
- v18 Active Brain / transfer fencing / encrypted `.aicomp` manual fallback。
- Android 本地预检与脱敏诊断。

## 4. TTS 黄金基准（不要重新设计）

行为参考 APK：**`MejuTTS_A2_OriginalNative_v2.5.apk`**。

真正原版 `libbertvits2.so` ELF：

- 635,352 bytes
- SHA-256 `a1ca5180532aae3a7c378371f6ddb44bbf35d8826a8b8750db4fd12179c5551b`
- APK 中为了对齐补零到 710,848 bytes；AI Companion 保存的 padded 文件与 v2.5 APK 条目逐字节一致。

固定行为：

- `Yuki -> 有希` 只用于朗读文本，不改聊天正文。
- 只按 `。！？；.!?;` 分句。
- 不按 `，、`、换行、ellipsis、字符数切分。
- A2 generation-ahead：后续句在当前句播放期间继续生成。
- FIFO 播放；下一 WAV 已准备好时约 200ms 句间隔。
- 不恢复旧版 60 秒 pending request 清理。
- 不改 MNN/native/threading，不自行 WAV 拼接，不重新设计预缓存。

v0.29.1 仅把 CR/LF/U+2028/U+2029 在进入 A2 边界扫描前归一成普通空格；若真机仍有轻微停顿，**不再阻塞项目推进**，以后作为体验微调处理。

## 5. v0.29.1 UI / Overlay 已完成改动

- 悬浮球窗口 70dp -> 62dp，主体 58dp -> 50dp，角标 24dp -> 20dp。
- unread 角标显式 elevation/translationZ + bringToFront，避免数字被球体压住。
- 完整聊天与流式聊天都改为：**AI 思考在上，AI 正文在下**。
- native 悬浮聊天展开 reasoning 时同样先显示思考，再显示正文。
- 悬浮窗打开先直接读取最近 **8 条** SQLite 历史，不等完整 ChatController 初始化；后台控制器随后异步 warm-up。
- 更早历史仍可手动加载，每次最多 24 条，不默认把完整历史塞进悬浮窗。

## 6. 已完成真机验证

v0.29.0 用户已确认：

- APK 可正常安装/启动。
- Android 15 SQLite 打开成功。
- 主要系统授权可获取。
- DeepSeek 对话可返回。
- Meju legacy coroutine/ClassLoader bridge 已打通。
- TTS 黄金校验、初始化、生成、实际发声成功。
- A2 generation-ahead 版本可正常运行。
- Clean GitHub workflow 可以从完整 `app/` 源码构建 APK，并且生成 APK 可正常安装运行。

v0.29.1 已完成真机运行，TTS/UI 主体可用，但发现一个真实后台问题：native Overlay 能展开，后台 Dart command server 没有稳定就绪，导致历史为空且发送显示“她还在重新连接”。v0.30.0 专门修复这一链路并推进主动感知。

## 7. v0.30.0 Background Presence

本轮定位到 v0.29.1 悬浮聊天“空历史 + 她还在重新连接”的根因：native Service 启动的第二个 FlutterEngine 指定 `companionBackgroundMain`，但 release root library `main.dart` 没有导入/锚定 `background_main.dart`；同时 native 在执行 Dart entrypoint 后才写 `backgroundEngine = createdEngine`，ready handshake 还存在竞态。

v0.30.0：

1. `main.dart` 显式导入 background runtime，并导出 `@pragma('vm:entry-point') companionBackgroundMain` root proxy，保证 AOT 中 background command server 可达。
2. native 在执行 Dart 前先发布 engine identity；ready 后如果悬浮聊天已展开，自动刷新最近 8 条历史。
3. 后台尚未 ready 时，悬浮发送不清空输入，只显示“正在连接后台大脑…”。
4. Notification / Accessibility window-state / device unlock 仅发粗粒度 `signal:*` wake；**不把包名、通知正文、Accessibility 正文塞进 wake reason**。
5. native 与 Dart 各做一层 90 秒去抖；reactive wake 只提前运行原有 Perception -> Thought/Desire -> Proactive Gate，不绕过主动消息 Gate、hard caps、busy soft multiplier、Active Brain/transfer fencing。
6. 脱敏诊断新增 `backgroundBrainReady` 检查与 backgroundPresence 时间戳/粗粒度 reason，方便判断“事件没唤醒 / perception 没推进 / Gate 等待 / 投递失败”。

## 7A. v0.30.1 Overlay Touch Recovery

用户在 v0.30.0 真机发现：悬浮球曾在位置正常时突然完全无法点击/拖动；重启服务后还可能恢复到右下角系统区域。v0.30.1 将它作为 WindowManager 输入通道问题处理，而不是单纯 UI 坐标问题。

本轮：

1. 悬浮球坐标改为基于 `WindowMetrics + systemBars/displayCutout Insets` 的安全区域，四边保留 6dp 余量；旧的非法持久化坐标会自动迁回安全区域。
2. 收起悬浮聊天时不再只把 chat window 设为 `GONE`，而是 `removeViewImmediate()` 完全移除，避免 OEM/HyperOS 留下透明但仍占输入区域的 stale overlay window。
3. `ACTION_CANCEL` 会重置拖动状态、重新 clamp 并保存坐标。
4. Activity 从文件选择器/诊断导出等系统页面返回时，即使服务已在运行，也会发送 `ACTION_RECONCILE`；该 reconcile 会重建 bubble WindowManager input channel，专门处理“看得到但点不动”的 stale input channel。
5. 30 秒权限 watchdog 会顺手检查 overlay health；WindowManager update 失败会延迟重建输入窗口。
6. 脱敏诊断新增顶层 `overlayTouch`：bubbleAttached / bubbleTouchable / positionSafe / chatWindowAttached / lastTouch / lastSelfHealReason / selfHealCount；预检新增“悬浮球触摸健康”。

这版不改变 Presence Intelligence 权重/主动联系 Gate。下一阶段再继续 Awareness→Thought/Desire→Proactive 的自然度调优。

## 8. 后续路线

1. v0.30.1 真机验收：悬浮球长时间可拖/可点、聊天展开/收起后触摸恢复、诊断导出往返后仍可触摸；若再卡死，直接导出报告查看 `overlayTouch`。
2. Presence Intelligence：感知累积、Thought/Desire 形成、主动联系 Gate 自然度。
3. HyperOS / Android 15 锁屏、长时间后台、杀进程/重启后的恢复。
4. 长期记忆几十轮压力测试，检查重复膨胀、冲突更新和 Continuity 污染。
5. 手机/平板 Active Brain 真机顶号 + encrypted `.aicomp` fallback。
6. 最终稳定性回归。

TTS 已进入非阻断小瑕疵阶段；UI 后续可继续微调，但不要阻塞主动陪伴主线。

## 9. GitHub / 构建约定

正常仓库结构：

```text
app/
  android/
  lib/
  test/
  tools/
  docs/
  pubspec.yaml
.github/
  workflows/
    build-apk.yml
README.md
```

- `app/` 是唯一源码真源（single source of truth）。
- v0.28 五分包与历史 patch 已经可以删除，不再作为构建输入。
- 日常 workflow：checkout -> Java/Flutter -> `flutter pub get` -> validators/tests/analyze -> `flutter build apk --release` -> TTS native integrity -> artifact。
- 测试 APK 从 v0.28.4 起使用固定测试签名，后续正常应可覆盖安装；正式发布再换正式私有签名。

## 10. 开发流程约束

- 用户非技术开发者；优先由助手完成代码、静态检查、结构验证和自动测试。
- 只有真人感知/真机行为必须确认时才交 APK 测试。
- 稳定正确优先于速度；大阶段之间主动做回归。
- 每个正式版本同时更新 `docs/HANDOFF.md`。
- 每个大版本保留完整源码 ZIP + SHA-256 作为离线备份。
