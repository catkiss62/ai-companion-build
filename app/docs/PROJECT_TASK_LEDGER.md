# AI Companion · Project Task Ledger

> 长期任务总账。每个正式版本更新 `docs/HANDOFF.md` 时必须同步核对本文件；完成、冻结、退役和延期都要显式记录。

状态：`ACTIVE` 当前主线 · `NEXT` 紧随其后 · `LATER` 后续重要 · `FROZEN` 暂停保留 · `RETIRED` 已移除 · `GUARDRAIL` 不可回归。

## P0 · ACTIVE · v0.31.5 Live Context & Self Seed

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
- [ ] 真机仍无效果：`coverState=idle / session=0 / enter=0 / detach=0 / recovery=0`，说明检测链未触发。
- [x] 任务重新冻结，不继续 +47 盲调重建延迟/次数。
- [ ] 后期重开先验证 cover detection：明确无障碍是否为硬前提及授权引导，或找到无需该权限的可靠 enter/exit 证据。
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
- [ ] Xiaomi/HyperOS 电池策略、后台启动限制说明与诊断。
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

- [ ] 合并 `01_core` 与 `01_relationship`，完整保留身份、存在、关系、自主与边界语义。
- [ ] 将 `03_behavior` 与 `03_personality_seed` 归为同一 UI 分类，同时保留常驻原则与可编辑/可关闭种子的不同元数据。
- [ ] 不强求固定六类；已有同类规则以后直接加入对应小节。
- [ ] 迁移不得用默认文本覆盖用户编辑；需覆盖重复启动、旧备份导入和 Active Brain 转移。

### N. 真正停止生成

- [ ] 停止键统一取消/作废模型流、TTS 和 durable recovery。
- [ ] 使用 `cancelled_by_user` 明确状态；取消后的晚到 token 不落库、不复活。

### O. 双通道感官

- [ ] 按 `docs/DUAL_CHANNEL_SENSE_v1.md` 先建 SQLite event/aggregate contract 和测试。
- [ ] 日常触觉 user-to-AI MVP；成功提交后再做 AI-to-self 弱回响。

### P. 表情包、主动联网、桌宠与屏幕陪伴

- [ ] 表情包标签注册、安全选图与结构化多气泡。
- [ ] curiosity 驱动的低频联网 discovery pool，保留来源/TTL/每日上限。
- [ ] Android 桌宠先做许可安全的隔离播放器，再接 Overlay。
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
- [ ] 选择测试签名策略：推荐轮换曾内嵌在旧 workflow 的 key（需卸载一次现有 APK）；若保留旧 key 只允许私人测试兼容，不能用于发布。
- [ ] 设置仓库 Secrets `AI_COMPANION_DEBUG_KEYSTORE_B64` 与 `AI_COMPANION_DEBUG_KEYSTORE_SHA256`；完成前新 workflow 会安全失败，不生成签名不确定的 APK。
- [ ] 固定正式 package/release signing；测试签名只用于开发。
- [ ] 最终覆盖安装、备份恢复、崩溃恢复检查。

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
- [x] Proactive hard caps：2/2h、8/24h。
- [x] TTS A2 黄金基线。
- [x] `app/` 是 GitHub single source of truth。
- [x] Clean Freeze 后每项功能走独立分支/PR；常规 workflow 只验证和构建当前 `app/`，不在构建时应用补丁或提交源码。
- [x] 每个正式版本同步更新 HANDOFF 与本总账；大阶段保留完整源码 ZIP + SHA-256。
