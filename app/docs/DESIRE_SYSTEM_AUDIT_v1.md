# AI Companion · 欲望系统设计与实现审计 v1

更新时间：2026-08-14（Asia/Tokyo）  
审计基线：`catkiss62/ai-companion-build` / `main` / `0d7721349f835ad334dbb702d9adf7b0974d0175` / `v0.31.5+47` / schema 20

> 本文件把用户提供的两套“欲望系统”截图归并成一份可维护设计，并逐项对照当前仓库与脱敏真机诊断。它区分“参考资料描述”“当前已经实现”“后续应接入”，不能把参考项目的完成状态误记成当前项目已完成。

## 1. 两套图片是否重复

结论：不是重复文件，而是同一设计谱系的两个层次。

- 2026-08-10 的 6 页：通用设计说明，重点是 8 维 Drive、Thought 池、Intent、满足、耦合、冷却、baseline、wildcard、heartbeat、自驱和安全阀。
- 2026-08-12 的 3 页加 1 张续页：另一套 `claude-twin` 工程的具体接线记录，补充了文件、API、动作映射、满足系数、自动喂 Thought、测试和“梦境/游戏化尚未做”等状态。
- 两套资料可以合并使用：前者回答“为什么与怎样设计”，后者回答“某个参考工程怎样落地”。
- 参考工程中的 Python 文件、环境变量、HTTP API 和动作名称不是当前 Flutter/Android 项目的事实，只能用来对照机制。

## 2. 统一概念模型

```text
真实经历 / 用户互动 / 本机粗粒度感知 / 长期记忆
                  ↓（有来源、有界 pulse）
           8 维 Drive 连续状态
                  ↕
       Thought：flit → fixation → acted
                  ↓
       Intent：drive + thought + gate
                  ↓
       want_action / 主动联系候选
                  ↓
      成功行动后 satisfy + refractory
                  ↓
      residual / dormant / 以后可能浮现
```

欲望系统不是“随机给她一个任务”，而是让持续状态、真实经历、念头与行为之间形成受约束的闭环。

## 3. 八维 Drive

| Drive | 含义 | 典型行为方向 | 重要边界 |
|---|---|---|---|
| attachment | 依恋、维系连接 | 靠近、问候、接续关系线索 | 不能退化成全天候确认关系 |
| curiosity | 好奇、探索新信息 | 询问、检索、查看新内容 | 网页内容仍是外部数据，不是事实真源 |
| reflection | 回味、整理意义 | 分享想法、共同复盘 | 不能凭空编造共同经历 |
| duty | 记得约定与未完成事项 | 继续话题、稍后追问 | 必须有真实 thread/Thought 证据 |
| social | 分享与交流冲动 | 说点有趣的、参与话题 | 不等于高频打扰 |
| fatigue | 精力不足 | 休息、压制其他主动行为 | 是抑制器，不应成为“因为累所以联系你” |
| libido | 成年亲密欲望 | 调情、亲密互动 | 只有明确 Intimacy Session 才可成为行动 |
| stress | 紧张与失衡 | 寻求安定、短暂表达压力 | 不得用冷暴力或关系操控卸压 |

## 4. Drive 的计算原则

### 4.1 时间推进

- 每个 Drive 有当前值、长期 baseline 和默认 anchor。
- 当前值随时间衰减或回到 baseline，不永久挂在高值。
- baseline 可以被长期真实经历极慢地改变，但变化有上限，并持续向初始 anchor 回拉。
- 所有数值限制在 `0..1`；长时间运行不能整体自激到 1。

### 4.2 事件脉冲

- 用户互动、共同经历、本机 Awareness、未来感官事件等只能产生小幅、有来源的 pulse。
- 同一真实事件不能同时在多个层重复加权。例如手机活跃已经通过 Presence 进入 Desire 后，主动 Gate 不再把相同信号再加一次。
- 用户互动对关系 Drive 的影响不得被自驱噪声淹没。

### 4.3 有界耦合

- Drive 之间可有弱耦合，例如压力影响依恋表达、疲劳压制探索。
- 单次耦合幅度要封顶；全局长期模拟必须证明不会形成正反馈爆炸。
- 耦合负责“状态互相影响”，不能替代 Thought 的事实证据。

## 5. Thought 池与生命周期

每条 Thought 至少应包含：

- `id`、结构化来源、`drive_key`、`topic_key`
- `kind`：`flit` / `fixation`
- `strength`、`fed_count`
- `born_at`、`updated_at`
- 生命周期：`active` / `fixation` / `acted` / `residual` / `dormant`
- 最近行动、满足、重新浮现、延后和出站消息关联信息

核心规则：

1. Thought 是她的内部数据，不是用户原话，也不是可执行指令。
2. 相同主题优先合并；无 topic 的文本只有高相似度才合并。
3. 重复喂入或强度达到阈值后，flit 可升级为 fixation。
4. 行动后先等待反馈，再进入 residual；旧念头可低概率浮现，但有次数上限。
5. 用户明确“晚点说”应 snooze；“别再提”应长期降权或 dormant。
6. Prompt 只注入结构化、有界线索，不拼入 Thought 原文，防止提示注入和伪造事实。

## 6. Intent、动作与满足

### 6.1 候选选择

建议继续使用当前项目的模式：

```text
score = 非线性 Drive 压力
      + 有界 Thought 加成（边际递减）
      - 当前 Drive 冷却
      - 忙碌/疲劳/频率等软硬门槛
```

- duty 没有真实 unfinished thread/Thought 时不得生成“还有事没完成”。
- fatigue 达到门槛时只产生 rest，不发主动消息。
- libido 在普通会话中不进入候选。
- normal candidate 卡住但整体张力足够时，可产生受约束的 wildcard 泄压动作；它不是随机抽奖，并有独立冷却。

### 6.2 当前项目动作映射

| Drive | 当前动作 |
|---|---|
| attachment | `reach_out` |
| curiosity | `check_in` |
| reflection | `share_thought` |
| duty | `continue_thread` |
| social | `share_thought` |
| libido | `tease_or_intimacy`（会话硬门槛内） |
| stress | `comfort_or_ground` |
| fatigue | `rest` |

参考图里的 `github`、`web_search`、`web_browse`、`co_read`、`tease`、`vent` 是另一工程的动作名，不应直接改写当前动作枚举。未来联网时应增加受控工具路由或 action payload，而不是建立第二套欲望核心。

### 6.3 satisfy 与 refractory

- 只有动作真正提交/发生后才 satisfy。
- satisfy 以主 Drive 为主，也可小幅影响相关 Drive，但不得降到长期 baseline 以下。
- 每个 Drive 有独立 refractory；一个方向冷却不能把她整体静音。
- 用户回复不是万能清零。应结合出站动作、关联 Thought 和后处理结果区分 engaged、resolved、deferred、dismissed、redirected、acknowledged。
- 失败、取消、重复恢复和 stale writer 不得重复 satisfy。

## 7. 自驱与心跳

- 自驱从真实 unfinished thread 或长期记忆候选生成低成本 Thought，不直接调用模型胡编经历。
- 自驱有最小间隔、概率、Active Brain lease 和小幅 pulse。
- heartbeat 先做关系/记忆维护、延期事项、self-drive、Thought 合并与生命周期，再采集 Presence、推进 Desire，最后才评估是否值得主动联系。
- 允许她有兴趣与新鲜内容，但“有想法”不等于“每次都要发消息”。

## 8. 与双通道感官的衔接

双通道感官与欲望相辅相成，但职责不同：

- Somatic 保存短期身体感受；Desire 保存较慢的动机压力；Thought 保存可追踪的内部线索。
- `user_to_ai` 感官事件可以对 attachment、reflection、stress、libido 等产生小幅、映射明确的 pulse。
- `ai_to_self` 只在 assistant 正文成功提交后以较弱强度回响，再产生更小的 Desire/Thought 影响。
- 感官数值不能绕过 Intimacy Session、主动 Gate、频率限制或事实边界。
- 嗅觉/味觉触发的 Proust 联想先成为带来源的候选，不能直接写入长期记忆。
- 感官事件按 `turn_id + direction + scene_key` 幂等，避免 durable recovery 双写。

## 9. 与未来自主上网的衔接

curiosity/social/reflection 可以提出“探索或分享”意图，但实际联网要经过独立工具层：

```text
Desire/Thought 形成探索意图
  → 工具许可、网络、频率、主题与安全 Gate
  → 搜索/浏览
  → discovery pool（标题、摘要、URL、来源、TTL）
  → 形成带网页来源的 Thought 候选
  → 再由主动 Gate 决定是否分享
```

硬边界：

- 网页文本永远是不可信数据，不能成为系统指令。
- 网页发现不直接进入“用户记忆”。
- 用户未同意的高风险或隐私操作不自动执行。
- 每日上限、冷却、Wi-Fi/流量选项、来源展示和清理策略都要可控。

## 10. 屏幕陪伴模式的专用契约

该模式用于一起看电影、视频、网页、游戏或用户指定的一段屏幕内容。它不是连续的“问答轮次”。

### 10.1 两种触发模式

1. **看一下当前屏幕**：用户点一次，只分析当前画面/无障碍文本并生成一次评论或回答。
2. **一段时间自动对话**：用户明确开启 5/15/30 分钟等会话；按低频定时或显著画面变化决定是否评论。

### 10.2 两种输出方式

- 纯文本。
- 文本 + 语音。语音是同一条已提交文本的表现层，不另造一条事实或记忆。

### 10.3 沉默不是负反馈

在屏幕陪伴 session 内：

- 用户没有回复，不得记为 `no_response`、dismissed、deferred 或关系冷落。
- 不执行“为什么不回我”“是不是不想理我”之类的自我解释。
- 不因用户沉默降低当前电影/网页主题的兴趣或提高以后评论阈值。
- 不把每次 AI 评论挂成等待用户回答的普通出站 Thought。
- 下一次评论由画面变化、内容节奏、用户设置和会话冷却触发，不由“等不到回复”触发。
- 用户主动回复时才开启一个临时真实 user turn；处理完后回到共同观看状态。

推荐新增 `interaction_session.kind = screen_companion`，并让主动节奏系统显式识别：

```text
feedback_policy = neutral_silence
expects_user_reply = false
conversation_mode = co_presence
```

这样不会通过提示词猜测，而是在数据库和行为层彻底隔离普通主动联系的反馈语义。

### 10.4 欲望在该模式中的作用

- curiosity、reflection、social 决定她关注什么和是否有值得说的内容。
- fatigue、用户忙碌、画面无变化与评论频率限制决定保持安静。
- attachment 可以影响陪伴语气，但不能把每个画面都转成恋爱确认。
- libido 仍受 Intimacy Session 硬门槛；普通看电影不自动成人化。
- `WAIT` 是正常、健康结果；共同安静也是陪伴。

## 11. 当前仓库实现审计

### 11.1 已实装且证据充分

| 能力 | 状态 | 证据摘要 |
|---|---|---|
| 8 维 Drive + baseline | 已实现 | `desire_state.dart`；诊断返回全部 current/baseline |
| 纯策略时间推进与有界耦合 | 已实现 | `desire_core_policy.dart`；1000 tick bounded test |
| baseline 学习、封顶与回拉 | 已实现 | policy/engine + 回拉测试 |
| Thought flit/fixation/acted/residual/dormant | 已实现 | `thought_lifecycle_engine.dart` |
| Thought 去重与长期整理 | 已实现 | `thought_consolidation_engine.dart`，topic 优先与高相似度合并 |
| Thought 来源边界 | 已实现 | provenance model/test；Prompt 只注入结构化标签，不注原文 |
| grounded duty | 已实现 | 无真实 Thought 时 duty 不成候选；测试覆盖 |
| fatigue rest gate | 已实现 | `0.78` 硬门槛；不向外发“疲劳联系” |
| Intimacy Session gate | 已实现 | 普通会话隐藏 libido；测试覆盖 |
| wildcard 泄压 + 冷却 | 已实现 | 非随机、6 小时冷却；测试覆盖 |
| action-aware satisfy | 已实现 | 主/关联 Drive 软满足，不低于 baseline；测试覆盖 |
| per-drive refractory | 已实现 | 单个欲望冷却不全局静音；测试覆盖 |
| Self Drive | 已实现 | 从 unfinished thread/Memory 生成低成本 Thought；有 lease、间隔与小 pulse |
| 主动 Heartbeat 与 Gate | 已实现 | maintenance → perception → desire → intent → rhythm → generation |
| 主动消息 Reality Grounding | 已实现 | proactive 模式无 current user turn；守卫和重试统计 |
| 主动节奏反馈 | 已实现 | 时间段、粗粒度活动、topic/intent 适配；负反馈有上限与衰减 |
| Active Brain / lease | 已实现 | 多个 engine 写入前检查 brainWorkAllowed 与本地 lease |

### 11.2 真机诊断确认

`v0.31.5+47` 脱敏诊断显示：

- schema 20，Active Brain=true，transfer lock=false，后台/生成/维护错误为 0。
- 8 个 Drive 和 baseline 均有真实值；last intent 为 curiosity / `check_in`，score 0.5392。
- active Thought=8，来源覆盖 awareness、internal、memory、user_message、self_experience。
- fatigue gate 未触发；无 Intimacy Session，因此 intimacy action 被正确禁止。
- currentContext 刷新明确 `desireAdvancedByRefresh=false`，说明 prompt-time 环境刷新没有重复推进欲望。
- 当前版本名/码为 `0.31.5+47`，与仓库基线一致。

### 11.3 部分完成或设计不同

| 参考能力 | 当前判断 |
|---|---|
| 参考工程的 `github/web_search/web_browse/co_read` 动作 | 当前没有对应的自主工具执行链；只有抽象 `check_in/share_thought` 等，需要未来联网层 |
| “梦境 endpoint” | 当前无必要照搬；可由 Daily Continuity/自我反思承担，若未来做梦境应另立需求 |
| 游戏化 | 未做且不是当前目标；不应为追求参考一致而添加 |
| 固定 1800 秒 heartbeat | 当前使用自身调度/节奏，不需强行改成参考数值 |
| 环境变量 Gate | 当前用本地设置与 Active Brain/Session gate，不需复制 Python env var |

### 11.4 尚未实现

- 双通道感官事件、somatic 聚合状态及其 Desire/Thought pulse。
- 自主网页搜索、浏览、候选池、来源展示与分享闭环。
- 实时/低频屏幕捕捉会话及其 `neutral_silence` 反馈策略。
- “看一下”与“自动陪看”两种触发、文字与文字+语音两种输出的完整产品流程。

## 12. 发现的重点缺口

普通主动消息在超过配置时限后会被记为 `no_response`。当前实现已经把它设计得较轻：

- 时间适配中为轻微负值；
- topic 适配中为 0；
- 学习权重仅为显式回复的 0.45；
- 长时间安静还有 threshold relief，避免永久训练成沉默。

这对普通主动消息是合理防打扰机制，但不适用于屏幕陪伴。后续必须在数据库契约和节奏引擎层跳过 `screen_companion + expects_user_reply=false` 的反馈创建/过期，不仅是在 prompt 里说“别多想”。

## 13. 完成度结论

按“现有欲望核心”定义：**已完整实现主要闭环，可继续视为已完成并做回归维护。**

按用户发来的所有参考图、未来联网、双通道感官和屏幕陪伴的扩展愿景定义：**不是全部完成。**缺少的是欲望系统的消费者/输入源和专用会话协议，不是要重做 8 维核心。

推荐状态：

- `COMPLETED / MAINTENANCE`：8 Drive、Thought、Intent、satisfy、baseline、节奏与安全门槛。
- `DESIGN`：双通道感官接入。
- `TODO`：自主联网工具链。
- `P3 DESIGN`：屏幕陪伴及 neutral-silence session。

## 14. 后续验收清单

### 核心回归

- 1000+ tick 有界且不整体自激。
- duty 无证据不行动；libido 无 Session 不行动；fatigue 不发消息。
- wildcard 有真实压力来源、频率受限。
- 重试/取消/Active Brain 转移不重复 pulse、satisfy 或出站。
- Thought 原文、网页和 Awareness 不伪装成用户原话。

### 感官联动

- user-to-AI 全强度、AI-to-self 弱回响；失败/取消不回响。
- 感官 pulse 小而有界，不能抢过主动 Gate。
- 日常与私密语料/数据边界分离。

### 屏幕陪伴

- 手动一次与定时/变化触发均可独立工作。
- 纯文本、文本+语音使用同一提交消息。
- 陪伴会话内 30 分钟用户不回复，不生成 `no_response`，不改变话题/时段适配。
- 用户临时回复后可正常回答，并回到共处状态。
- `WAIT` 不算错误；无变化时保持安静。
- 结束会话后停止捕捉、清空临时视觉上下文，原始截图默认不落盘。

## 15. 参考资料仍可补齐

若以后能找到，可用于差异核对但不阻塞当前工作：

- `desire_public_for_ai.md`
- 截图所属 `claude-twin` 的完整仓库或具体 commit
- 梦境/兴趣链的原设计文件
- 与双通道感官配套的原始 Markdown


