# AI Companion · Project Task Ledger

> 这是项目长期任务总账，不是某一版的临时 Roadmap。每个正式版本更新 `docs/HANDOFF.md` 时，都必须同时核对此文件；完成、冻结、延期都要显式改状态，避免长上下文或新主线把旧的重要任务挤掉。

状态：`ACTIVE` 当前主线 · `NEXT` 紧随其后 · `LATER` 后续重要 · `FROZEN` 暂停但保留 · `GUARDRAIL` 已落地且以后不可回归。

## P0 · ACTIVE · v0.31.2 Companion Voice Recovery（可选开关）

> DeepSeek V4 Pro 服务端更新后，provider `reasoning_content` 从第一人称主观内心变成 Agent/规则清单式规划；当前 App 又直接把它展示为“思考”，导致关系连续性和“女友感”明显下降。此任务是 provider compatibility 层，不把恋爱话术永久写死进基础人格。
>
> 分批约束：v0.31.2 只改 Companion Voice；Overlay 固定到 v0.31.3，Desire 定向收尾固定到 v0.31.4。三版分别构建、真机验收和回滚，不做跨域合并补丁。

- [x] 设置页提供默认 OFF 的“伴侣式内心与回应”；**OFF 不注入新协议、不改变当前 provider 请求/流式路径**，允许未来直接使用模型原版行为。
- [x] ON 模式把 `provider_reasoning / inner_voice / final reply` 三者分离；provider reasoning 只作本地诊断证据，不再直接冒充用户可见的“她的内心”。
- [x] 模型显式输出第一人称 `inner_voice` 与 `reply`；协议只在真实 prompt 尾部注入一次，避免被旧规则层覆盖或重复叠加。
- [x] inner voice 允许自然犹豫、玩笑、安静、亲近与少量动作/停顿，并拦截 Agent 清单/规则讲解；不要求每轮撒娇或动作描写。
- [x] 保留 AI 身份与 Reality Grounding；主动联系的 Voice/Grounding guard 检查解析后的 inner/reply。
- [x] 缺标签、格式错误或 Agent 污染最多纠正重试一次；proactive 与 Grounding 共用一次预算，仍失败时 WAIT/block，不落库错误候选。
- [x] TTS 只朗读最终 reply；A2/native/分句队列哈希未改。ON 缓冲验证，OFF 保留流式分句。
- [x] schema v19 独立保存 `provider_reasoning / reasoning_content / content + companion_voice`；旧 reasoning 回填 provider 字段，历史显示不变。
- [ ] 用现有截图建立 golden cases：短问候、深夜陪伴、昵称承接、暧昧玩笑、主动想念；再加严肃办事、拒绝亲昵等反例，防止“女友感”退化成固定滤镜。
- [x] 开关名称、默认关闭与用户可见说明按讨论结果实现。
- [x] **v0.31.2+43 真机热修**：修复 +42 仅接受 content 双标签、无法识别 DeepSeek 原生 reasoning/content 双通道而导致普通聊天 `protocol_shape` 连续失败；加入原生/跨通道解析与安全正文 fail-open，主动消息仍保持严格拦截。
- [x] **v0.31.2+43 真机复测**：开启开关后普通消息已能回复，诊断无 generation failure；仍观察到部分 `inner_agent_planning` 被安全降级，且体验上内心非流式、回复偏短/缺少括号神态。
- [x] **v0.31.2+44 源码实现**：过滤后的第一人称内心采用可撤回整体替换流式预览；最终验证覆盖 preview。Companion Voice ON 的回复增加软性展开度和按语境出现的括号神态倾向，OFF 路径不变。
- [ ] **v0.31.2+44 真机复测**：内心逐步出现且最终不重复；Agent planning 不留在历史；短陪伴对话明显比 +43 丰富并有自然括号神态；技术/严肃对话不过度表演。

## P0 · NEXT · v0.31 Grounded Desire Core 定向收尾

> v0.31.1+41 已在 v0.31.0 基础上补齐 proactive context isolation、reasoning grounding、一次纠正重试和主聊天时间戳；下列未勾选项继续留在后续 v0.31.x。

### A. Reality Grounding（先保证“她知道什么是真的”）

- [x] **真实时间锚点**：普通聊天与主动联系每次生成前，由调用方显式传入本机当地日期、时间、UTC offset、星期、daypart。Desire 纯策略本身不直接读取 wall-clock。
- [x] **Conversation Grounding**：从 SQLite 的真实 `messages + generation_jobs` 确定：最后真实用户消息、最后 AI 消息、最后用户消息是否已经被 AI 回复、AI 回复后用户是否再次发言、当前是否存在 pending user turn。
- [x] **禁止重复回复已回答消息**：主动联系不得把“最后一条 user 消息”简单当成本轮最新输入。若该 user turn 已有对应 assistant generation，主动消息必须理解为“我已经回复过，用户之后暂未继续说话”。
- [x] **Proactive Context Isolation**：主动联系的旧聊天折叠为只读 `ANSWERED CHAT HISTORY` system transcript；当前 proactive 请求不再携带可被模型当作 current turn 的 `role=user`。
- [x] **Reasoning Grounding**：DeepSeek `reasoning_content` 同样受 `CURRENT_USER_TURN=NONE` 约束；若首次 candidate 把已回答历史当成当前输入，最多纠正重试一次，仍违规则整条丢弃。
- [x] **聊天时间 metadata 展示**：主聊天每条消息显示 `HH:mm`，跨日本地日期分隔；时间不写入正文，TTS 继续只读 `message.content`。
- [x] **事实来源隔离 / provenance**：`user_message / awareness / memory / self_experience / inference` 必须在 prompt 中保持来源边界。只有真实 `role=user` 内容允许被表述成“你说过……”。
- [ ] **Thought 不是用户发言，也不是系统命令**：provenance 与“不得伪装用户原话”已经实现；但 `PromptBuilder` 仍拼入完整 Thought 文本，尚需改成有界结构化摘要/关键词，避免原始 Thought 成为 prompt 指令面。
- [ ] **当前手机上下文**：把新鲜的粗粒度 activity / busy / screen / switching 状态作为“当前环境”独立块传入；继续禁止 raw package name、通知正文、Accessibility 正文进入长期 prompt。
- [x] 为普通聊天与 proactive generation 增加 Grounding 单元测试，覆盖“你好已回复后用户沉默”“连续两次主动消息”“proactive 历史无 current role=user”“reasoning 回复已回答 hello 的 guard”“当地时间明确注入”等案例。

### B. Desire Core v2（让“她为什么想做事”成为内核，而不是 Gate 算分）

- [x] 保留并正式定义 8 Drive：`attachment / curiosity / reflection / duty / social / libido / stress / fatigue`；语义统一为“女性 AI 伴侣”，不照搬参考中的男性 AI / 哥哥 / GitHub / 浏览器行为词。
- [x] **纯策略 tick**：Drive 的衰减、回归、coupling、refractory、score 计算支持显式 `now/elapsed` 输入，便于确定性测试；Android/后台层负责提供时间。
- [x] **Thought Pool**：继续 `flit -> fixation -> residual/dormant`，保留重复喂养、衰减、合并和重新浮现；增强 provenance，禁止 Thought 文本污染事实层。
- [x] **召唤力 score**：Drive + 相关 Thought/Fixation boost，使用边际递减，避免某一维瞬间顶满。
- [x] **Action-aware satisfy**：不再只有“满足主 Drive 一个 factor”；按实际 action 对主/相关 Drive 做柔性回落，例如 reach_out、followup、share_thought、tease/intimacy、comfort/vent、rest 等。
- [x] **Per-drive refractory**：刚满足的需求短期内不能立刻再次赢，但其他 Drive 仍可产生 Intent。
- [x] **fatigue gate**：fatigue 是抑制闸，不作为普通主动联系理由；高 fatigue 时允许安静、不硬找事情。
- [x] **bounded coupling**：Drive 间小系数联动 + 全局阻尼；做随机长跑测试，禁止正反馈震荡。
- [ ] **baseline drift 双安全阀**：anchor/cap 已实现；仍缺明确的长期时间/关系 pullback，现有正向 baseline learning 不能持续累积到 cap 后永久停留。
- [x] **self-drive 第一阶段**：自己的 Thought、未完成线索、长期记忆可形成低强度 intent，发送与用户 response outcome 也已进入反馈；后续任务是长期 baseline/自我经历平衡，不重复建设整套 self-drive。
- [ ] **Intent / Action 能力硬边界**：基础 action mapping 已接入；仍需给 `libido -> tease_or_intimacy` 增加显式 Intimacy Session gate，并继续禁止假装已经完成外部动作。
- [ ] **Wildcard**：当前实现仅随机 pulse 普通 Drive，尚不是“整体张力高且正常候选均不可执行时”的泄压 action；补齐真正选择、投递与 satisfy 路径。
- [x] Presence Momentum 降级为 **Drive/Thought 的现实输入源**；Proactive Gate 回归“安全/投递闸”角色，避免同一手机活动同时在 Desire 和 Gate 里重复加权。

### C. 内心状态可观测性

- [x] 脱敏诊断新增 `grounding`：local time/daypart、last user/assistant 时间、pending user turn、last user answered、factual/reasoning guard block/retry 统计；不输出聊天正文。
- [x] 脱敏诊断新增 `desireCore`：8 Drive、baselines、refractory、top scores、selected intent/action、Thought provenance 计数、fatigue gate、最后 satisfy/action。
- [x] `Inner` 调试页升级为只读“她的内心”面板：Drive / top Thought / Intent / why / refractory；调试 UI 不进入普通关系界面。
- [ ] 所有调试 reason 使用第一人称内在语义，但不得把技术参数直接发给用户。

## P0 · NEXT · HyperOS / Android 15 Overlay file-picker 恢复

> 文件选择器位于 `TYPE_APPLICATION_OVERLAY` 之上是系统窗口层级的正常结果；故障是打开文件页后，即使取消/确认并离开，悬浮球仍可见却 100% 失去触摸，直到进入 AI Companion 才恢复。

- [x] 静态定位现有恢复链：Accessibility system-cover、Overlay root visibility、`MainActivity.onResume -> ACTION_RECONCILE` 均可触发 `removeViewImmediate + createBubble`；进入主 App 后恢复与 reconcile 路径一致。
- [x] 根因边界：系统 cover 的退出主要依赖有限 package allowlist + `TYPE_WINDOW_STATE_CHANGED`；OEM DocumentsUI/Photo Picker 变体或返回事件漏报后，`overlayInputSuspect` 无后台消费者。
- [x] 现有 30 秒 permission watch 只验证 attached/flags/enabled，不能识别“表面健康但 input channel 已死”，也不会消费 suspect。
- [ ] 实现有界 cover 状态机：明确 enter/suspect/exit/rebuilt，只有已经观察到 cover/suspect 时才允许扩大 exit 证据，避免全局监听噪声。
- [ ] 对遗留 suspect 增加一次性 watchdog fallback，设置次数上限、冷却/退避；系统 cover 仍在顶层或主 App 可见时不得反复重建。
- [ ] 脱敏诊断区分 cover-enter、exit evidence、rebuild source、attempt/cooldown；不得恢复 v0.30.2 的 `selfHealCount=28 / coverRecoveryCount=11` 风暴。
- [ ] 真机验收至少覆盖：打开后取消、确认选择、从 picker 回原 App、切到第三方 App、连续多次 picker、30 分钟日常使用无误重建。
- [ ] 与 Companion Voice 分开补丁和 APK 验收，避免两个高风险兼容层互相干扰定位。

## P1 · NEXT · v0.31 之后立即处理

### D. Notification Experience · 主动消息送达

- [ ] App 完整前台可见时主动消息默认静音，不做打扰式通知。
- [ ] App 不在前台（其他 App / 桌面 / 锁屏）时使用系统通知送达。
- [ ] 提示音开关、内置多种短提示音、试听、App 内音量、震动选项。
- [ ] 锁屏隐私：显示正文 / 仅“她发来一条消息” / 隐藏；Android/HyperOS 最终锁屏与 heads-up 行为仍尊重系统通知设置。
- [ ] 通知点击优先进入既有悬浮聊天；Inline reply 继续复用 durable ChatController。
- [ ] 消息提示音不得走 TTS；App 正在聊天或悬浮聊天已展开时避免重复“叮”提示。

### E. HyperOS / Android 15 长后台生存

- [ ] 屏幕关闭/开启数轮。
- [ ] 从最近任务划掉完整 App 后，Foreground Service / background brain 是否持续。
- [ ] 数小时 idle 后恢复 heartbeat / perception / proactive。
- [ ] Android 杀进程后的 service/process recreation。
- [ ] 开机、应用更新（package replaced）后的恢复。
- [ ] Xiaomi/HyperOS 电池策略、后台启动限制的真实设备说明与诊断。
- [ ] generation job 在完整 Activity 真正 destroy 时仍可由 durable worker 恢复，不依赖 Activity-owned engine 生命周期。

### F. 长期记忆压力测试

- [ ] 50 / 100 / 数百轮对话压力测试：消息体积、摘要、memory evidence、Thought、unfinished thread 均不能无限膨胀。
- [ ] `current_fact / inference / shared_experience / historical` 冲突语义回归。
- [ ] 长期事实的证据累积、过时/被替代、错误推断不能覆盖事实。
- [ ] AI Self 与 Relationship 的长期变化不能被一次异常模型输出永久污染。
- [ ] Memory / Daily Continuity / Thought 的 prompt 预算与检索相关性检查。

### G. 手机 / 平板同一个“她” · Active Brain 真机接管

- [ ] Nearby 真实授权与发现。
- [ ] Phone -> Tablet takeover；旧设备必须 standby、不删数据。
- [ ] Tablet -> Phone reverse takeover。
- [ ] transfer 中断/超时/应用重启后的 durable pending state。
- [ ] generation / Thought / Desire / Continuity 在接管前后不重复执行。
- [ ] encrypted `.aicomp` 手动 fallback 实测。
- [ ] 两端状态 lineage / generation fencing 压力测试。

## P2 · LATER · 完整产品化前的重要任务

### H. 主动联系体验二次调优

- [ ] 在 Grounded Desire Core 真机数据基础上调主动频率，而不是先拍脑袋改阈值。
- [ ] 评估 `engaged / resolved / deferred / dismissed / no_response` 对 desire/rhythm 的长期影响。
- [ ] 通知隐私、锁屏展示、悬浮未读与 TTS proactive policy 的一致性。
- [ ] “用户忙”始终是 soft friction，不变成绝对静音。

### I. Intimacy / NSFW Session 深度融合

- [ ] Intimacy Core / Rendering 仍只在明确亲密 Session 生效，普通聊天不自动色情化。
- [ ] `libido` 进入 Desire Core 后不能单靠数值强行开启成人 Session；必须满足当前关系/会话语境与用户可中止边界。
- [ ] Reference 继续只作为低优先级参考，不能把 AI 本体变成角色卡。

### J. 隐私 / 安全 / 可靠性审计

- [ ] Raw notification / Accessibility / package names 永不进入长期 prompt、Thought 或导出诊断。
- [ ] API key、本地数据库、导出包、设备 transfer 的 secret/crypto 边界复核。
- [ ] 主动联系与 background writer 全部继续受 Active Brain / transfer lock / leases / run token fencing。
- [ ] 脱敏报告做逆向检查：不能通过组合字段还原用户聊天正文。

### K. 发布工程

- [x] **v0.31.1 完整源码交接基线**：`app/` 确认为 `0.31.1+41` / schema v18，v0311 补丁反向校验证明已完整合入；失败 v0.31.2 不进入基线。
- [ ] **v0.31.2 构建交付**：全新源码实现、本地回归、source-update patch、完整替换 workflow 和干净 v0.31.1 round-trip 已完成；待 Actions 通过 analyze/test/release APK 后勾选。
- [ ] 阶段性 Clean Freeze：从纯 `app/` checkout 独立 analyze/test/release build。
- [ ] 删除已应用的 v0.30.x / v0.31.x 临时 patch 和 apply workflow。
- [ ] 固定正式 package/release signing；测试签名只用于开发。
- [ ] 最终升级/覆盖安装、备份恢复、崩溃恢复检查。

## FROZEN · 已知问题 / 暂不阻断主线

### TTS

- [ ] Meju A2 已真机可用；仅剩轻微断句/节奏体验问题，**非阻断**。
- [ ] 当前 TTS 版本号可能是修改后的遗留不一致；与轻微断句停顿一起冻结，不为了版本显示重动可用引擎。
- [ ] `Yuki -> 有希`、A2 punctuation、generation-ahead、FIFO、native/model baseline 均为 `GUARDRAIL`，不能重做。

## GUARDRAIL · 已落地、以后不可回归

- [x] DeepSeek provider reasoning、Companion inner voice 与 reply 独立保存；OFF 保留原版 reasoning 路径，ON 不把 provider Agent planning 当作“她的内心”。
- [x] 本地 SQLite 为长期状态真源。
- [x] Durable Generation / run token / recovery。
- [x] Active Brain / transfer fencing（待双机真机验收，但架构不可绕过）。
- [x] Awareness 原始敏感数据先本地粗粒度化。
- [x] Proactive hard caps：2/2h、8/24h（后续可经充分真机数据讨论，但不能无保护删除）。
- [x] TTS A2 黄金基线。
- [x] `app/` 是 GitHub single source of truth；不恢复历史五分包 + patch 链构建。
- [x] 大阶段内使用“成对的 source-update patch + 完整手动 Apply workflow”迭代；大阶段验收后再做仓库整合/完整回归/Clean Freeze，不在每个小版强制清理补丁。
- [x] 每个正式版本更新 `docs/HANDOFF.md`；大阶段保留完整 source ZIP + SHA-256。
