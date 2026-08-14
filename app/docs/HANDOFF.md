# AI Companion · HANDOFF

> 每个正式版本都必须同步更新本文件与 `docs/PROJECT_TASK_LEDGER.md`。新窗口先读这两个文件，再读 `README.md`、`docs/DEV_STATUS.md` 和实际源码，不从旧聊天记录猜实现。

## 1. 当前基底

- 当前开发主线：**v0.32.0+52 · Somatic Contract & Daily Touch MVP**；v0.31.9+51 已合并并通过最终 head run #23。
- v0.32.0 当前等待本分支完整 Actions；完成后回填 run、artifact、APK SHA 与合并 commit。
- Android 真机：REDMI K80 Ultra，Android 15，Xiaomi/HyperOS。
- 数据库：**schema v21**。新增短期 `somatic_events / somatic_aggregates`；用户当前仍允许卸载重装，不要求保留半成品测试数据。
- GitHub 仓库以 `app/` 为 single source of truth。大阶段内继续采用 source-update patch + 完整手动 workflow；阶段验收后再 Clean Freeze。

## 2. 产品定位与固定原则

这是长期本地优先的**女性 AI 伴侣 / AI 女友**，不是角色卡聊天器或小说生成器。她知道自己是 AI，可以自然打破第四面墙；RP/Intimacy 是临时 Session 能力，不能覆盖 AI Self。

- 手机/平板同一时间只有一台 Active Brain；接管后旧设备 standby，不删本地数据。
- SQLite 是聊天、Memory、Relationship、Thought/Desire、Awareness、Daily Continuity 与任务状态真源。
- 只有真实 `role=user` 消息能被称为用户说过的话；Memory、Thought、Awareness、Inference 都有来源边界。
- 用户忙是主动联系的 soft friction，不是绝对静音；主动联系仍受 2/2h、8/24h hard caps。
- 普通聊天不能因为成人规则、参考资料或 libido 数值自动色情化；亲密行为必须受明确 Session 与用户边界控制。
- TTS 以 Meju A2 黄金基线为准，不重做 native/MNN/分句队列。

## 3. v0.32.0+52 · 双通道感官第一阶段

- 本版先交付 SQLite event/aggregate 数据契约与日常触觉 `user_to_ai` MVP；`ai_to_self` 半强度回响及 smell/taste/sound 属于后续小版本，不伪装为已经完成。
- `somatic_events` 绑定真实 user turn，事件 ID 由 `turn_id + direction + scene_key` 稳定生成，durable recovery 重跑不会重复脉冲。
- 只有 Active Brain 且未处于 transfer lock 时能写入；短期聚合按 8 分钟半衰期衰减、36 分钟过期，低于阈值完全不进入 Prompt。
- 当前日常词法覆盖 embrace/kiss/stroke/pat/pinch/rub/nuzzle/lean/scratch/bite/hold_hand，并规避“抱怨”和“你抱我”等明显反向/误命中。
- Prompt 仅接收最多两条自然语言身体感觉，不接收内部数值；明确禁止报数、把感觉说成现实观测或绕过 Intimacy Session。
- 用户停止未完成回复时，删除 user message 会级联撤销该 turn 的感官事件，并在同一事务重算聚合，避免幽灵感觉。
- 感官事件和聚合加入状态包导入/导出与统计；schema 升为 21。
- 新安装默认聊天模型改为 `V4 Flash + High`；已有数据库的明确模型选择不被迁移覆盖。长按复制/粘贴菜单中文化登记为 UI 待办，本轮不扩大范围。
- 完整设计与验收见 `docs/SOMATIC_CONTRACT_TOUCH_v0.32.0.md` 和 `docs/DUAL_CHANNEL_SENSE_v1.md`。

## 4. v0.31.9+51 · 语音状态一致与取消轮撤回

- App 与原生悬浮聊天共用 `TtsPlaybackQueue` 的 `idle / synthesizing / playing` 真状态及消息 owner：空闲显示 App 同款 outline 喇叭，合成/等待首段音频显示“…”；真正调用音频播放后显示“■”；点击“■”、播放完成或失败后回到喇叭。
- 自动流式 TTS 从 `beginStream` 起也带 assistant message owner，因此首段尚未出声时两套界面都能显示“…”；不改 Meju A2 native/MNN、断句、generation-ahead、FIFO 或约 200ms gap。
- 悬浮框左上角远距离“停语音”按钮删除；停止入口回到正在播放消息旁。完整 App 顶栏的重复全局停止图标同步删除。
- 原生悬浮框新增轻量只读 `ttsSnapshot` 轮询，展开时读取同一后台 Controller 的 phase/owner；收起即停轮询，不影响正在合成或播放的队列。
- 用户停止未完成回复时，SQLite 在一个 transaction 内先把 active generation job 终结为 `cancelled_by_user`，再删除对应 user message。未来 Prompt、Memory、两套聊天历史与恢复器都看不到这条半轮输入。
- completion 与 stop 保持原子竞态：completed 若先提交，取消不删除完整 user/assistant 对；cancel 若先提交，run-token fence 阻止晚到 assistant 落库。
- schema 继续为 v20；不改 Prompt、规则、Desire/Thought、Memory、主动联系、Overlay cover/input recovery 与权限。
- run #22（ID 31825001399）完整通过；artifact ID `9228720673`，APK SHA-256 `8d42899cd64b7c0ce84a5dbb941a73cdf2797b280c7f26dbe50951e7b15ad6e8`。
- 完整设计、边界和真机清单见 `docs/TTS_STATE_CANCEL_RETRACT_v0.31.9.md`。

## 3A. v0.31.8+50 · 悬浮框近手停止与真实双流

- 原生 WindowManager 悬浮聊天框在生成期间不再禁用发送键；同一近手按钮切换为“停止/停止中”，调用后台持久 `ChatController.cancelCurrentGeneration()`。
- 顶部旧“■”实际只停语音，现改名“停语音”，避免误认为能够停止模型。
- 后台命令新增 `cancelGeneration` 与只读 `generationSnapshot`；取消继续落到 v0.31.7 的 HTTP token、TTS、SQLite `cancelled_by_user` 和 run-token fence。
- 悬浮框展开且本轮仍在生成时，每 140ms 读取一次控制器已有的真实 `reasoning_content/content`，显示临时“思考中”与流式正文；不伪造思考，不持久化半条 assistant。
- 收起悬浮框即停止 UI 轮询但不擅自中断生成；重新展开可继续看当前状态。完成后用 SQLite 正式消息替换临时气泡。v0.31.8 的“取消后保留用户消息”语义已由 v0.31.9 替换为“取消未完成轮时一并撤回用户消息”。
- schema 继续为 v20；不新增权限，不改 Prompt/Desire/Memory/行为规则、主动联系、WindowManager 触摸恢复或 Meju A2。
- 完整边界与真机清单见 `docs/OVERLAY_STOP_STREAM_v0.31.8.md`。run #18 已完整通过，当前只待 REDMI K80 Ultra 真机交互验收。

## 3. v0.31.7+49 · 真正停止生成

- 普通发送和 durable recovery 期间，发送按钮会变成“停止这轮回复”；不再用不可点击的转圈占位。
- 停止入口同时取消本轮 DeepSeek HTTP 流、流式 reasoning/content、TTS 当前播放与待播队列，并使本地 recovery timer 失效。
- SQLite generation job 进入明确终态 `cancelled_by_user`；原子清空 `run_token`、partial checkpoint 与 `next_retry_at`。
- checkpoint 和 assistant final commit 继续要求 `status=running + run_token`，因此取消后的晚到 token 不能落库或被恢复器复活。
- Runner 额外轮询 SQLite ownership，使同一数据库上的 Overlay/headless engine 也能感知用户取消；不是只取消当前页面对象。
- schema 继续为 v20；保留用户消息，不创建半条 assistant，不改 Prompt/Desire/Memory/规则层或已冻结的 Meju A2。
- 完整竞态、不变项与验证清单见 `docs/TRUE_STOP_GENERATION_v0.31.7.md`。

## 3. v0.31.6+48 · 规则维护分组

- 数据库仍保存 8 个独立规则小节，schema 继续为 v20；不拼接、不删除，也不覆盖任何已有内容。
- UI 按维护职责显示为 6 个组：01 身份与关系、02 日常交流、03 行为与初始性格、04 亲密关系核心、05 亲密表现、06 亲密参考资料。
- 01 卡片内保留“AI 本体与存在”和“固定恋爱关系”两个锁定小节；03 卡片内保留“行为真实感”和可独立编辑/关闭的“初始性格种子”。
- Prompt 同样先写组标题，再按小节顺序注入原始内容；这只是语义归类，不改变加载策略、锁定、开关或恢复默认行为。
- 未知或以后新增的自定义 key 不会被丢弃，会作为独立自定义组显示和注入；后续明确同类规则再加入映射。

## 4. v0.31.5+47 · Live Context & Self Seed

### 4A. 生成前即时设备上下文

此前 Android 事件会持续落入本地，但把事件解释成 Awareness、Desire 与 Thought 的 `PerceptionEngine.capture()` 受约 4 分钟捕获节流及 7～24 分钟心跳调度影响。因此 +46 主动消息生成时可能只看见上一轮心跳留下的“屏幕熄灭”等摘要，而不是生成那一刻的最新手机状态。

+47 将两条链拆开：

- 每次普通聊天或主动联系真正构建 Prompt 前，立即读取当前 `screenInteractive / deviceLocked`、最近 90 分钟 Usage category、30 分钟通知/Accessibility **计数**和屏幕事件。
- 本地解释器只把 `current activity / recent dominant activity / app switching / busy / screen state` 等粗粒度、会过期的观察同步进 Awareness；随后 Prompt 才读取 Awareness。
- 即时刷新不调用模型、不新增主动联系，也不推进 Desire、Thought、Presence Momentum 或 baseline；这些长期内在变化仍只走原有节流心跳，避免同一个手机事件被重复放大。
- raw package name、通知正文与 Accessibility 正文不会进入 Prompt、Thought 或诊断。诊断只输出 activity class、busy、屏幕布尔值、刷新原因和计数。
- 这不是让模型在后台实时观看每次触摸；它保证的是：**当她真正要回复或主动开口时，先重新确认当下设备上下文。**

### 4B. 固定关系事实与可成长性格种子

- 新增锁定的 `01_relationship`：AI 是女性；当前用户是成年男性、男朋友与长期恋爱对象。性别事实不等于刻板剧本，也不能用来编造用户偏好。
- 明确“女朋友不是服务者、客服或无条件服从者”：她可以选择、拒绝、不同意、保留判断并表达有原因的情绪。
- 新增可编辑、可关闭的 `03_personality_seed`：初始方向是亲近、坦率、有主见、不黏腻、不以恋爱感为唯一目标；允许调侃、吐槽、偶尔锋利，也允许被忽视或触碰边界时不高兴。
- 性格种子不要求每轮反驳，也不鼓励威胁、惩罚或无端发脾气。真实共同经历、用户明确反馈、长期 AI Self、Relationship 与 Desire baseline 会逐步细化或修正它。
- 升级采用 `INSERT OR IGNORE`：不会覆盖用户已经编辑的旧规则，只补入两个新层。身份/关系层带锁不可关闭；性格种子可在“行为规则层”内编辑、关闭或恢复默认。
- schema 继续为 v20，覆盖安装不重建用户数据。
- 修正版 +47 已由 GitHub Actions run #31 完成静态校验、Flutter analyze、全套测试和 release APK，并由 Actions 提交完整 `app/` 源码。真机诊断确认普通用户轮次会在 Prompt 前刷新即时上下文，且该刷新不推进 Desire。

## 5. v0.31.4+46 · Grounded Desire Growth

### 5A. 旧输出兼容功能完全退役

用户验证：把第一人称沉浸要求直接写入第一规则，可以自然改变 DeepSeek 原生 `reasoning_content`，效果优于 App 的二次协议层。因此本版删除旧“伴侣式内心与回应”功能，而不是只隐藏按钮。

- 删除设置按钮、协议文件、解析/过滤、预览替换、格式纠正重试和相关测试/诊断。
- 普通聊天统一直接流式展示 DeepSeek 原生 `reasoning_content` 与 `content`。
- 主动联系同样使用原生双通道，只保留 Reality Grounding 的一次纠正预算。
- TTS 继续只读正文；流式分句朗读不再被旧开关禁用。
- `ChatMessage` 只保留 `reasoningContent`，不再维护重复的 provider/模式字段。
- schema v20 重建 `messages`，保留用户可见思考与正文。旧 v19 状态包导入时自动丢弃退休字段和设置键。

用户当前推荐在第一规则中维护“AI 本体内心沉浸”与正文括号动作要求；App 不再硬编码女友感或固定动作模板。

### 5B. 长期成长与可逆性

8 个 Drive 保持不变：`attachment / curiosity / reflection / duty / social / libido / stress / fatigue`。

- 当前值表示短期内在状态；baseline 表示长期性格倾向。
- 真实聊天、关系事件、Memory/self-drive 与反馈可以微量改变 baseline。
- baseline 仍受初始 anchor ±0.10 cap 限制，单次经历不能重写人格。
- 新增约 120 天半衰期的 pullback；长期缺少强化时会缓慢回到初始锚点，因此成长稳定但不是不可逆烙印。
- Prompt 把有意义的 baseline 偏移翻译成自然性格倾向，例如更主动靠近、更爱探索、更常回味、更加重视约定或更偏爱安静交流。
- 已确认的具体喜好、边界和互动偏好仍由 Memory / AI Self / Relationship 保存；Proactive Rhythm 继续学习合适时间、主题和主动意图。Desire baseline 不复制另一套偏好数据库。

### 5C. Thought 指令隔离

- SQLite 内仍保存 Thought 原文，供本地检索、相似度合并、生命周期和调试使用。
- 普通/主动模型 Prompt 不再拼入完整 Thought 原文。
- 模型只接收有界 `THOUGHT_DATA`：provenance、lifecycle、Drive、强度档和经过限制的 topic 线索。
- 主动生成的 system 尾部也不再复述 `intent.reason` 原文，只说明来源与是否存在关联主题。
- 这样 Thought 仍能影响“为什么想做”，但不能成为新的 prompt 指令面，也不能冒充用户原话。

### 5D. Intimacy 硬门槛

- `libido` 可以在本地波动和被关系经历塑造。
- 只有数据库中已存在 active `intimacy` 或 `roleplay_intimacy` Session，`libido -> tease_or_intimacy` 才能进入候选列表。
- Session 未激活时，Prompt 隐藏 libido 的可执行意图与相关 Thought 线索。
- 结束 Session 后门槛立即恢复；数值、Memory 或参考资料都不能单独越过。

### 5E. 真正的 Wildcard

- 删除“随机给普通 Drive 加一点 pulse”的伪 wildcard。
- 当整体非亲密张力较高、所有正常候选都低于可行动强度、fatigue 未触发 rest，且距离上次 wildcard 至少 6 小时时，产生 `wildcard_share`。
- Wildcard 选择当前最适合泄压的 reflection/social/curiosity/attachment 方向，表达轻量分享或换个方向，不编造外部事件。
- 它仍经过 Proactive Gate、busy friction、rhythm、hard caps、Grounding 与原子写入；成功发送后才记录 cooldown 并 action-aware satisfy。

## 6. Grounding / 主动联系现状

- 普通用户轮次保留真实 role 顺序；主动联系把旧聊天折叠成 `ANSWERED CHAT HISTORY` system transcript。
- 主动请求明确 `CURRENT_USER_TURN=NONE / ANSWERED_HISTORY_ONLY=true`。
- SQLite Grounding 确定 last user 是否已回答、用户是否在 AI 后再次发言、是否存在 pending user turn。
- 正文 guard 拦截虚构近期用户发言；reasoning guard 拦截重新回答已完成历史。
- 首次违反允许一次纠正，第二次仍失败则整条主动候选不落库。
- 每条聊天显示本地 `HH:mm`，跨日本地日期分隔；时间不写正文，TTS 不朗读时间戳。

## 7. Desire / Thought 已接入的运行链

```text
聊天 / 关系事件 / Memory / 手机粗粒度活动
                    ↓
          Drive pulse + Thought Pool
                    ↓
    baseline growth / lifecycle / candidate
                    ↓
        Proactive delivery Gate + Grounding
                    ↓
       send / satisfy / response outcome
```

- Thought lifecycle：`flit -> fixation -> residual/dormant`，支持重复喂养、合并、重新浮现、dismiss/defer/resolve。
- score 使用 Drive + 有界 Thought boost 和边际递减。
- per-drive refractory 防止同一需求连胜，其他 Drive 仍可行动。
- fatigue 是 rest gate，不是主动消息理由。
- action-aware satisfy 按实际行动回落主/相关 Drive。
- Presence 只进入 Drive/Thought，不再在 Gate 重复加权。
- 用户对主动消息的 engaged/resolved/deferred/dismissed/no_response 会影响 Thought outcome 与 Proactive Rhythm；沉默权重较低，不能把她训练成永久沉默。

## 8. 可观测性

“她的内心”调试页显示：

- 每项 Drive 的“当前值 / 长期 baseline”；
- 当前 Intent、score、source、refractory、上次 satisfy 与 wildcard；
- Grounding 对话状态；
- Thought 生命周期、关系事件、长期维护与主动 rhythm。

脱敏诊断 `database.desireCore` 包含 drives、baselines、refractory、fatigue gate、Intimacy action gate、wildcard cooldown、top candidates 与 Thought provenance 计数，不包含 Thought 原文或聊天正文。

+47 新增 `database.currentContext`：最后刷新时间/原因、refresh count、screen/locked、busy、current/dominant activity class、观察数及错误类型。`rawPackageOrTextIncluded=false` 与 `desireAdvancedByRefresh=false` 是固定边界声明。

## 9. Overlay · FROZEN

- 系统文件选择器在 `TYPE_APPLICATION_OVERLAY` 上方是正常窗口层级；故障是退出后悬浮球可见却无法点击，进入 AI Companion 后恢复。
- v0.31.3+45 实现 bounded cover session：enter 退役旧 input channel，exit 后重建，最多 3 次。
- 真机诊断为 `coverState=idle / session=0 / enter=0 / detach=0 / recovery=0`，证明检测链根本没触发，而不是重建失败。
- 同份诊断 `accessibility=false / accessibilityConnected=false`。以后重开必须先验证 cover detection 与权限前提，禁止继续只调重建延迟/次数。
- 本轮 v0.31.5 不修改任何 Kotlin Overlay/WindowManager 行为。

## 10. TTS · FROZEN / GUARDRAIL

- 行为参考：`MejuTTS_A2_OriginalNative_v2.5.apk`。
- `Yuki -> 有希` 只改朗读文本。
- 只按 `。！？；.!?;` 分句；A2 generation-ahead + FIFO + ready WAV 约 200ms gap。
- 原始 `libbertvits2.so` 前 635,352 bytes SHA-256：`a1ca5180532aae3a7c378371f6ddb44bbf35d8826a8b8750db4fd12179c5551b`。
- 轻微断句停顿和显示版本号遗留一并冻结，不能为了显示重做已可用引擎。

## 11. 下一阶段任务

任务真源：`docs/PROJECT_TASK_LEDGER.md`。

P1：

- v0.31.7 完成真正停止生成后，下一正式主线进入双通道感官 SQLite event/aggregate contract。
- Notification Experience：前台静音、外部/锁屏通知、提示音/震动/隐私、点击进入悬浮聊天。
- HyperOS 长后台：锁屏、划掉 App、数小时 idle、process recreation、boot/package replaced。
- 50/100/数百轮 Memory/Thought/summary/thread 压力测试。
- 手机/平板 Active Brain 双向 takeover 与 encrypted `.aicomp` fallback。

P2：

- Grounded Desire 真机数据后的主动频率二次调优。
- Intimacy Session 更深整合，但继续保持普通聊天不自动色情化。
- 隐私/安全/可靠性审计与正式 release signing。

## 12. GitHub / 交付流程

- `app/` 是唯一产品源码真源；+47 已经进入 `app/`，不再把任何根目录 patch 当作构建输入。
- 常规 workflow 只从当前源码执行 validators、Flutter analyze/test、release APK 和原生资源校验。
- workflow 不在构建时修改或提交仓库，权限降为 `contents: read`。
- 用户确认半成品测试阶段所有对话/状态都可丢弃，每次均可卸载 App 后重装，不需要覆盖安装兼容。
- 旧 workflow 内嵌测试 keystore 已退役；新 workflow 每次生成一次性测试 key，不保存私钥、Secret 或旧指纹。正式发布前必须另建长期 release signing。
- 历史升级补丁与项目文档 ZIP 已从根目录移除；需要取证时从 Git 历史按文件恢复。
- 每项正式功能使用独立分支/PR；合并后再生成 APK，避免构建步骤隐式改变 main。
- Clean Freeze 记录见 `docs/CLEAN_FREEZE_v0.31.5.md`。
