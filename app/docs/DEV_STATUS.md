# v0.29.0 开发状态 · A2 TTS / Clean Baseline

## 当前变化

- Android 15 真机已确认：启动、SQLite、权限、聊天生成和 legacy coroutine/ClassLoader TTS 初始化/发声链可用。
- 实物对比 `MejuTTS_A2_OriginalNative_v2.5.apk` 后确认 native 已经正确；句间长停顿来自 AI Companion 自己的串行 `generate + play` 调度。
- v0.29.0 恢复 A2 分句：仅 `。！？；.!?;`，不按逗号/换行/省略号/字符数切分。
- TTS 改为 generation-ahead：一个 FIFO MNN worker 继续安全串行推理，独立 AudioTrack worker 同时播放当前 WAV；后续句可在当前句播放期间准备。
- ready queue 已有下一句时保留约 200ms 间隔；取消/停止使用 process-wide generation epoch fence。
- `libbertvits2.so` 原版 ELF 前 635352 bytes SHA-256 为 `a1ca5180532aae3a7c378371f6ddb44bbf35d8826a8b8750db4fd12179c5551b`，后 75496 bytes 仅为零填充；当前 payload 不修改。
- schema 仍为 v18；Memory / Relationship / Active Brain / Transfer 无迁移。
- GitHub 将从五分包+补丁链晋升为 `app/` 完整源码基底；旧 bootstrap 只在 clean build 成功后清理。
- 版本：`0.29.0+34`。

---

# v0.28.5 开发状态 · Legacy Coroutine/ClassLoader Fix

## v0.28.5 真机 TTS 修复

- Android 15 真机已确认 37/37 黄金资源通过；v0.28.4 的新阻断为 `NoSuchFieldException: INSTANCE`。
- 移除 `EmptyCoroutineContext.INSTANCE` 与静态 `COROUTINE_SUSPENDED` 反射；从真实 legacy `Continuation` 签名派生 `CoroutineContext` 并动态代理。
- `initialize()` 与 `generateTTS()` 共用同一桥；新增不播放声音的分阶段 WAV 诊断。
- schema 仍为 v18；模型/JAR/native 黄金负载未修改；版本 `0.28.5+33`。


## 真机暴露
- v0.28.2 已成功进入完整 App，Android 权限与系统页面可用。
- 深度自检只在 `libbertvits2.so` 报 golden fingerprint mismatch。对已构建 release APK 复核确认：源码/黄金库为 710848 bytes，而 release APK 中被 AGP strip 成 635352 bytes；其它五个核心 Meju native 库保持字节一致。
- 聊天页持续加载并不等于 DeepSeek 连接失败。源码审计发现 ChatController 在 `loading=false` 之前同步等待 long-running maintenance；同时该维护任务会清理 `daily_continuity(window_start)`，但数据库维护 allowlist 漏掉该 table/column，必然抛 `Unsupported maintenance table/column`。真机诊断中的 `hasMaintenanceError=true` 与此吻合。

## v0.28.4 修复
- AGP `packaging.jniLibs.keepDebugSymbols` 明确保留 6 个 Meju 黄金 native payload，尤其避免 `libbertvits2.so` 在 release 中被 strip。
- GitHub build 在上传 Artifact 前逐项比较 APK 内 6 个 native 库与源码黄金库 SHA-256/size，不一致直接失败。
- `daily_continuity` + `window_start` 纳入长期维护 allowlist。
- Chat 先读取消息并结束可见 loading，再异步执行 best-effort maintenance；任何维护异常不能再造成永久转圈。
- 设置页增加“测试 API 连接”，用当前 endpoint/Key/model 做 30 秒受控探针，不写入聊天与长期记忆。
- 数据库 schema 保持 v18；Memory/Relationship/Transfer/TTS 模型与运行时内容不改。
- 版本更新为 `0.28.4+32`。

---

# v0.28.2 开发状态 · Android SQLite Open Fix

## 真机触发原因

- v0.28.1 已成功绘制启动恢复页，证明 Flutter 首帧修复生效。
- REDMI K80 Ultra / Android 15 在“打开本地数据库”阶段返回：`Queries can be performed using SQLiteDatabase query or rawQuery methods only`，指向 `PRAGMA journal_mode = WAL`。
- Android `SQLiteDatabase.execSQL()` 不允许执行返回数据的 SQL；`journal_mode` 会返回实际模式，因此 sqflite `execute()` 会失败。

## v0.28.2 修复

- 保留 `foreign_keys = ON` 的执行语义。
- `journal_mode = WAL` 改为 `rawQuery()`，并校验实际返回值必须为 `wal`；不允许静默降级。
- `synchronous = NORMAL` 同样走 `rawQuery()`，避免 Android 对 query-returning PRAGMA 的 execute 限制。
- schema 仍为 v18；Memory/Relationship/TTS/Active Brain/Transfer 不改。
- 版本更新为 `0.28.2+30`。

---

# v0.28.1 开发状态 · Startup Recovery Patch

## 真机触发原因

- REDMI K80 Ultra / Android 15 首次 release APK 可安装，但启动后内容区永久纯黑；无权限弹窗，系统状态栏/导航栏仍可见。
- 首次真实 Flutter release build 同时暴露并修复 `durable_generation_runner.dart` 缺少 `DriveKey` import。
- 源码审计确认 v0.28 `main()` 在 `runApp()` 前同步等待 `AppDatabase.ensureReady()`，任何 SQLite/identity 初始化阻塞都会直接造成“第一帧永远不出现”。

## v0.28.1 修复

- `runApp()` 立即执行；第一帧先显示 Startup Recovery 页面。
- 数据库打开与本机身份分为独立可见阶段，分别设置 30s / 10s 诊断超时。
- release 模式 Widget 构建错误使用可见 ErrorWidget，不再只留下纯黑区域。
- SQLite 打开增加 in-flight Future 复用，超时/重试不会并发打开两个数据库。
- schema 仍为 v18；TTS 黄金负载、Memory/Relationship、Active Brain、Transfer 协议不改。
- 版本更新为 `0.28.1+29`。

---

# v0.28 开发状态 · First Real-device Checkpoint Harness

## 已完成

- 新增“第一次综合真机验收”页面，不新增第二套功能逻辑，只把现有真机能力按风险顺序组织。
- 测试顺序固定为：快速自检 → 深度 TTS 黄金/JNI 初始化 → 生产 TTS 真正发声 → Android 权限/感知 → 悬浮/后台/通知 → 手机↔平板顶号。
- TTS 发声测试直接调用正式 `TtsService.preview()`，不使用测试假引擎；固定句包含 `Yuki`，用于同时听 `Yuki -> 有希` 的 spoken-only 替换。
- 固定测试句不进入聊天、Memory、RelationshipEvent、Thought、Daily Continuity 或 Reference。
- 任何真机失败继续导向 v0.27 的脱敏诊断报告，不增加云端日志。
- schema 保持 v18；Active Brain、Memory、Relationship、Nearby ownership 协议和 MejuTTS 黄金负载均不修改。
- 新增 `tools/check_android_build_env.py`，明确区分“源码验证失败”和“外部 Flutter/Android 构建工具缺失”。
- 版本更新为 `0.28.0+28`。

## 当前构建边界

- 当前执行环境实际只有 Java/Kotlin，没有 Flutter SDK、Dart、Android SDK、ADB，也没有完整 Gradle wrapper binary。
- 已尝试从可用网络通道补齐 Flutter SDK，但约 1GB SDK 归档无法通过当前文件下载通道，因此本阶段不虚构 APK build 结果。
- v0.28 的目标是把首个真机 APK 的测试入口与故障诊断准备好；一旦进入具备 Flutter/Android toolchain 的构建环境，可直接生成综合 checkpoint APK。

## 阶段回归重点

- Checkpoint 页面只调用现有 read-only preflight / TTS preview / Android perception / navigation，不直接写关系状态。
- v0.27 privacy/redaction/Native preflight 回归。
- v0.26 transfer generation/replay/fencing 与 AES-GCM 备用包回归。
- v0.25 TTS queue/Kotlin/golden payload freeze。
- v0.14-v0.24 Durable Generation、Recovery、Reference、Awareness、Relationship、Memory、Proactive Rhythm、Daily Continuity 全部 SQLite 回归。

---

# v0.27 开发状态 · Real-device Readiness / Preflight Diagnostics

## 已完成

- 新增独立“真机测试前自检”页面：快速自检只读运行状态；深度自检额外执行 37 项 TTS 黄金校验 + JNI/MNN 初始化，但不会发声。
- schema 保持 v18；诊断不进入关系同步数据库，不新增第二套 Memory/日志云端。
- 新增 `NativePreflightProbe`：App/Android 版本、后台限制、电池优化、权限、Google Play services、Nearby 权限/蓝牙/定位条件与音频输出路由。
- 新增 `RuntimeDiagnosticStore`：SharedPreferences 本地环形历史，最多 160 条 / 30 天。
- Nearby 在统一 emit 边界保存脱敏阶段日志；endpoint discovery churn 不落盘；session/device/snapshot/hash 仅保存短 SHA-256 指纹。
- TTS 保存黄金资源校验、JNI/MNN 初始化与推理失败类型；推理失败日志不保存 spoken text 或可能回显正文的错误 detail。
- 新增纯 Kotlin `DiagnosticRedaction`，JVM 测试验证路径、UUID、长哈希不会原样泄漏。
- Preflight 报告只包含数据库计数/ownership flag/短指纹、权限与 runtime 状态、TTS 状态和脱敏 Native 历史。
- 报告明确不读取聊天/思考链正文、Memory/Relationship/Thought/Reference/Daily Continuity 文本、raw notification/accessibility、使用包名历史或 API Key。
- Android SAF 新增脱敏诊断 `.txt` 保存路径；临时报告在 picker 返回后删除，不上传服务器。
- `requestNearbyPermissions` 与 preflight 使用同一版本化权限清单，避免“页面说缺一个权限、请求却问另一组”的漂移。
- 版本更新为 `0.27.0+27`。

## 本阶段边界

- 不自动修复 Active Brain / transfer lock；只报告状态，避免诊断页变成第二套 ownership writer。
- 不自动播放 TTS 测试音；真正声音一致性与首句延迟留给真人实机。
- 不引入 Firebase/Sentry/Analytics 或任何云端诊断。
- 当前无 Flutter/Android SDK，不声称 APK build 或 Android 硬件行为已经通过。

## 阶段回归重点

- diagnostic privacy / redaction / retention bound。
- NativePreflightProbe Kotlin stub compile。
- Nearby v3 / manual crypto / TTS Kotlin/queue 回归。
- v0.14-v0.26 Durable Generation、Recovery、Reference、Awareness、Relationship、Memory、Proactive Rhythm、Daily Continuity、Transfer 全部 SQLite 回归。
- v0.26 baseline 冻结对比与 37 个 TTS 黄金 payload byte freeze。

---

# v0.26 开发状态 · Phone↔Tablet Sync Integrity / Transfer Hardening

## 已完成

- schema v17 -> v18；新增安装本地 `transfer_receipts`，以及 `state_lineage_id / state_generation / pending transfer` 身份设置。
- 每次冻结状态包分配唯一 `snapshot_id`，并绑定 relationship lineage、source device、单调 ownership generation、目标激活代次、SHA-256 与 byte length。
- Snapshot v2 严格校验 manifest / state root / settings 三层身份一致；旧包、损坏包、截断包、snapshot-id collision 均 fail closed。
- 同 lineage 只接受严格更高 generation；成功目标激活会再次 generation+1，使刚用过的包立即变旧。
- `transfer_receipts` 不随状态包覆盖，并与目标整库导入在同一个 transaction 提交；重复投递可安全识别为 no-op。
- Nearby 控制协议升级为 `ai_companion_takeover_v3`，request/ACK 绑定 exact snapshot session，不再使用固定 V2 字符串。
- 源设备收到匹配 takeover request 后，由原生 SQLite transaction 再核对 active/lock/lineage/generation/pending snapshot，先 fence 成 standby，之后才发送 ACK。
- ACK 丢失时源端保持下线、目标保持 standby，优先避免双 Active Brain；迟到/错会话 ACK 不允许激活。
- 被挤下线设备只改变 ownership，不删除本地关系/记忆数据。
- 新增手动 `.aicomp` 备用：Android SAF 文件选择器 + PBKDF2-HMAC-SHA256 + AES-256-GCM；口令不持久化，内部 snapshot 继续保留 SHA-256。
- 手动导出成功后源设备先 standby；目标导入也先 standby，需明确确认接管。
- standby 只停止当前 overlay service，不再永久擦除用户的 overlay preference；overlay/background brain 恢复增加 Active Brain gate。
- 版本更新为 `0.26.0+26`。

## 本阶段边界

- Nearby 仍为正常路径，手动文件只做厂商/网络异常兜底。
- 不引入云账号、服务器真源或双端冲突合并；SQLite + single Active Brain 仍是权威模型。
- 不自动删除 standby 设备本地数据。
- TTS 模型/runtime/native 黄金负载不修改。
- 当前无 Flutter/Android SDK，不声称 APK build、Nearby 射频链路、系统文件选择器或双真机时序已经实测。

## 阶段回归重点

- v17 -> v18 migration / lineage-generation ownership。
- replay / stale / corruption / wrong-session ACK / snapshot-id collision。
- import + receipt transaction rollback。
- source fence-before-ACK / target ACK-before-activation。
- manual AES-GCM roundtrip / wrong password / truncated package。
- Nearby/Native transfer Kotlin stub compile。
- v0.13-v0.25 旧数据库、durable generation、recovery、memory、awareness、relationship、TTS 回归。

---

# v0.25 开发状态 · Native TTS Core Integration

## 已完成

- 以用户提供的 `MejuTTS_DoomsdayBridge_v2.7.apk`（SHA-256 `63a8c10f...c58c5e7`）作为黄金行为/资源基准。
- 22 个模型/预处理资源、6 个 arm64 `.so` 与黄金 APK 逐文件一致。
- 9 个 compatibility runtime JAR 内 `classes.dex` 与黄金 APK `classes.dex`～`classes9.dex` 9/9 一致。
- `runtime_01.jar` 内 5 个 pinyin 字典及 NLP classpath 资源与黄金 APK 一致。
- AI Companion 源码树不携带 HTML / JS；TTS Kotlin 链不依赖 WebView/JavascriptInterface。
- 新增 `TtsGoldenBaseline` / `TtsArtifactVerifier`：初始化前按 SHA-256 + size 校验 37 项核心负载。
- Settings 的“检查 TTS”升级为强制黄金校验，可显示校验状态/项数/黄金参考。
- 修复旧 runtime 私有缓存可能在 APK 更新后继续加载旧 JAR 的问题：v0.25 使用版本化 cache + 指纹校验 + 原子重拷贝 + read-only。
- `TtsPlaybackQueue` 抽出最小 `TtsQueueService` 接口，补 stop/cancel、单句失败不中毒后续队列、流式 FIFO 测试源。
- TTS 错误诊断写 SQLite 改为 best-effort，语音失败不能反向破坏聊天/主动联系 durability。
- `Yuki -> 有希` 仍只作用于 spoken text；reasoning_content 仍不进入语音链。
- schema 仍为 v17。
- 版本更新为 `0.25.0+25`。

## 本阶段边界

- 不重写已验证的中文 G2P/前处理；先保留隔离的 compiled dependency closure，避免音色/读音回归。
- 不把原 HTML/WebView/JS 外壳带进 AI Companion。
- 不修改 Memory、Relationship、Awareness、Daily Continuity、Active Brain、Nearby 协议。
- 当前无 Android SDK / Flutter SDK，不声称 APK、JNI/MNN、AudioTrack 真机通过。
- 主观音质、首句延迟、后台音频、蓝牙耳机/来电中断留到首次必须真机的 APK checkpoint。

## 阶段回归重点

- 黄金 APK / source payload hash 对比。
- 37 项 runtime integrity gate。
- stale runtime cache replacement。
- queue stop/cancel/error isolation。
- Kotlin TTS bridge/runtime stub compile。
- v0.13-v0.24 旧数据库/恢复/主动联系/Reference/Awareness/Relationship/Continuity 回归。

---

# v0.24 开发状态 · Companion Continuity / Daily Reflection

## 已完成

- schema v16 -> v17，新增本地 `daily_continuity` 短期连续性表。
- 不新增模型“每日写日记”路径；连续性记录完全由本地确定性规则从真实旧数据压缩。
- 每个 local day 最多一条 UNIQUE row；当天可更新，昨天在下一次 Active Brain 运行后固化并禁止后续改写。
- 来源限制为 RelationshipEvent、active unfinished thread、companion-facing Thought、粗粒度 Awareness 与实际消息活动。
- AI Self reflection 继续独立，`self_reflection_run:*` / perception Thought 不进入用户-facing daily care。
- unresolved thread 最多每天带 1 条；前两天已经展示且今天没有新更新的 thread 不重复搬运。
- quiet day 显式中性化：不把安静或普通相处解释为疏远/关系倒退，也不为了“每日进展”制造 milestone。
- Prompt 最多注入最近 2 天；明确说明不是新事实来源、不是 AI 日记、不要逐条复述。
- post-turn extractor 增加 anti-recursion 规则：AI 仅复述旧连续性不能自动生成新的 memory / relationship_event / thread。
- post-turn durable maintenance 与 proactive heartbeat 两条现有路径负责刷新；不新增 Android scheduler。
- continuity 写事务内再次检查 `active_brain` + `transfer_lock`，standby/接管冻结期间不能写。
- continuity 故障与旧核心隔离，不会阻断 proactive heartbeat、Memory Maintenance 或 AI Self reflection。
- full-state snapshot 加入 `daily_continuity`；v16 状态包导入 v17 保持兼容。
- 长期维护限制为约 180 天 / 最多 220 条；永久事实继续由 Memory / RelationshipEvent 保存。
- Home 增加轻量“今天/昨天还在延续”卡片；`你们之间`增加“最近几天”，standby 明确显示为上次同步状态。
- 版本更新为 `0.24.0+24`。

## 本阶段边界

- 不新增第二套长期历史库。
- 不使用模型生成每日总结，不产生额外 API 消耗。
- 不让 daily continuity 自身成为新的 memory/event 事实来源。
- 不把 raw package、通知正文、Accessibility 原文写入连续性记录。
- 不修改 TTS、Durable Generation、Active Brain、Nearby 接管协议的核心实现。
- 当前环境无 Flutter / Android SDK，因此不声称 APK 编译、布局渲染或 Android 后台真实调度通过。

## 阶段回归重点

- v16 -> v17 additive migration / old-state import。
- same-day retry exactly-once / finalized-yesterday immutability。
- standby / transfer transaction write fence。
- unresolved thread anti-repeat / real-update resurfacing。
- quiet-day neutral semantics。
- two-day Prompt cap / anti-recursion。
- full-state phone/tablet transfer。
- 180-day / 220-row retention bound。
- v0.23 proactive rhythm / v0.22 memory / Awareness / Relationship / Reference / Home / durable generation / async ownership / Recovery 全部继续通过。
- v0.23 baseline 外 231 个未授权旧文件逐字节一致。
- v0.23 TTS 41 个关键文件逐文件 SHA-256 一致。