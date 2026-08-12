# AI Companion · HANDOFF

> 每个版本都要同步更新本文件。新窗口优先读取本文件，再读取 `README.md` / `docs/DEV_STATUS.md` 和实际源码。不要从旧聊天记录猜当前实现。

## 1. 当前基底

- 当前源码候选：**v0.29.1+35 · TTS / UI Polish**。
- 最近一次用户真机确认稳定：**v0.29.0+34 Clean Baseline**。
- Android 真机：Android 15，REDMI K80 Ultra（Xiaomi/HyperOS）。
- 数据库：**schema v18**，v0.29.1 不做 schema 迁移。
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

## 5. v0.29.1 本轮 UI / Overlay 改动

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

v0.29.1 尚待真机验收，重点只需看：悬浮球视觉、悬浮最近历史、reasoning 顺序、换行 TTS 体验以及无明显回归。

## 7. 已知待办 / 下一阶段

最高优先级不再是 TTS，而是“她对用户手机行为有真实反应”。目前权限/感知入口存在，但真机体验仍表现为用户在手机里做事情时，她几乎不主动回应。

下一阶段固定方向：

1. 手机事件 -> Awareness -> Perception 的真机有效性与去噪。
2. Perception -> Thought / Desire / unfinished thread 的意义判断。
3. Thought/Desire -> 主动消息 / 通知 / 悬浮球反应，避免做成机械事件播报器。
4. HyperOS / Android 15 锁屏、切 App、长时间后台、杀进程后的恢复与主动联系。
5. 长期记忆几十轮压力测试，检查重复膨胀、冲突更新和 Continuity 污染。
6. 手机/平板 Active Brain 真机顶号 + encrypted `.aicomp` fallback。
7. 最终稳定性回归。

UI 后续仍可继续微调，但不要为了轻微视觉/TTS 瑕疵长期阻塞主动陪伴能力开发。

## 8. GitHub / 构建约定

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

## 9. 开发流程约束

- 用户非技术开发者；优先由助手完成代码、静态检查、结构验证和自动测试。
- 只有真人感知/真机行为必须确认时才交 APK 测试。
- 稳定正确优先于速度；大阶段之间主动做回归。
- 每个正式版本同时更新 `docs/HANDOFF.md`。
- 每个大版本保留完整源码 ZIP + SHA-256 作为离线备份。
