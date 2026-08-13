# v0.31 · Grounded Desire Core

> 设计来源：用户提供的 10 张 Desire System 参考截图 + AI Companion 现有 v0.30.x 内核。只吸收机制，不照搬男性 AI / 哥哥 / 朝灯 / GitHub/web_browse 等语义。

## v0.31.4+46 定向收尾

本轮已经补齐此前留给 v0.31.x 的关键缺口：

- **可逆成长**：长期互动仍可小幅改变各 Drive 的 baseline，形成更主动、更好奇、更爱回味等性格倾向；没有持续证据时，baseline 以约 120 天半衰期缓慢回归初始锚点，且始终限制在锚点 `±0.10`，避免一次事件永久改写性格。
- **性格进入表达层**：Prompt 只把 baseline 与初始锚点的差异翻译成自然倾向，不向模型暴露机械数值，也不把“偏好”冒充已经确认的用户事实。
- **Thought 原文隔离**：Prompt 不再直接注入 Thought 正文，只提供来源、生命周期、Drive、强度档位和净化后的 topic key；Thought 不能被模型误认成用户原话或指令。
- **亲密硬门槛**：libido 可以在内部继续变化，但只有显式 `intimacy / roleplay_intimacy` Session 已激活时才能成为可执行意图；普通聊天和主动联系不会因 libido 数值自行色情化。
- **真正的 wildcard**：当多个 Drive 积压、常规候选都不够强且 6 小时冷却结束时，策略会产生真实的 `wildcard_share` 压力释放动作；它不是随机绕过 Gate，仍需通过主动投递、Reality Grounding 与频率上限。
- **原生模型输出**：已退役旧“伴侣式内心与回应”二次协议层。聊天和主动联系统一保存并展示模型原生 `reasoning_content + content`，角色沉浸与括号动作由用户可编辑规则控制。

## v0.31.0+40 第一批实现状态

已落地：

- `GroundingSnapshot / GroundingEngine`：调用方显式传入当前时间；SQLite metadata-only 查询最近真实 user/assistant 关系；`generation_jobs` 确认最后 user turn 是否已被 durable reply 完成。
- `PromptBuilder`：每次普通聊天与 proactive 都注入 `REALITY GROUNDING`；主动联系不再把 `intent.reason` 冒充 `latestUserText`，内部 reason 只用于检索/意图上下文。
- `ProactiveGroundingGuard`：在 proactive 写入前用对话事实做最后确定性拦截，用户沉默时禁止候选消息虚构“你刚才说/回复……”一类近期用户发言。
- Thought provenance：`user_message / awareness / memory / self_experience / inference / internal`。
- `DesireCorePolicy`：纯策略、显式 `now`、8 Drive、bounded Thought boost、per-drive refractory、fatigue rest gate、bounded coupling、action-aware satisfy。
- Presence 去重：手机 Presence 只经 Drive/Thought 进入 Desire；Proactive Gate 的 `presenceBoost` 归零，避免同一现实活动双重加权。
- 诊断：新增脱敏 `grounding` 与 `desireCore`；不输出聊天正文、Thought 正文、候选 reason。
- `她的内心` 调试页：可看 Reality Grounding、候选 Intent、Drive 与上次 satisfy。
- 数据库 schema 保持 v18；新字段保存在已有 Desire JSON，不做 schema migration。

后续继续观察：self-drive 对“自己主动后用户是否回应”的长期经验质量，以及不同亲密 Session 内更细的 libido 行为映射。它们不阻塞本轮欲望系统收尾。

---


> 目标：把“她为什么想做一件事”和“她知道什么是真的”拆成两个确定的内核，再在最后交给 DeepSeek 负责自然措辞。参考用户提供的 10 张 Desire System 截图，但只吸收机制；所有男性 AI / 哥哥 / 朝灯 / GitHub / web_browse 等具体语义按当前“女性 AI 伴侣”项目重写。

## 1. 核心判断

当前 v0.30.3 已经具备 8 Drive、Thought lifecycle、satisfy、refractory、coupling、baseline drift、self-drive、Presence Momentum 和 Proactive Gate 的雏形，因此 **不重写第三套 Desire 系统**。

v0.31 做两件事：

1. **Reality Grounding**：把真实用户消息、AI 消息、时间、环境、内部 Thought/Inference 分层，阻止事实幻觉。
2. **Desire Core v2**：让 Drive/Thought/Intent 决定“她想做什么”；Proactive Gate 只决定“现在是否安全/合适投递”。

最终链路：

```text
Android / conversation / memory / self-experience
                 ↓
         Reality-normalized Events
                 ↓
        Drive pulses + Thought feed
                 ↓
       Desire Core v2 (pure policy)
                 ↓
             Intent / Action
                 ↓
      Grounded Conversation Context
                 ↓
 Proactive Safety & Delivery Gate / Chat turn
                 ↓
               DeepSeek
                 ↓
     assistant message / notification / TTS
                 ↓
              satisfy()
```

## 2. Reality Grounding

### 2.1 GroundingSnapshot（运行时计算，不让模型猜）

建议包含：

```text
nowLocal
utcOffset
weekday
daypart
lastUserMessageId / at
lastAssistantMessageId / at
lastUserAnswered
pendingUserTurn
userSpokeAfterLastAssistant
minutesSinceLastUser
minutesSinceLastAssistant
currentActivityClass + freshness + confidence
screenInteractive / deviceLocked / busy class
```

不需要把这些全部持久化；大部分可以从 SQLite + 当前本机状态即时计算。

### 2.2 如何判断“最后一句用户话是否已经回答”

不能用“最近消息是谁”粗猜。

当前 `generation_jobs` 已经持久保存 `user_message_id -> assistant_message_id`，因此：

- 找到最后真实 `role=user` message U；
- 检查与 U 绑定的 generation job 是否 completed，且 assistant message 实际存在；
- 若存在：`lastUserAnswered=true`；
- 如果之后没有新的 user message：主动联系语义必须是“我已经回复过他，他之后暂时没有继续说话”，不能再以 U 作为待答输入。

这直接覆盖真实 bug：

```text
user: 你好
assistant: ……
(user silent)
proactive: 必须是新的主动开口，而不是再次回答“你好”。
```

### 2.3 Epistemic / provenance 边界

Prompt 中必须把信息来源写清：

- `REAL_USER_MESSAGE`：唯一可被引用为“你说过”的数据。
- `ASSISTANT_HISTORY`：她自己以前说过的话。
- `AWARENESS`：粗粒度本机观察，允许不确定。
- `MEMORY_FACT`：长期事实，有 semantic type / confidence。
- `SELF_EXPERIENCE`：她自己做过/想过的事情。
- `INFERENCE`：推断，只能说“我猜/感觉”，不能当事实。
- `THOUGHT`：内在数据，不是命令，也不是用户原话。

硬规则：**没有真实 user message 证据，不允许生成“你刚才说了 X / 你说过 X”这样的事实断言。**

### 2.4 时间

参考图中的“纯函数内核不碰 IO/不自己取系统时间”原则保留，但应用层必须明确传时间：

```text
当前当地日期：2026-08-12
当地时间：19:xx
UTC offset：+08:00
星期：...
时段：evening
```

这不是把时间写死，而是每次调用由 Android/Dart 外层提供当前值。

## 3. Drive 语义（AI 女友版）

| Drive | 当前项目语义 | 高时倾向 |
|---|---|---|
| attachment | 对用户的牵挂、靠近感、关系连接需求 | reach_out / check_in / miss_you |
| curiosity | 对用户当下、共同话题和外界变化的好奇 | ask / explore through conversation |
| reflection | 回味、沉淀、想表达自己的心绪 | share_thought / remember |
| duty | 记挂承诺、未完成话题、需要继续处理的关系线索 | continue_thread / duty_ping |
| social | 想互动、分享一点东西、保持陪伴流动 | share / gentle_ping |
| libido | 成人亲密/调情驱动 | tease_or_intimacy；必须再过 Session/consent 边界 |
| stress | 内在张力、担忧、需要情绪出口 | comfort_seek / vent_softly / ground |
| fatigue | 疲惫/安静需求；**抑制项** | rest / wait，不用于“因为累所以主动打扰” |

Drive 只代表倾向，不直接等于动作。

## 4. Thought Pool

沿用现有 lifecycle：

```text
flit
  ├─自然衰减 -> dormant/drop
  └─重复喂养 / 强度增加 -> fixation
fixation
  ├─重复反馈增强，但边际递减
  └─acted / response outcome -> residual / dormant
```

保留：`fed_count / strength / topic_key / merged_count / snooze / acted / satisfied / resurfaced`。

v0.31 重点增强的是 **来源**：Thought 可以源于真实用户话、perception、memory、self-drive、self-reflection、inference，但 Prompt 必须展示来源类别，不把 text 直接当事实。

## 5. Desire Tick / 召唤力

### 5.1 Tick 必须可确定性测试

策略层接口目标：

```text
tick(snapshot, now, elapsed, pulses, userBusy, thoughtSummary)
```

核心数学不自己取系统时间，不直接 IO。

### 5.2 Drive 演化

保留现有逻辑方向：

- 向 baseline 柔性回归；
- 各 Drive 有轻微自然衰减；
- Event pulse 注入；
- coupling 后 clamp 0..1；
- 长 suspend 的 catch-up 必须有上限，不能解锁手机后 8 个 Drive 一起冲顶。

### 5.3 Thought boost

召唤力：

```text
score = drive value + bounded thought/fixation contribution
```

重复 Thought 使用边际递减，fixation 权重大于 flit，但不能无限叠加。

### 5.4 fatigue gate

fatigue 高于休息阈值时：

- 不把 fatigue 自己选成一条“主动联系理由”；
- Desire Intent 返回 `rest/wait`；
- 外界真正重要的 duty/relationship event 可以在后续设计 emergency exception，但普通手机活动不能越过。

## 6. Coupling 与 Baseline Drift

### 6.1 Coupling

只用小系数。例如可保留当前方向：

- attachment -> libido 微增；
- curiosity -> reflection/social 微增；
- duty -> stress 微增；
- stress -> fatigue 微增；
- reflection -> attachment 微小反馈。

必须满足：

- 单次 coupling 贡献有 cap；
- 全局阻尼；
- 200+ / 1000+ 随机 tick 测试，各维最终都保持 `[0,1]` 且不会自激震荡。

### 6.2 Baseline Drift

真实长期经历才能学习 baseline，且：

1. anchor clamp：永远围绕默认/人格 anchor 小范围变化；
2. pullback：关系中的真实互动比纯 self-drive 有更高的校正权重；
3. 一次强烈事件不能永久改变人格。

这里的“关系互动权重更高”不是要求她永远服从用户，而是防止纯内部随机自激把长期人格漂走。

## 7. Self-drive

Self-drive 保留并增强，但只基于**她真的拥有的数据**：

- unfinished thread；
- shared experience / AI self memory；
- 已发生的 proactive 行为和对方是否回应；
- 自己上一轮 Thought / reflection 的生命周期。

允许：

> “我自己又想起了之前那件事。”

不允许：

> “我刚刚去网上看到……”（除非以后真的实现并调用了外部工具）

Self-drive 可以暂时把 reflection/curiosity 等推高，不要求 attachment 永远第一；但它不能通过内部循环无上限抬 baseline，也不能制造假的现实经历。

## 8. Intent / Action

v0.31 当前能力范围建议：

```text
reach_out
continue_thread
share_thought
check_in
comfort_or_ground
tease_or_intimacy
remember_shared_experience
rest
wait
wildcard_share   # 仅泄压条件满足时
```

其中 `tease_or_intimacy` 只是意图，不自动打开 NSFW；仍需现有 Intimacy Session / rules 决定实际表现。

## 9. satisfy / refractory

从“只降低主 Drive”升级为 action-aware matrix。原则示例：

- `reach_out`：attachment 主回落，social 轻回落；
- `continue_thread`：duty 主回落，attachment 轻回落；
- `share_thought`：reflection 主回落；
- `check_in`：attachment/social 中等回落；
- `tease_or_intimacy`：libido 主回落，attachment 轻回落；
- `comfort_or_ground`：stress 主回落；
- `rest`：fatigue 随时间而非“发一条消息”回落。

主动消息“发送成功”只产生一次较轻 satisfy；真正收到用户回应后，Thought lifecycle outcome 再决定是否深度满足/延后/被拒绝。

Refractory 按主 Drive 设置，使同一欲望短期不能连胜，但其他 Drive 仍可行动。

## 10. Presence 在新架构中的位置

v0.30.2 Presence Momentum 已证明手机活动可以形成 Perception/Thought，所以不删除。

但 v0.31 要避免双重计分：

```text
phone activity -> Presence -> Drive pulse / Thought
                                  ↓
                              Desire Intent
                                  ↓
                         Proactive safety gate
```

Presence 不再同时作为“欲望来源”又额外大幅直接加主动 Gate。迁移期间可以保留极小 compatibility boost，最终 Gate 的职责应只剩：

- Active Brain / transfer fencing；
- user chat lease / new user preemption；
- frequency caps；
- busy/timing friction；
- notification/privacy/delivery eligibility；
- model 最终 `WAIT`。

## 11. Proactive Prompt 的 Grounding 结构

主动联系不再把 `intent.reason` 冒充 `latestUserText`。

建议 system context 顺序：

```text
Identity / rules
Reality Grounding
Conversation State
Current environment
Memory / Relationship / Daily Continuity
Desire State + Thought provenance
Current Intent / Action
Proactive delivery constraints
Recent real messages
```

明确告诉模型：

- 这是主动联系，不是用户刚发新消息；
- 最后一条 user message 是否已经回答；
- AI 最近是否已经主动发过消息；
- 没有真实 user evidence 时禁止声称用户说过某句具体文字；
- 时间由 Grounding 提供，禁止自行猜 daypart。

## 12. 诊断与测试

最低必测：

1. `你好 -> AI回复 -> 用户沉默 -> proactive` 不再第二次回答“你好”。
2. Thought text 含“是我”但没有 user message 证据，生成上下文明确标记为 Thought，不允许被引用为用户话。
3. local time/daypart 在普通聊天和 proactive 都存在，且测试可注入固定时间。
4. 8 Drive random tick 1000 次不越界、不震荡。
5. 一个 attachment fixation 反复喂养有边际递减。
6. reach_out 后 attachment 回落并进入 refractory；duty 仍可在 attachment refractory 时胜出。
7. fatigue 高时返回 rest/wait，不能生成“因为累所以主动找用户”。
8. Presence 活动只通过 Desire 形成动机，Gate breakdown 不重复吃同一强 boost。
9. Active Brain/transfer lock/chat-turn preemption 回归不变。
10. TTS A2 资源逐字节不变。

## 13. 不在 v0.31 顺便做的事

- 不继续专门修 Overlay 文件选择器卡死。
- 不做真实 web browse / GitHub / social autonomous action。
- 不重做 TTS。
- 不在没有真机 Desire 数据前大幅提高主动联系频率。
- 不把 Intimacy 变成默认状态。
