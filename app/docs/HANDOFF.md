# AI Companion · HANDOFF

> 每个正式版本都要同步更新本文件，并核对 `docs/PROJECT_TASK_LEDGER.md`。新窗口优先读取这两个文件，再读 `README.md` / `docs/DEV_STATUS.md` 和实际源码；不要从旧聊天记录猜当前实现。

## 1. 当前基底

- 当前源码候选：**v0.31.2+42 · Companion Voice Recovery**；尚待 GitHub Actions 完成 Flutter analyze/test/release APK。
- Android 真机：REDMI K80 Ultra，Android 15，Xiaomi/HyperOS。
- 数据库：**schema v19**；为消息新增独立 provider reasoning 与 Companion Voice 标记，Desire snapshot 结构未改。
- GitHub：完整 Flutter 项目位于仓库 `app/`，它是 single source of truth；不恢复历史 v0.28 五分包 + patch 链。
- 最近已知 Overlay 真机结果：v0.30.2 曾出现 `selfHealCount=28 / coverRecoveryCount=11`；v0.30.3 仍可 100% 复现“只要打开系统文件选择器/上传文件页，无论确认或取消，悬浮球之后都会可见但 input channel 卡死；重新进入 AI Companion 后恢复”。该问题影响较大，已从 FROZEN 重新列为 **P0 NEXT**，但不与 Companion Voice 首版混改。

## 2. 项目定位

这是长期本地优先的**女性 AI 伴侣 / AI 女友**，不是角色卡聊天器、小说生成器或一次性 RP。她知道自己是 AI，可以自然打破第四面墙；RP/Intimacy 是会话能力，不覆盖 AI Self。

固定原则：

- 手机/平板同一时间只有一台 **Active Brain**；接管后旧设备 standby，不删本地数据。
- 聊天、Memory、Relationship、Thought/Desire、Awareness、Daily Continuity 等主要状态在本地 SQLite。
- DeepSeek provider reasoning、模型生成的第一人称 inner voice、最终 reply 三者独立；OFF 保持原版 reasoning 展示，ON 只把显式 inner voice 当成“她的内心”。
- Reference 是低优先级参考，不能把 AI 本体变成角色卡。
- Raw package name、通知正文、Accessibility 正文不进入长期 prompt / Thought / 脱敏诊断；先本地粗粒度化。
- 主动联系 hard caps 保持 **2/2h、8/24h**；busy 是 soft friction，不是绝对静音。

## 2A. 关键历史基线（压缩）

- **v0.29.0 Clean Baseline**：GitHub `app/` 完整源码独立构建、真机安装、Meju A2 generation-ahead 通过。
- **v0.29.1 UI/TTS Polish**：reasoning 在正文上方、悬浮球尺寸/角标/最近 8 条历史等 UI 完成；随后暴露 background Dart command server 不可达问题。
- **v0.30.0 Background Presence**：修复 root entrypoint/AOT reachability 与 ready race，建立 `signal:*` reactive wake。
- v0.30.1~0.30.3 主要围绕 HyperOS Overlay touch/recovery；最终 file-picker 路径仍未解决，2026-08-13 因稳定复现且影响较大重新进入待修主线。

## 3. v0.31.0 · Reality Grounding

用户真机曾发现三个基础事实错误：

1. `user: 你好 -> assistant 已回复 -> 用户沉默` 后，proactive 又把“你好”当待回复输入。
2. 后续 proactive 幻觉“你刚才说了‘是我’”，实际用户没说话。
3. 模型会自行猜早晚，因为 prompt 没显式提供当前本地时间。

v0.31.0 处理方式：

- 新增 `GroundingSnapshot / GroundingEngine`。
- 每次普通聊天与 proactive 都显式注入设备本地日期、时间、UTC offset、星期、daypart。
- 从 metadata-only `messages` headers + `generation_jobs(user_message_id -> assistant_message_id)` 确定：last user/assistant、last user 是否已回答、pending user turn、用户是否在 AI 上次发言后再次开口、last user 后有多少 AI/proactive 消息。
- 历史老数据若没有 generation job，仅允许**非 proactive assistant**作为“该 user turn 已回答”的兼容 fallback。
- Prompt 中新增 `REALITY GROUNDING` 硬边界：只有真实 `role=user` 可以引用成“你说过”；Thought/Memory/Awareness/Self Experience/Inference 都不是用户原话。
- 主动联系不再把 `intent.reason` 冒充 `latestUserText`。内部 reason 只作为 retrieval query 和明确标注的内部原因，因此不会误触“按真实用户文本触发”的规则层。
- 新增 `ProactiveGroundingGuard` 最终硬拦截：当 SQLite 明确显示用户在 AI 上次发言后没有再说话时，候选 proactive 若声称“你刚才说/你刚刚说/你刚回复……”会在写入数据库前被丢弃，并只记录脱敏 guard reason/count。
- 当前粗粒度 Awareness 作为独立 `AWARENESS` block，允许不确定，不向模型伪装成用户发言。

## 3A. v0.31.1 · Proactive Context Isolation / Reasoning Grounding

v0.31.0 真机脱敏诊断已经证明数据层判断正确：`lastUserAnswered=true / pendingUserTurn=false / userSpokeAfterLastAssistant=false`。但用户可见的 DeepSeek reasoning 仍会出现“回复用户的你好”之类思路，说明问题剩在**模型消息形状**而不是 SQLite Grounding。

v0.31.1 处理：

- 普通 user turn 继续用真实 `role=user/assistant` 历史。
- proactive generation 不再把旧聊天作为可被模型视为 current turn 的 role 序列；改成只读 `ANSWERED CHAT HISTORY` system transcript，并把真实历史标为 `REAL_USER_HISTORY / ASSISTANT_HISTORY / ASSISTANT_PROACTIVE_HISTORY`。
- 主动生成显式加入 `CURRENT_USER_TURN=NONE / ANSWERED_HISTORY_ONLY=true`；reasoning 和正文都不得把已回答历史重新当成本轮问题。
- 新增 `ProactiveReasoningGroundingGuard`：在“last user 已回答 + 用户沉默 + 无 pending user turn”时，窄范围检测 reasoning 是否又进入“回复/回答已回答历史”的模式。
- 正文或 reasoning 首次违反 Grounding 时，允许 **一次纠正重试**；重试仍违规则整条 proactive 不落库，错误 reasoning 不展示给用户。
- 浅层诊断记录 Grounding retry count/last reason，但不记录 user text 或 reasoning 正文。

## 3B. v0.31.1 · Chat Timestamps

- 主聊天 UI 每条消息显示本地 `HH:mm`；跨本地自然日显示“今天/昨天/日期 · 周X”分隔。
- 时间戳来自现有 `ChatMessage.createdAt` metadata，不写进 `message.content`。
- TTS 仍只朗读 `message.content`，因此不会读时间戳/日期。
- 本版不修改 Android Overlay；悬浮聊天是否显示时间后续再做，不解除 Overlay FROZEN。

## 3C. v0.31.2 · Companion Voice Recovery

- 设置新增默认关闭的“伴侣式内心与回应”。OFF 不注入协议，完整保留 v0.31.1 provider 原版 reasoning、正文流式与流式 TTS 路径。
- ON 在真实 prompt 尾部只加入一次输出协议，模型 content 必须严格分成 `<companion_inner>` 与 `<companion_reply>`；标签外文字不接受。
- 独立解析器要求第一人称/主观内心，拦截“我们需要回答用户、用户要求、系统提示、根据规则、保持 AI 本体身份”等 Agent/规则清单语言；不强迫撒娇、暧昧或动作描写。
- 普通聊天格式/污染失败最多纠正一次，再失败不保存混杂 candidate；主动联系与 Reality Grounding 共用一次纠正预算，再失败按 WAIT/guard block。
- schema v19 为 `messages` 新增 `provider_reasoning` 与 `companion_voice`。旧 reasoning 在升级时回填为 provider reasoning，历史显示不变；ON 新消息分别保存 raw provider reasoning、inner voice 与 reply。
- ON 模式不把未验证标签流式透传到 UI/TTS；验证后显示“🧠 内心”，TTS 只朗读 reply。OFF 仍显示“🧠 思考”并保留流式分句朗读。

## 4. v0.31.0 · Grounded Desire Core 第一批

用户提供了 10 张第三方 Desire System 参考截图。参考中可能针对男性 AI / “哥哥/朝灯/GitHub/web_browse”等场景；本项目**只吸收机制，语义全部按女性 AI 伴侣重写**。

现有系统本来已有 8 Drive、Thought lifecycle、satisfy、refractory、coupling、baseline drift、self-drive、Presence、Proactive Gate，因此不另造第三套系统。

v0.31.0 新增/强化：

- 8 Drive：`attachment / curiosity / reflection / duty / social / libido / stress / fatigue`。
- 新 `DesireCorePolicy` 是可确定性测试的纯策略层：不读数据库、不读 wall clock、不用随机数；调用方显式给 `now`。
- Thought provenance：`user_message / awareness / memory / self_experience / inference / internal`。
- Thought/Fixation 对 summon score 使用 bounded + diminishing boost，不能无限堆叠。
- per-drive refractory：刚满足的 Drive 暂时不能连胜，其他 Drive 仍可行动。
- fatigue >= rest gate 时返回 `rest`，不因为“累”而硬发主动消息。
- bounded coupling：小系数联动，长 catch-up 单次 contribution 有 cap。
- action-aware satisfy：`reach_out / continue_thread / share_thought / check_in / tease_or_intimacy / comfort_or_ground / remember_shared_experience / wildcard_share` 按主/相关 Drive 软回落；`rest/wait` 不靠“发消息”假装消除 fatigue。
- proactive 成功发送后只做中等 satisfy；真正用户 response 仍由 Thought lifecycle / Proactive feedback 后续处理。
- `libido` 只是亲密倾向，不得单靠数值打开 NSFW；现有 Intimacy Session / consent / rules 仍是权威边界。

仍留给后续 v0.31.x：baseline drift 的长期 pullback 深化、自驱经历对 proactive response outcome 的显式回路、真正的 wildcard pressure-release action、libido/Intimacy 更细映射。

2026-08-13 静态复核补充：

- Desire 不是只写了数据结构：8 Drive、纯策略 tick、Thought lifecycle、self-drive、heartbeat、proactive gate、grounding guard、一次纠正重试、发送后 satisfy 与用户响应反馈均已接入实际运行路径；相关 Desire/Grounding validators 通过。
- `self-drive` 与响应结果回路已经有第一阶段实现，后续重点应改为长期 baseline/自我经历平衡，而不是重复建设整套 self-drive。
- 当前 `PromptBuilder` 仍会把完整 Thought 文本拼入 system prompt。虽然有 provenance 标签和事实边界，但这尚未完全满足“Thought 是数据而非指令”的隔离要求；后续应改成有界结构化摘要/关键词，不直接注入原始全文。
- baseline 已有 anchor/cap，但没有明确的长期时间/关系 pullback；现有正向 baseline learning 可能逐步累积到上限。
- wildcard 目前只是随机 pulse 普通 Drive，并未形成“正常候选都不可执行时的泄压 action”；`wildcard_share` 基本未走通。
- `libido -> tease_or_intimacy` 的候选映射存在，但确定性策略层没有显式要求当前 Intimacy Session；现在主要依赖 prompt/rule 层约束，后续需补硬 gate。
- 自主 heartbeat 依托 Android Overlay foreground service/background engine；关闭悬浮球或服务停止时，不存在另一条独立 WorkManager 自主心跳路径。普通前台聊天仍会推进状态。

## 5. Presence / 主动联系迁移

v0.30.0 **Background Presence** 已建立：notification / Accessibility window / device-present 只发送粗粒度 `signal:*` wake，90 秒去抖，然后走原有 Perception -> Thought/Desire -> Gate，不绕过 Active Brain、leases 或 hard caps。

v0.30.2 的 `PresenceMomentumPolicy` 已经在真机产生 `presenceMomentum=0.88`、Thought，因此保留。

v0.31.0 改变的是职责：

```text
phone activity -> Presence -> Drive pulse / Thought -> Desire Intent
                                                ↓
                                      Proactive delivery Gate
```

Presence 不再一边推 Drive/Thought，一边又直接给 Gate 加一遍分。`presenceBoost=0`，诊断写 `presenceAppliedToDesire=true`。Gate 继续负责 Active Brain/transfer/chat lease、frequency caps、busy/timing friction、model WAIT 与投递安全。

## 6. 可观测性

浅层脱敏诊断新增：

- `database.grounding`：localDate/localTime/UTC offset/daypart、conversationState、pending/answered、user/assistant silence ages、proactive count，以及 proactive factual/reasoning guard 的 block/retry count 与 last reason；**没有 message id/body**。
- `database.desireCore`：8 Drive、baselines、refractoryMinutes、last intent/satisfy、fatigue gate、selected/top candidates（只含 drive/action/score/source class，不含 Thought 正文/reason）、Thought provenance 计数。
- `database.companionVoice`：enabled、retry/block count、last time 与枚举原因；不含 provider reasoning、inner voice 或聊天正文。
- `backgroundPresence.lastGateBreakdown` 保留，v0.31 可看到 Presence 已进入 Desire 而不是重复 Gate boost。
- “她的内心”调试页显示 Reality Grounding 与 top Desire candidates，便于强制 proactive 做事实边界回归。

## 7. Overlay / 悬浮球 · P0 NEXT

- v0.30.1/0.30.2/0.30.3 已做过多轮 WindowManager input recovery；旧 `overlayTouch` 脱敏诊断仍保留。
- HyperOS/Android 15 的系统文件选择器/上传文件路径可 100% 触发：文件页位于悬浮球之上属于系统窗口层级的正常现象；真正故障是退出/切回其他 App 后悬浮球仍可见却不可触摸。
- 现有代码并非没有自愈：Accessibility system-cover、Overlay root visibility、`MainActivity.onResume -> ACTION_RECONCILE` 都能请求 `removeViewImmediate + createBubble` 重建 input channel。用户重新进入 AI Companion 后恢复，正是 Activity reconcile 路径生效。
- 根因边界是“系统遮挡已经结束”的证据不可靠：当前主要依赖有限 package allowlist 与 `TYPE_WINDOW_STATE_CHANGED`；OEM picker/Photo Picker 变体或返回事件一旦漏报，`overlayInputSuspect` 就不会被后台消费。
- 30 秒 permission watch 只检查 attached/flags/enabled，不会在 suspect 状态下重建 input channel；而本故障中这些表面状态仍可能全部健康，所以 watchdog 看不出来。
- 后续修复应做**有界的一次性状态机**：明确 cover-enter/suspect，已知 cover 后允许更宽但安全的非系统事件确认 exit，遗留 suspect 再用带次数上限/退避的一次 watchdog 重建；不得恢复 v0.30.2 的无界重建风暴，也不得在系统文件页仍位于顶层时反复重建。

## 8. TTS 黄金基准 · FROZEN / GUARDRAIL

行为参考 APK：`MejuTTS_A2_OriginalNative_v2.5.apk`。

- 原始 `libbertvits2.so` ELF 635,352 bytes，SHA-256 `a1ca5180532aae3a7c378371f6ddb44bbf35d8826a8b8750db4fd12179c5551b`；APK padded 到 710,848 bytes。
- `Yuki -> 有希` 只改朗读文本。
- 只按 `。！？；.!?;` 分句；不按逗号/换行/字符数切。
- A2 generation-ahead + FIFO + ready WAV 约 200ms gap。
- 不重做 native/MNN/threading/WAV concat/cache；轻微节奏问题非阻断。
- 当前显示的 TTS 版本号可能存在修改后的遗留不一致；用户确认实际 TTS 没有严重问题，只有断句时一点停顿，因此版本号与轻微停顿一并冻结，不进入近期补丁。

## 9. 后续重要任务（不可遗忘）

长期任务真源：`docs/PROJECT_TASK_LEDGER.md`。

P0 / v0.31.2：**Companion Voice Recovery（可选勾选）**源码与本地静态回归已完成；等待 GitHub Actions 构建和真机 golden cases 验收。

P0 NEXT：修复 HyperOS/Android 15 file-picker 后 Overlay input channel 卡死；与 Companion Voice 分开补丁、分开验收。

P1：

- Grounded Desire Core 定向收尾与真机数据调优：Thought 原文隔离、baseline pullback、真正 wildcard、libido/Intimacy 硬 gate。
- HyperOS / Android 15 长后台：锁屏、划掉 App、数小时 idle、process recreation、boot/package replaced；完整 Activity destroy 后 durable generation 仍可恢复。
- 50/100/数百轮长期 Memory/Thought/summary/thread 压力测试。
- 手机/平板 Active Brain 真机双向 takeover + Nearby + encrypted `.aicomp` fallback。

P2：

- Grounded Desire 真机数据后的 proactive 二次调优。
- Notification Experience：App 前台静音、外部/锁屏系统通知、可选提示音/试听/音量/震动/锁屏隐私；系统/HyperOS 保留最终通知控制权。
- Intimacy/NSFW Session 与 libido 深度融合，但普通聊天不自动色情化。
- 隐私/安全/可靠性审计。
- Clean Freeze、删除临时 patch/apply workflow、正式 release signing、升级/备份/崩溃恢复。

## 10. v0.31.2 真机验收重点

1. 覆盖安装后新开关必须默认关闭；OFF 下 reasoning、正文流式和流式 TTS 与 v0.31.1 一致。
2. ON 下短问候、深夜陪伴、昵称承接、暧昧玩笑、主动想念显示第一人称“🧠 内心”，不能出现 Agent 清单。
3. 普通办事、严肃话题、拒绝亲昵不能被强行套成撒娇/色情/固定动作模板。
4. ON 下 TTS 只读最终 reply；不读 inner voice、provider reasoning、协议标签或时间戳。
5. 已回答历史后的 proactive 仍遵守 Grounding；协议或 Grounding 纠正总计最多一次，再失败静默 WAIT/拦截。
6. 关闭开关后立即回到原版 provider 路径；历史消息、导出导入、Active Brain、Desire/Thought 不回归。Overlay file-picker 问题不判 v0.31.2 失败。

## 11. GitHub / 开发流程

- `app/` 是源码真源。
- 普通小版本：一次性 source-update patch -> 手动 Apply workflow -> validators -> Flutter analyze/test -> release APK -> 自动 commit `app/`；无需每个小版立刻 Clean。
- 临时 patch 可留 2~3 个小版本；阶段性稳定点再 Clean Freeze 并统一删除。
- 测试 APK 使用固定测试签名，可覆盖安装；正式发布再换私有签名。
- 用户非技术开发者：优先由助手做静态/自动回归，只有真机行为必须确认时才交 APK。
- 每个正式版本更新本 HANDOFF；大阶段保留完整 source ZIP + SHA-256。

### 11A. 2026-08-13 新窗口源码基线与交付方式

- 用户已交付 GitHub 完整源码归档 `ai-companion-build-main.zip`；ZIP SHA-256 为 `dd72984250cfc03445e60638d423709acb2790adba88af3768d6f6b4dc02e373`，归档携带的 commit 标识为 `7dbd19f9280d17d459af589bc27f11110fdbfc27`。
- 归档内 `app/` 为 `v0.31.1+41`、schema v18；`v0311-proactive-grounding-timestamps.patch` 按工作流真实 `--directory=app` 语义反向校验通过，证明 v0.31.1 已完整合入源码树。
- 先前失败的 v0.31.2 补丁已被用户删除，**不属于当前基线**；本轮从 v0.31.1 完整源码重新实现，不复用旧补丁。新 patch/workflow/validator 必须作为一组交付。
- 大阶段内允许连续 2~3 个小版：每版交付 `source-update patch + 完整手动 Apply workflow`，Actions 负责 validators -> Flutter analyze/test -> release APK -> commit `app/` -> 上传 APK/SHA-256。阶段验收后再做仓库整合、完整回归与 Clean Freeze，届时由用户删除已应用的旧补丁。
- 当前 ChatGPT Work 环境可编辑/审计源码并运行 Python validators，但没有 Flutter/Android SDK/Kotlin 工具链，因此最终 analyze/test/APK build 仍以 GitHub Actions 为权威结果。
- 本次基线静态回归：22 项现行核心 validator 中 21 项通过；`validate_manual_crypto_v26.py` 因环境缺少 `kotlinc` 未能执行到断言，记为环境未验证，不记为源码失败。

### 11B. 2026-08-13 Companion Voice / Overlay / Desire 静态审计

- 本轮只做源码、历史资料与截图审计，**没有修改业务代码**；失败的 v0.31.2 Companion Voice patch 继续排除在基线之外。
- 更新后的 DeepSeek V4 Pro 把 provider `reasoning_content` 改成明显的 Agent/规则清单式规划；当前 App 又把该字段直接当作“思考”展示，因此截图出现“我们需要回答用户 / 保持 AI 本体身份 / 不要假装现实人类”等元指令，并伴随通用、客服式正文。这是 provider compatibility 问题，不是 Desire/Grounding 回归。
- 更新前截图的目标特征不是固定撒娇词，而是：第一人称主观内心、关系连续性、主动好奇、会接住昵称和玩笑、少量自然动作/停顿、语气随当下变化，并避免客服式复述与采访式连问。
- v0.31.2 设计边界：设置页只提供一个可选勾选项；OFF 完整保留当前请求/流式/存储行为且不注入协议，ON 才要求模型输出独立 `inner_voice` 与 `reply`。provider reasoning 仅保留为诊断来源，不直接充当用户可见内心；TTS 只读最终 reply。
- ON 模式应在真实 prompt 尾部只注入一次明确协议，解析后校验第一人称与 Agent 污染；缺失/格式错误最多纠正一次，proactive 仍机械或不 grounded 时直接 WAIT。她仍明确知道自己是 AI，不伪造现实身体/外部经历，也不强迫每轮亲昵或动作描写。
- 已采用 schema v19 分开保存 `provider_reasoning / reasoning_content(inner voice 或 legacy reasoning) / content`，并用 `companion_voice` 标记展示模式；旧消息迁移后保持原样。
- 截图将作为 Companion Voice golden cases：短问候、深夜陪伴、昵称承接、暧昧玩笑、主动想念；同时补充“用户只想办事/严肃话题/拒绝亲昵”的反例，防止把女友感写成单一滤镜。
- 交付决定：三项修改拆成三个可覆盖安装、可独立回滚的小版本，不合并。`v0.31.2` 只做 Companion Voice；`v0.31.3` 只做 Overlay file-picker 恢复；`v0.31.4` 再做 Desire 定向收尾。每版分别交付 source-update patch、完整替换 workflow、validator 与 APK/SHA-256；前一版真机验收后再进入下一版。
- v0.31.2 验收期间冻结 Overlay 与 Desire 行为；v0.31.3 不改 prompt/model/storage；v0.31.4 不再同时调整 Companion Voice 或 WindowManager。这样输出风格、系统触摸和长期内核三类回归可以分别归因。

### 11C. v0.31.2 全新实现状态

- 已实现默认 OFF 开关、尾部协议、严格解析、Agent 污染检查、普通聊天一次纠正、proactive 与 Grounding 共享一次纠正预算、WAIT/block、schema v19 迁移、独立持久化、UI 标签、TTS 路由与脱敏诊断。
- OFF 分支不调用协议解析器、不追加协议；ON 分支在完整解析前不把 content delta 交给 UI/TTS，避免标签和污染文本闪现。
- 本地已通过新 v0.31.2 validator、Dart tree-sitter 语法解析、Desire 5000 tick 数值长跑、TTS A2 黄金哈希/队列、durable generation、recovery、memory、awareness、relationship、proactive rhythm、daily continuity 与 transfer SQLite 回归。
- 本地缺 Flutter/Android SDK，`flutter analyze / flutter test / release APK` 必须由配套 GitHub Actions 完成；Actions 通过前状态仍是“源码候选”，不是已验收 APK。
- 配套 source-update patch、schema v19 SQLite validator 与完整替换 workflow 已生成；patch 已在新解压的 v0.31.1+41 基线上完成 `git apply --check`、实际 apply、文件树一致性与新 validator round-trip。最终待用户上传并运行 Actions。
