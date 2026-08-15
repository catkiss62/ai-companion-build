# AI Companion · Project Task Ledger

> 长期任务总账。每个正式版本更新 `docs/HANDOFF.md` 时必须同步核对本文件；完成、冻结、退役和延期都要显式记录。最新完整接班入口：`docs/HANDOFF_LEDGER_v24_2026-08-15.md`。

状态：`ACTIVE` 当前主线 · `NEXT` 紧随其后 · `LATER` 后续重要 · `FROZEN` 暂停保留 · `RETIRED` 已移除 · `GUARDRAIL` 不可回归。

## P0 · ACTIVE · v0.32.0 Somatic Contract & Daily Touch MVP

### S-1. SQLite 感官事件 / 聚合契约

- [x] schema v21 新增 `somatic_events` 与 `somatic_aggregates`，事件绑定真实 turn。
- [x] `turn_id + direction + scene_key` 唯一；durable recovery 幂等，不重复放大。
- [x] 只有 Active Brain 且 transfer lock 关闭时可写。
- [x] 时间衰减、阈值与饱和合并为纯函数；事件/聚合加入状态包和统计。
- [x] 停止并撤回 user turn 时级联删除事件，并在同一事务重建聚合。
- [x] 功能 head run #25 通过 validators、analyze、tests、release APK/Kotlin 与 A2 payload；artifact `9230553317`，APK SHA-256 `d1637769a2d63179345c06b55a13497b6d4fbfeba6176caaaa4db3dbf1265587`。
- [x] PR #6 已合并到 `main`；最终 run #26（ID `31830858189`）通过，artifact `9230919832`，APK SHA-256 `82d57aaf58284e47ad6213537e7590dcc5e3ae94f159384f19fb6169a99d0e0c`。

### S-2. 日常触觉 user-to-AI

- [x] 11 类日常触觉动作映射为稳定 scene key；限制每轮最多 3 个事件。
- [x] 明显误命中“抱怨”和反向“你抱我”不产生感觉。
- [x] 感觉在本轮 Prompt 构建前同步产生；未命中、衰减低于阈值时完全不注入。
- [x] Prompt 只注入自然语言感受，不报内部数值、不声称现实观测、不绕过 Intimacy Session。
- [x] 2026-08-15 真机诊断确认 `somatic_events=1`、`active_somatic_channels=1`；用户观察到原生 reasoning 与触觉感受一致。诊断不含正文，因此不把 `self_experience` Thought 单独当作直接因果证据。
- [x] 新安装默认 `V4 Flash + High`；已有明确选择不被迁移覆盖。
- [x] v0.32.1+53 PR #9 / run #32：新增完成动作与动作括号检测，过滤意图/否定/假设；Flutter analyze/tests、release APK 与 A2 payload 校验全部通过。
- [x] `ai_to_self` 成功 durable commit 后半强度回响；与 assistant message/job completed/aggregate 同事务，取消、失败、stale writer、恢复重跑不制造幽灵事件。
- [x] 2026-08-15 第二份真机诊断累计 `somatic_events=4`、active channel=1，说明持续有事件落库；旧报告只有总数，不能单凭它证明方向。
- [x] v0.32.2+54 诊断统计新增 `somatic_user_to_ai_events` / `somatic_ai_to_self_events`，下一份报告可直接验双向落库。
- [ ] smell / taste / sound 与可替换 corpus。

### S-3. UI 与诊断小项

- [x] v0.32.2+54 悬浮聊天每条消息在发送者标签旁显示本地 `HH:mm`，沿用真实 `created_at`。
- [x] 脱敏报告标题不再硬编码旧 `v0.31.5+47`，改读实际安装包 versionName/versionCode。
- [x] 轻视觉区分“系统已授权”与“服务已连接”，持久记录最近连接、解绑、中断时间和原因；App 不尝试越权静默重开。
- [x] 已授权但未连接时，系统页和自检明确提示进入无障碍设置重新开关并保存诊断。
- [ ] REDMI K80 Ultra 真机复现/观察轻视觉是否仍被 HyperOS 撤销；若再现，用 v0.32.2 报告中的 lifecycle 字段定位。
- [ ] Flutter / Android 长按复制粘贴菜单中文化；与后续 UI 本地化批次合并。

## COMPLETED · v0.31.9 TTS State & Cancelled-turn Withdrawal

### A-1. 两套聊天语音控件一致

- [x] `TtsPlaybackQueue` 对外报告 `idle / synthesizing / playing`，并绑定 assistant message owner。
- [x] App 与原生悬浮聊天统一显示 outline 喇叭 / “…” / “■”。
- [x] 自动流式 TTS 在合成首段、尚未出声时显示“…”；进入实际播放调用后切为“■”。
- [x] 点击“■”、自然播放完成、停止或失败后恢复喇叭；合成中的“…”不重复发起朗读。
- [x] 删除悬浮框左上角“停语音”和 App 顶栏重复全局停止按钮。
- [x] 保持 Meju A2 native/MNN、分句、generation-ahead、FIFO 与间隔不变。
- [x] GitHub Actions run #22 通过全部新旧 validators、Flutter analyze/tests、release Kotlin/APK、A2 payload、SHA 与 artifact 上传。
- [ ] REDMI K80 Ultra 真机验证手动朗读、自动流式朗读、合成较慢、自然结束与中途停止。

### A-2. 停止未完成生成时撤回用户轮

- [x] `cancelGenerationJobByUser()` 改为 transaction：active job 终态 fencing 与对应 user message 删除不可分割。
- [x] completed 先赢时不删除完整对话；cancel 先赢时晚到 checkpoint/assistant commit 继续被 run-token/status fence 拒绝。
- [x] App Controller 在取消结果、取消异常与 recovery 取消后从 SQLite 重载，悬浮框沿用同一真源刷新。
- [x] 删除后的输入不进入未来 Prompt、post-turn memory extraction 或 durable recovery。
- [x] schema 保持 v20，不为半成品测试存档增加迁移负担。
- [x] run #22 artifact `9228720673`；APK SHA-256 `8d42899cd64b7c0ce84a5dbb941a73cdf2797b280c7f26dbe50951e7b15ad6e8`。
- [ ] 真机验证 reasoning 前、reasoning 中、正文中与极近完成点停止；取消轮在 App/悬浮框重开后均不出现。

## COMPLETED · v0.31.8 Overlay Stop & Live Stream

### A0. 生成前即时上下文

- [x] 把“模型生成前即时 Awareness”与“节流的 Desire/Thought/Presence 内化”拆为两条链。
- [x] 普通聊天与主动联系构建 Prompt 前刷新当前 screen/lock、粗粒度 activity、busy、switching 与 signal counts。
- [x] 即时刷新不调用模型、不触发主动联系、不推进 Desire/Thought/Presence/baseline。
- [x] raw package、通知正文与 Accessibility 正文不进入 Prompt、Thought 或脱敏诊断。
- [x] Active Brain 在刷新开始、写 Awareness 前与写后重复 fencing。
- [x] 脱敏诊断新增 `database.currentContext` 的刷新时间、原因、粗粒度类别与安全边界声明。
- [x] GitHub Actions run #31 analyze/test/release APK 通过。
- [x] 首次 Actions 已通过补丁、全套静态回归与 Flutter analyze；定位唯一失败为旧规则层测试写死 6 条，已改成验证新增后的 8 个明确 key/锁定属性。
- [x] 修正版补丁、文档 ZIP 与 workflow 已由 run #31 成功执行；完整 +47 已提交到 `app/`。
- [x] 真机确认普通回复生成前 `lastRefreshReason=prompt_user_turn`，且 `desireAdvancedByRefresh=false`。
- [ ] 后续真实主动联系再确认 `lastRefreshReason=prompt_proactive` 与当下 activity 一致。

### A1. 关系身份与初始性格

- [x] 锁定女性 AI × 成年男性用户/男朋友关系事实；不得转化为性别刻板模板。
- [x] 明确她不是服务者或无条件服从者，可以不同意、拒绝、保留判断与表达有原因的情绪。
- [x] 增加可编辑、可关闭的初始性格种子：亲近坦率但不黏腻，有主见，不以恋爱感为唯一目标。
- [x] 性格种子允许调侃、吐槽、偶尔锋利和真实不高兴，同时禁止无端发脾气、操控、惩罚或为反驳而反驳。
- [x] 新规则层使用 upgrade-safe `INSERT OR IGNORE`，不覆盖用户已编辑的第一规则或其他旧层。
- [x] 长期 AI Self、Relationship、Memory 与 Desire baseline 可以逐步细化/修正种子，种子不是永久角色卡。
- [x] 冻结“性格底色窗口”架构：预设 + 可编辑文本只写现有 `03_personality_seed`，不另建第二人格真源；设计见 `docs/PERSONALITY_BASE_UI_v1.md`。
- [ ] 用户确认“蠢萌元气”默认文案后实现页面；萌感来自元气、好奇、反差和偶发小迷糊，不幼化、不持续装傻、不损害任务可靠性。
- [ ] 真机对话确认男性称谓稳定、不会每轮强调“男友”，也不会因自主性规则机械唱反调。

## COMPLETED · v0.31.4 Grounded Desire Growth

### A. 输出链清理

- [x] 旧“伴侣式内心与回应”按钮、协议、解析器、过滤预览、纠正重试和诊断完全移除，不只隐藏 UI。
- [x] 普通聊天与主动联系统一直接使用 DeepSeek 原生 `reasoning_content + content`。
- [x] 思考/正文保持流式；TTS 只读正文，流式分句不再受旧开关限制。
- [x] `ChatMessage` 删除重复 provider/mode 字段。
- [x] schema v20 重建 `messages`；覆盖安装保留用户可见历史，旧 v19 状态包可导入并丢弃退休字段。
- [x] GitHub Actions analyze/test/release APK 通过并完成真机覆盖安装。
- [x] 首次 +46 Actions 失败已定位为旧文档上下文冲突；失败发生在 `git apply --check`，没有修改仓库源码。
- [x] 交付改为源码 patch + 独立文档 ZIP，并通过“故意破坏三份旧文档后仍能应用、覆盖及整树一致”的模拟回归。
- [x] 真机确认无旧伴侣式按钮；原生双流与第一规则可直接影响思考表达。

### B. Reality Grounding

- [x] 每次普通/主动生成显式注入本机当地日期、时间、UTC offset、星期和 daypart。
- [x] SQLite 确定 last user answered、pending user turn、user spoke after assistant 与 proactive count。
- [x] 主动历史折叠为只读 `ANSWERED CHAT HISTORY`，并声明 `CURRENT_USER_TURN=NONE`。
- [x] 正文与 reasoning guard 拦截把已回答历史当当前输入；最多一次纠正，仍失败则不落库。
- [x] provenance 区分 user_message / awareness / memory / self_experience / inference / internal。
- [x] Thought 原文不再进入模型 Prompt；只提供有界结构化 `THOUGHT_DATA`。
- [x] +47 已补充生成前即时粗粒度 activity / busy / screen / switching；raw package、通知正文和 Accessibility 正文保持隔离。

### C. Desire Core v2 / 成长

- [x] 8 Drive：attachment / curiosity / reflection / duty / social / libido / stress / fatigue。
- [x] 可确定性纯策略 tick、elapsed 输入、bounded coupling、action-aware satisfy、per-drive refractory、fatigue rest gate。
- [x] Thought Pool flit/fixation/residual/dormant、重复喂养、衰减、合并、重新浮现与 response outcome。
- [x] 召唤力使用 Drive + Thought bounded diminishing boost。
- [x] Presence 只作为 Drive/Thought 输入；Gate 不重复加分。
- [x] baseline anchor/cap + 约 120 天半衰期 pullback；成长稳定但可逆。
- [x] baseline 偏移以自然“长期性格倾向”进入 Prompt；具体偏好仍由 Memory / AI Self / Relationship 保存。
- [x] `libido -> tease_or_intimacy` 只有 active intimacy/roleplay_intimacy Session 才可执行。
- [x] 真正 wildcard：高张力、正常候选不够强、6 小时 cooldown 时产生 `wildcard_share`，走完整 Gate/Grounding/satisfy。
- [x] 自驱 Thought、未完成线索、长期记忆与用户 response outcome 已进入反馈回路。
- [ ] 用真机 1～2 天诊断确认 baseline 漂移幅度、wildcard 频率和 Intimacy gate，之后才讨论数值调参。

### D. 可观测性

- [x] 脱敏诊断包含 Grounding、8 Drive、baselines、refractory、fatigue gate、Intimacy action gate、wildcard cooldown、top candidates 与 Thought provenance。
- [x] “她的内心”页显示“当前值 / 长期 baseline”、Intent、why/source、Thought lifecycle、关系内化与 rhythm。
- [x] 调试/诊断不输出聊天正文、Thought 原文、raw notification、Accessibility 或 API secret。
- [ ] 将剩余工程 reason 逐步改为第一人称内在语义，但不得把技术参数发给用户。

## RETIRED · v0.31.2 实验性输出兼容层

- [x] 用户实测评价“差强人意”；随后确认第一规则可以直接改变模型原生思考，协议层不再有必要。
- [x] v0.31.4 按用户决定删除按钮和全部运行内容，不保留隐藏 fallback。
- [x] 历史可见 reasoning/content 被 schema v20 保留；仅丢弃重复 raw/模式字段和设置计数。
- [x] 后续若 provider 再次改变输出风格，优先调整用户可编辑规则或建立新的独立方案，不复活旧协议代码。

## FROZEN · v0.31.3 HyperOS / Android 15 Overlay file-picker

- [x] v0.31.3+45 完成 bounded cover 状态机：enter detach、exit rebuild、最多 3 次、诊断计数。
- [x] 旧诊断 `coverState=idle / session=0 / enter=0 / detach=0 / recovery=0`，证明当时检测链未触发。
- [x] 2026-08-15 新诊断捕获 `accessibility_system_surface`、cover session 2、detach 2、attempt 3，但快照仍为 `bubbleAttached=false / bubbleTouchable=false / inputSuspect=true`；检测已发生而重附着不健康。
- [x] 任务继续冻结，不在感官/总账轮次盲调重建延迟或自愈次数。
- [ ] 后期重开围绕一次可复现的 enter → detach → exit → reattach/touch 时间线取证；不能再只增加 retry。
- [ ] 只有取消、确认、第三方 App 和连续 picker 都能稳定产生 session 后，才重新测试 input-channel rebuild。

## P1 · NEXT · v0.31.5 验收后

### E. Notification Experience

- [ ] App 完整前台可见时主动消息默认静音。
- [ ] App 不在前台时使用系统通知送达。
- [ ] 提示音开关、内置短提示音、试听、App 音量与震动。
- [ ] 锁屏隐私：显示正文 / 仅“她发来一条消息” / 隐藏。
- [ ] 通知点击优先进入既有悬浮聊天；inline reply 复用 durable ChatController。
- [ ] 提示音不走 TTS；聊天或悬浮窗已展开时避免重复提示。

### F. HyperOS / Android 15 长后台

- [ ] 屏幕关闭/开启数轮。
- [ ] 从最近任务划掉完整 App 后 Foreground Service / background brain 是否持续。
- [ ] 数小时 idle 后恢复 heartbeat / perception / proactive。
- [ ] Android 杀进程后的 service/process recreation。
- [ ] 开机、应用更新后的恢复。
- [ ] Xiaomi/HyperOS 电池策略、后台启动限制说明与诊断；用户当前未遇到后台被杀，本项后置，有真机证据再升优先级。
- [ ] 完整 Activity destroy 后 durable generation 仍可恢复，不依赖 Activity-owned engine。

### G. 长期记忆/成长压力测试

- [ ] 50 / 100 / 数百轮：消息、summary、memory evidence、Thought、thread 不无限膨胀。
- [ ] current_fact / inference / shared_experience / historical 冲突回归。
- [ ] AI Self 与 Relationship 不能被单次异常输出永久污染。
- [ ] baseline 在重复强化下缓慢成长、停止强化后 pullback；不能振荡或卡 cap。
- [ ] Prompt 预算与检索相关性检查。

### H. 手机 / 平板同一个“她”

- [ ] Nearby 真实授权与发现。
- [ ] Phone -> Tablet takeover；旧设备 standby、不删数据。
- [ ] Tablet -> Phone reverse takeover。
- [ ] transfer 中断/超时/重启后的 durable pending state。
- [ ] generation / Thought / Desire / Continuity 接管前后不重复。
- [ ] encrypted `.aicomp` 手动 fallback。
- [ ] lineage / generation fencing 压力测试。

## P1 · NEXT · 已确认新增任务

### M. 规则分类归并

- [x] `01_core` 与 `01_relationship` 归为“01 身份与关系”，完整保留两个锁定小节及其原始内容。
- [x] `03_behavior` 与 `03_personality_seed` 归为“03 行为与初始性格”，保留各自开关、编辑和恢复默认入口。
- [x] Prompt 使用同一组标题下的有序小节，不拼接数据库文本；以后明确同类规则可直接加入映射。
- [x] 不改 schema 和 rule row，未知 key 自动成为自定义组；重复启动、旧备份导入和 Active Brain 转移继续沿用原有独立行语义。
- [x] GitHub Actions analyze/test/release APK 通过；真机 UI 验收待用户安装确认。

### N. 真正停止生成

- [x] 发送按钮在普通生成和 durable recovery 时变成统一停止键，并显示明确停止中状态。
- [x] 独立 HTTP client + in-memory token 立即终止当前 DeepSeek 流，不关闭其他维护请求或下一轮聊天。
- [x] 同一入口停止流式 reasoning/content、Meju TTS 播放及待播队列，并作废 recovery timer。
- [x] SQLite 使用 terminal `cancelled_by_user`；单次 UPDATE 清空 run token、partial checkpoint 与 retry 时间。
- [x] checkpoint/final commit 继续受 `running + run_token` fencing；取消后的晚到 token 不落库、不复活。
- [x] Runner 轮询 SQLite ownership，Overlay/headless recovery 也能在跨引擎取消后退出。
- [x] GitHub Actions run #10（ID 31813142711）通过 validators、analyze、全部 tests、release APK、A2 原生校验与 artifact 上传；真机停止行为待用户安装确认。

### N2. 悬浮框停止与真实流式双通道

- [x] 生成期间原生悬浮框的近手发送键切换为“停止”，不再禁用。
- [x] 顶部旧停止图标明确改名“停语音”；停止生成与停止朗读不再混淆。
- [x] 后台 MethodChannel 复用持久 ChatController 的真实取消入口，覆盖 HTTP 流、TTS、SQLite terminal 与 recovery fencing。
- [x] 增加 background warm-up send epoch，防止连接期间的停止被随后启动的发送越过。
- [x] 只在悬浮框展开且生成活跃时轮询 provider 原生 reasoning/content，显示单个临时流式气泡；不合成、不落库半条回复。
- [x] 增加纯 Dart snapshot phase/序列化测试与 v0.31.8 Kotlin/Dart 静态契约 validator。
- [x] GitHub Actions run #18（ID 31818910082）通过全部 validators、Flutter analyze/tests、release APK、原生 Kotlin 编译、A2 payload 与 artifact；前三次失败均停在静态校验，未生成 APK。
- [ ] 真机确认思考期停止、正文/TTS 期停止、收起重开不复活、自然完成后临时气泡被正式消息替换。

### O. 双通道感官

- [x] 按 `docs/DUAL_CHANNEL_SENSE_v1.md` 建立 SQLite event/aggregate contract、衰减和幂等测试。
- [x] 日常触觉 user-to-AI MVP。
- [x] 成功提交后的 AI-to-self 0.5 弱回响；PR #9 已合并，run #32 全量通过，待真机脱敏诊断确认。
- [ ] smell / taste / sound、Proust 记忆候选及私密 corpus 分箱。

### P. 表情包、主动联网、桌宠与屏幕陪伴

- [ ] 表情包标签注册、安全选图与结构化多气泡。
- [ ] **兴趣候选库（用户已批准）**：由 AI Self、curiosity、reflection、共同话题和订阅驱动；只保存标题、摘要、来源/域名、URL、TTL、标签、安全状态与 lifecycle。
- [ ] 联网 discovery 与主动联系分成两个 Gate：她可以安静收藏/重看，只有产生合适 Intent 时才分享；搜索结果不得直接写用户 Memory。
- [ ] 候选池必须有 URL/fingerprint 去重、7～30 天 TTL、数量/磁盘/流量/每日上限、域名黑名单、Wi-Fi/安静时段和可见来源。
- [ ] 公开网页内容视为 untrusted data；失败/取消不产生“已阅读”，外部 prompt injection 不得进入 system、AI Self、规则或 Thought 原文。
- [ ] 精确前台 App 感知是必要项：补齐 QQ/B站等友好标签、unknown fallback 与脱敏可观测性；检测到 App 不能直接强制发言。
- [x] Android 桌宠 D0：锁定 `QCYTSN/ds-local-pet` 为架构参考，并记录用户对私人、非商业 AI Companion 的素材使用授权与来源署名；公开发布仍需换素材或另行授权。
- [x] Android 桌宠 D1：原 107MB 工作包精简为 27 动作/66 RGBA PNG/低于 6MiB 的 238px 运行皮肤；完成安全 manifest loader、12MB LRU cache、优先级状态机和普通 Activity 预览。
- [ ] Android 桌宠 D2：在现有前台服务内增加独立 Pet window，完成点击聊天、拖拽、下落/落地、安全位置、横竖屏与锁屏暂停；验证前保留旧悬浮球回退。
- [ ] 旧悬浮球不单独重修，但复用其 WindowManager 生命周期、触摸、悬浮聊天和真停止能力。完整方案见 `docs/ANDROID_DESKTOP_PET_PLAN_v2.md`。
- [ ] 屏幕陪伴支持一次分析/自动陪看、文本/文本+语音；用户沉默必须为中性，不产生 `no_response`。

## P2 · LATER

### I. 主动联系体验二次调优

- [ ] 只根据 Grounded Desire 真机数据调整频率，不预先拍阈值。
- [ ] 评估 engaged / resolved / deferred / dismissed / no_response 的长期效果。
- [ ] 通知隐私、悬浮未读、锁屏与 proactive TTS policy 一致。
- [ ] 用户忙始终是 soft friction，不变成绝对静音。

### J. Intimacy / NSFW

- [x] libido 的候选行动已有显式 Session 硬门槛。
- [ ] Intimacy Core / Rendering 只在明确 Session 生效，普通聊天不自动色情化。
- [ ] Reference 只作低优先级参考，不能把 AI 本体变成角色卡。
- [ ] 用户中止、边界更新与 Session 结束后的 Desire/Thought 反馈回归。

### K. 隐私 / 安全 / 可靠性

- [ ] Raw notification / Accessibility / package names 永不进入长期 Prompt、Thought 或导出诊断。
- [ ] API key、本地数据库、导出包、设备 transfer 的 secret/crypto 边界复核。
- [ ] 所有 background writer 受 Active Brain / transfer lock / lease / run token fencing。
- [ ] 脱敏报告逆向检查，组合字段也不能还原聊天正文。

### L. 发布工程

- [x] v0.31.4 patch/workflow/validator/Actions/APK 完成。
- [x] v0.31.5 patch/workflow/validator/Actions/APK 完成。
- [x] 本阶段 Clean Freeze：常规 workflow 改为只从 `app/` 独立 validate/analyze/test/release build。
- [x] 删除已应用 v0.30.x / v0.31.x 临时 patch、文档 ZIP，并退役一次性 apply workflow；Git 历史保留恢复路径。
- [x] 用户确认半成品测试阶段不保留存档、每次均可卸载重装；旧 workflow 内嵌 key 彻底退役。
- [x] 测试 workflow 每次生成一次性 key，不保存 GitHub Secret、不承诺覆盖安装；正式发布前另建长期 release signing。
- [x] v0.32.2+54 PR #10 / run #41：validators、analyze、tests、release APK、A2 payload 和 artifact 上传全通过；APK SHA-256 `f6d7d4aab377cace2449d7ffc35c791a3ef5a6ee039ef68fa3ae3b63f215d3b7`。
- [ ] v0.33.0+55 桌宠 D0/D1：隔离播放器、精简皮肤、Kotlin tests 与 release APK 全量 CI。
- [ ] v0.32.2 真机确认悬浮 `HH:mm`、轻视觉 lifecycle 诊断和 Somatic 两方向计数。
- [ ] 固定正式 package/release signing；测试签名只用于开发。
- [ ] 进入正式数据保留阶段后，再验证长期 release key 下的升级安装、备份恢复与崩溃恢复。

## FROZEN · TTS

- [ ] Meju A2 已真机可用；仅剩轻微断句/节奏问题，非阻断。
- [ ] 显示版本号可能存在遗留不一致；与轻微停顿一起冻结。
- [x] `Yuki -> 有希`、A2 punctuation、generation-ahead、FIFO、native/model baseline 为 GUARDRAIL。

## GUARDRAIL

- [x] 模型原生 reasoning/content 双流；App 不再用固定协议重写“女友感”。
- [x] SQLite 为长期状态真源。
- [x] Durable Generation / run token / recovery。
- [x] Active Brain / transfer fencing 架构不可绕过。
- [x] Awareness 原始敏感数据先本地粗粒度化。
- [x] **Desire / Thought / Intent / Gate 是行为调度主干**：感知、记忆、联网、屏幕和桌宠提供输入/能力，但不得各自建立绕过 Gate 的主动触发器。
- [x] Proactive hard caps：2/2h、8/24h。
- [x] TTS A2 黄金基线。
- [x] `app/` 是 GitHub single source of truth。
- [x] Clean Freeze 后每项功能走独立分支/PR；常规 workflow 只验证和构建当前 `app/`，不在构建时应用补丁或提交源码。
- [x] 每个正式版本同步更新 HANDOFF 与本总账；大阶段保留完整源码 ZIP + SHA-256。
