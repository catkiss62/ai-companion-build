# AI Companion · HANDOFF

> 每个正式版本都要同步更新本文件，并核对 `docs/PROJECT_TASK_LEDGER.md`。新窗口优先读取这两个文件，再读 `README.md` / `docs/DEV_STATUS.md` 和实际源码；不要从旧聊天记录猜当前实现。

## 1. 当前基底

- 当前源码候选：**v0.31.0+40 · Grounded Desire Core**。
- Android 真机：REDMI K80 Ultra，Android 15，Xiaomi/HyperOS。
- 数据库：**schema v18**，v0.31.0 无 schema migration；Desire 新字段继续存现有 JSON snapshot。
- GitHub：完整 Flutter 项目位于仓库 `app/`，它是 single source of truth；不恢复历史 v0.28 五分包 + patch 链。
- 最近已知 Overlay 真机结果：v0.30.2 曾出现 `selfHealCount=28 / coverRecoveryCount=11`；v0.30.3 仍可稳定复现“进入系统文件选择器/上传文件后，返回时悬浮球可见但 input channel 卡死，打开 AI Companion 后恢复”。用户确认除此之外暂无重大 Overlay 故障，因此 **悬浮球任务冻结**。

## 2. 项目定位

这是长期本地优先的**女性 AI 伴侣 / AI 女友**，不是角色卡聊天器、小说生成器或一次性 RP。她知道自己是 AI，可以自然打破第四面墙；RP/Intimacy 是会话能力，不覆盖 AI Self。

固定原则：

- 手机/平板同一时间只有一台 **Active Brain**；接管后旧设备 standby，不删本地数据。
- 聊天、Memory、Relationship、Thought/Desire、Awareness、Daily Continuity 等主要状态在本地 SQLite。
- DeepSeek `reasoning_content` 与正文独立保存/显示。
- Reference 是低优先级参考，不能把 AI 本体变成角色卡。
- Raw package name、通知正文、Accessibility 正文不进入长期 prompt / Thought / 脱敏诊断；先本地粗粒度化。
- 主动联系 hard caps 保持 **2/2h、8/24h**；busy 是 soft friction，不是绝对静音。

## 2A. 关键历史基线（压缩）

- **v0.29.0 Clean Baseline**：GitHub `app/` 完整源码独立构建、真机安装、Meju A2 generation-ahead 通过。
- **v0.29.1 UI/TTS Polish**：reasoning 在正文上方、悬浮球尺寸/角标/最近 8 条历史等 UI 完成；随后暴露 background Dart command server 不可达问题。
- **v0.30.0 Background Presence**：修复 root entrypoint/AOT reachability 与 ready race，建立 `signal:*` reactive wake。
- v0.30.1~0.30.3 主要围绕 HyperOS Overlay touch/recovery；最终 file-picker 路径仍作为 Frozen 已知问题。

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

- `database.grounding`：localDate/localTime/UTC offset/daypart、conversationState、pending/answered、user/assistant silence ages、proactive count，以及 proactive factual guard 的 block count/last reason；**没有 message id/body**。
- `database.desireCore`：8 Drive、baselines、refractoryMinutes、last intent/satisfy、fatigue gate、selected/top candidates（只含 drive/action/score/source class，不含 Thought 正文/reason）、Thought provenance 计数。
- `backgroundPresence.lastGateBreakdown` 保留，v0.31 可看到 Presence 已进入 Desire 而不是重复 Gate boost。
- “她的内心”调试页显示 Reality Grounding 与 top Desire candidates，便于强制 proactive 做事实边界回归。

## 7. Overlay / 悬浮球 · FROZEN

- v0.30.1/0.30.2/0.30.3 已做过多轮 WindowManager input recovery；旧 `overlayTouch` 脱敏诊断仍保留。
- HyperOS/Android 15 的系统文件选择器/上传文件路径仍可稳定让悬浮球返回后可见但不可触摸；打开主 AI Companion 后恢复。
- 用户确认目前除这个路径外没有其它重大悬浮球 bug，因此 **不再单独检查/开版本修 Overlay**。
- 后续主线如果顺手触及 WindowManager/Activity lifecycle，可以做低风险修补；核心逻辑/长后台稳定后再做 OEM compatibility pass。

## 8. TTS 黄金基准 · FROZEN / GUARDRAIL

行为参考 APK：`MejuTTS_A2_OriginalNative_v2.5.apk`。

- 原始 `libbertvits2.so` ELF 635,352 bytes，SHA-256 `a1ca5180532aae3a7c378371f6ddb44bbf35d8826a8b8750db4fd12179c5551b`；APK padded 到 710,848 bytes。
- `Yuki -> 有希` 只改朗读文本。
- 只按 `。！？；.!?;` 分句；不按逗号/换行/字符数切。
- A2 generation-ahead + FIFO + ready WAV 约 200ms gap。
- 不重做 native/MNN/threading/WAV concat/cache；轻微节奏问题非阻断。

## 9. 后续重要任务（不可遗忘）

长期任务真源：`docs/PROJECT_TASK_LEDGER.md`。

P0 / v0.31.x：Grounded Desire Core 收尾与真机数据调优。

P1：

- HyperOS / Android 15 长后台：锁屏、划掉 App、数小时 idle、process recreation、boot/package replaced；完整 Activity destroy 后 durable generation 仍可恢复。
- 50/100/数百轮长期 Memory/Thought/summary/thread 压力测试。
- 手机/平板 Active Brain 真机双向 takeover + Nearby + encrypted `.aicomp` fallback。

P2：

- Grounded Desire 真机数据后的 proactive 二次调优。
- Intimacy/NSFW Session 与 libido 深度融合，但普通聊天不自动色情化。
- 隐私/安全/可靠性审计。
- Clean Freeze、删除临时 patch/apply workflow、正式 release signing、升级/备份/崩溃恢复。

## 10. v0.31.0 真机验收重点

1. 当前时间/daypart 是否与手机一致。
2. `你好 -> AI 回复 -> 用户沉默 -> 她的内心/测试主动找我`：proactive 必须是新开口，不能重复回答“你好”。
3. 用户继续沉默再强制 proactive：不能虚构“你刚才说了 X”。
4. 正常用手机 5~15 分钟后直接导出浅层诊断，不跑深度自检；检查 `grounding / desireCore / lastGateBreakdown`。
5. 主聊天、reasoning/body 顺序、TTS、Active Brain 无明显回归。Overlay 已知 file-picker freeze 不判 v0.31 失败。

## 11. GitHub / 开发流程

- `app/` 是源码真源。
- 普通小版本：一次性 source-update patch -> 手动 Apply workflow -> validators -> Flutter analyze/test -> release APK -> 自动 commit `app/`；无需每个小版立刻 Clean。
- 临时 patch 可留 2~3 个小版本；阶段性稳定点再 Clean Freeze 并统一删除。
- 测试 APK 使用固定测试签名，可覆盖安装；正式发布再换私有签名。
- 用户非技术开发者：优先由助手做静态/自动回归，只有真机行为必须确认时才交 APK。
- 每个正式版本更新本 HANDOFF；大阶段保留完整 source ZIP + SHA-256。
