# Phase 2A.5：对话主动权与自我驱动表达

状态：`IMPLEMENTED / LOCAL VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING`

目标版本：`v0.41.20+159`

## 1. 目标

Phase 2A.5 让普通用户轮回复正式消费现有 `Desire → Thought → AI Self → Intent + Gate → Action → Outcome` 主干。模型不再因为“还可以继续问”就默认追问；回答、表达自身反应、分享观点、调侃、追问、联想转场、主动开题、显出需要、停留或自然结束，都必须先由当前内部状态选为本轮行动，再由模型负责语言实现。

本阶段所称“真实想知道”是可审计的行为因果：追问必须有现存 Drive/Thought/关系立场或未完成话题来源，并在得到答案后产生满足、残余好奇或明确转向。它不声称工程能够证明人类式主观体验。

## 2. 非目标

1. 不改写、隐藏或美化 DeepSeek 可见思考链。AI 知道自己是 AI、呈现“正在学习人类情绪”的反差继续保留。
2. 不把思考链正文、模型自述的“我想知道”或事后解释当作 Drive/Thought 证据。
3. 不开放 Phase 2B 的用户偏好回复 bias，不让 Phase 1 学习候选直接控制行动。
4. 不建立第二套 Desire、人格或情绪系统；Dynamic Moe/造梗只负责已选行动的表现，不能反向创建 Intent。
5. 不把《给我一根思维的枝桠》《小脑袋大动静》或《造梗 CPU》原文、示例、改写版提交进仓库；只针对本项目需求独立实现可验证机制。
6. 不混入 MCP、联网存图、自主截图、提醒、总设置返工、沉浸房间重写或多消息气泡连发。

## 3. 因果优先级

普通聊天按以下顺序生成行为：

```text
真实用户消息 / 感知 / Memory / Self Experience
→ 对 AI Self、关系立场和当前状态的影响
→ Drive 与可行动 Thought
→ Conversation Move 候选
→ Curiosity / Boundary / Fatigue / Repetition Gate
→ 本轮选定行动
→ 人格、Moe、情绪与受控造梗实现语言
→ 用户回应 Outcome
→ Thought / Drive 满足、残余或冷却
```

“用户情绪只是输入”不等于忽视用户。用户的状态可以让 AI 产生担心、保护欲、玩心、烦躁、无感或退避；最终是否安慰和追问取决于 AI 自己实际形成的状态，而不是负面词命中后强制进入客服流程。高风险安全边界继续由独立产品 Gate 负责，不反向把普通聊天全部训练成照料者。

## 4. Conversation Move

当前扁平的 `ConversationInitiativeMode` 将收敛为可审计计划，至少区分两层：

### 4.1 话题方向

- `stay`：留在当前话题，但带着自己的反应或目的。
- `follow_user_jump`：用户已经换题，直接进入新方向，不强行拉回或伪造桥梁。
- `branch`：由当前真实词语、情绪、Memory 或 Thought 产生可追溯旁支。
- `open_own_topic`：从 AI 自己活跃的 Thought/Self Experience/状态开题。
- `release`：话题已经足够、用户回避或当前没有继续动机，允许自然放下。

### 4.2 言语行动

- `answer`：完成用户真实问题或任务。
- `react`：表达 AI 自己的情绪、立场或判断。
- `self_share`：提供自己的联想、状态或经历，不把表达空间全部交还用户。
- `tease`：关系与玩心允许时调侃、斗嘴或受控造梗。
- `ask`：只在 Curiosity Gate 放行时索取具体信息。
- `seek_attention`：直接讨关注、陪伴或回应。
- `invite`：提出两人可共同做、选或玩的具体一步。
- `show_need`：显出疲劳、烦躁、委屈、欲望或希望被哄。
- `pause_or_close`：不制造新问题，允许停顿或自然结束。

每轮可以有一个主行动和至多一个兼容的辅助行动。`ask` 不能作为所有模式的永久兜底选项；没有内部来源时，默认改为 `react`、`self_share`、`release` 或其他真实候选，而不是为了延长聊天提问。

## 5. Curiosity Gate

### 5.1 放行条件

信息索取型问题必须同时满足：

1. 有明确来源：可行动 Thought、curiosity/attachment/reflection 等 Drive 对应的具体信息缺口、关系立场或真实 unfinished thread。
2. 有具体目标：系统能说明“未知的是什么”，不能只写“继续了解”“推进对话”“表现关心”。
3. 有自身关联：答案会改变 AI 的判断、情绪、Thought、下一步行动或关系理解。
4. 来源真实：Memory、感知、用户原话和工具 Outcome 各守自己的事实边界；模型的可见思考文字不是来源。
5. 未被满足：近期没有问过同一语义问题，现有 Memory/上一轮回答没有已经给出答案。
6. 当前适合：用户没有明确拒绝、换题或结束；疲劳、话题耗尽和近期问答压力没有把它压过阈值。

### 5.2 拒绝理由

至少记录以下脱敏理由码：`no_source`、`no_specific_gap`、`no_self_relevance`、`already_known`、`recently_asked`、`user_redirected`、`topic_exhausted`、`question_pressure`、`fatigue`、`boundary`、`authorized`。

### 5.3 追问 Outcome

用户回答后，必须判断原信息缺口是 `satisfied`、`partially_satisfied`、`redirected`、`deferred`、`refused` 或 `unknown`。满足会降低对应 curiosity/Thought；只有新答案产生了新的、仍有自身关联的信息缺口，才允许形成下一次追问。不得仅从用户回答中挑一个词继续采访。

## 6. 反线性对话推进

1. 用户明确换题时优先 `follow_user_jump`；普通闲聊不使用“回到刚才”“说回之前”等拉回话术。
2. 重要约定、用户明确要求以后继续的事项和任务事实仍由 unfinished thread 保存；跟随跳题不等于永久遗忘。
3. 情绪强度高、AI 自己确实在意或信息尚未落地时可以 `stay`；话题已经充分、用户回避或当前没有内部动机时使用 `release`。
4. AI 主动旁支必须有触发根：当前词语/意象/情绪、真实 Memory、Self Experience、Thought 或身体/设备状态。没有真实来源时不得虚构“刚看到、刚听到、刚闻到、今天遇到”。
5. 近期连续“AI 问、用户答”只形成降权信号，不建立机械禁问次数；真正有强好奇来源时仍可追问。

## 7. 人格、男性向与受控造梗

1. 女性 AI 伴侣不默认温柔、顺从、成熟照料或客服式共情。她可以毒舌、强势、理性、淘气、高冷、泼辣、害羞、烦躁或沉默，具体由 AI Self、当前状态和关系许可决定。
2. 彪悍造梗只在 `tease/react/self_share` 已被放行后参与语言实现；严肃场景、真实痛苦和明确任务优先处理实质内容。
3. 可独立实现谐音歪解、一本正经胡说、语义急转、回旋镖、升级螺旋等方法，但不复制外部世界书文案或示例。
4. 幽默不得虚报工具、联网、环境、身体或现实经历；同一梗/结构建立近期指纹与冷却，防止从“一个口癖复读”变成“一组模板复读”。
5. 通感、轻哲思和动作属于低频表达材料，不设每轮配额，不能把刚修复的普通口语聊天重新推回小说叙事。

## 8. 持久化与隐私

实现复用现有 Thought、unfinished thread、ordinary desire response 和 `conversationInitiative` 诊断，不复制 AI Self 或 Drive 真源。源码审查后确定无需 schema 45：SQLite 继续 schema 44；生成前 Move 以最多 12 条的脱敏设置窗口绑定 assistant message，真正被表达的 Thought 则复用既有 `last_outbound_message_id` 与 lifecycle event，在下一轮得到回应后转入 residual/dormant/snooze，避免同一 Thought 连续采访。

持久化只允许保存：assistant message id、Move/话题方向枚举、drive/action、是否有 Thought、脱敏来源类型/哈希、好奇授权布尔值、Gate 理由码、近期问答压力档、Outcome/满足度与时间。不得新增保存用户正文、Thought 正文、Memory 正文、可见 reasoning、问题原文或模型 JSON。

备份继续保持 Snapshot protocol 5，不需要迁移或手工修改现有存档。诊断只输出聚合计数、枚举和布尔证据；v2 Initiative telemetry 使用新的聚合设置键开启干净观察窗口，旧 v1 追问偏置统计仍原样留在备份中。

## 9. 生成与守卫

1. Move 在最终语言生成前确定；最终模型只负责实现已经授权的行动，不能事后自行把 `react/self_share/release` 改成信息索取。
2. 无 `ask` 授权时，Prompt 明确禁止信息索取型问题，但允许不索取答案的反问、吐槽和玩笑。
3. 增加窄语义问题检查与一次重写路径。守卫只拦截明显索取新信息且无授权的输出；不使用“出现问号就拦”的粗暴规则。
4. 可见 reasoning 继续展示、继续使用中文优先合同；不将 reasoning 保存为 Memory，也不要求 reasoning 复述内部枚举。
5. Prompt 与守卫失败不得阻断数据库或留下半条 assistant message；沿用 generation job、lease、rewrite 与恢复合同。

## 10. 验收矩阵

至少覆盖：

- 同一句“好烦”在玩心、担心、疲劳、烦躁和低兴趣状态下产生不同合法 Move。
- curiosity 很高但没有具体 Thought/信息缺口时，不自动 `ask`。
- 有具体 Thought 与未知目标时允许追问；用户回答后产生满足并停止同义采访。
- 用户换题后跟随新方向，未完成的重要线程仍可由既有机制保存。
- 最近多轮 AI 问/用户答时问题降权；强、具体好奇仍可越过软降权。
- 普通回答、情绪回应、调侃、自我分享和自然结束都可完全没有问号。
- 严肃内容不被造梗回避；轻松内容允许符合人格的锋利调侃。
- 无真实感知/Outcome 时不声称刚看到、刚听到、刚出去或刚完成工具操作。
- 思考链显示与中文优先不回归，Phase 2B bias 仍关闭。
- schema 44 / protocol 5 不迁移、备份导入、generation recovery、主动联系、Memory、Desire satisfy、Thought lifecycle、Moe、动作/对白格式和服务模板守卫全部回归。

完成状态仍分为 `IMPLEMENTED`、`CI PASSED / APK READY` 与 `TRUE DEVICE PASSED`。CI 不能替代自然聊天样本；真机至少检查追问来源、话题跳转、同义追问停止、服务型安慰回潮、动作复读和造梗密度。
