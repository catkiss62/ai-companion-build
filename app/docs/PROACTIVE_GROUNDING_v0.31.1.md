# Proactive Grounding v0.31.1

## 真机发现

v0.31.0 的 SQLite Grounding 已正确判断：最后真实 user turn 已回答、没有 pending user turn、用户在 AI 上次发言后没有再发言。但 proactive DeepSeek reasoning 仍可能把历史最后一条 user 消息（例如“你好”）当成普通 current turn 去“回复”。

## v0.31.1 修复

### 1. Answered History Transcript

普通用户轮次继续保留真实 `role=user/assistant` 顺序。主动联系则把历史折叠成一个只读 system transcript：

- `REAL_USER_HISTORY`
- `ASSISTANT_HISTORY`
- `ASSISTANT_PROACTIVE_HISTORY`

每条历史带本地时间 metadata，但它们都明确属于 **ANSWERED CHAT HISTORY**，不是当前输入。

### 2. Current Turn Contract

主动生成额外注入：

- `CURRENT_USER_TURN = NONE`
- `ANSWERED_HISTORY_ONLY = true`

reasoning 与正文都不能把旧 user turn 描述成当前等待回复的问题。

### 3. Reasoning Guard + One Retry

`ProactiveReasoningGroundingGuard` 只在以下客观条件同时成立时启用：

- last user turn 已回答；
- 无 pending user turn；
- 用户在 AI 最近发言之后没有再次说话。

它窄范围识别 reasoning 是否又进入“回复/回答已回答用户消息”的模式。正文继续使用已有 `ProactiveGroundingGuard` 检查虚构近期用户发言。

首次任一 guard 失败时，系统进行一次纠正重试；第二次仍失败则整条 proactive 丢弃，不写消息、不展示错误 reasoning。

### 4. Chat Timestamp

`ChatMessage.createdAt` 已存在于数据库。本版只增加 UI 呈现：

- 每条消息显示 `HH:mm`；
- 跨本地自然日显示日期分隔；
- 不把时间拼进 `message.content`；
- TTS 继续只读 `message.content`，因此天然跳过时间戳。

## 未改内容

- schema v18；
- Android Overlay / WindowManager；
- Meju A2 TTS/native/model；
- Desire Core v2 数值策略；
- Presence Momentum 与 Proactive hard caps；
- Active Brain / transfer fencing。

## v0.31.4 状态同步（2026-08-13）

- 旧输出兼容协议已退役；主动联系直接使用 DeepSeek 原生 `reasoning_content + content`。
- Grounding 的事实来源、answered-history transcript、正文 guard 与 reasoning guard 保持不变；首次违反时仍只允许一次 Reality Grounding 纠正，第二次失败则整条丢弃。
- Thought 原文不再进入主动 Prompt。模型只收到 provenance、Drive、生命周期、强度档和是否存在关联主题等结构化线索；本地 `retrievalQuery` 可以继续利用原文检索相关 Memory，但不会把原文当系统文本注入。
- `libido` 只有在明确的亲密 Session 已经激活时才是可执行候选；普通聊天中的数值变化不能越过 Session/边界规则。
- Wildcard 成为有冷却的 `wildcard_share`，仍必须经过 Active Brain、chat lease、频率 hard caps、节奏阈值和 Grounding guard，不能绕过投递安全。
- v0.31.3+45 Overlay 源码保留但真机问题继续冻结；Grounding/Desire 不通过 prompt 或主动频率补偿系统触摸故障。

## v0.31.5 生成时设备锚点（2026-08-13）

- Android 事件落库是持续的，但此前 Awareness 解释受 perception/heartbeat 节流；主动消息可能在生成时只拿到上一轮留下的屏幕状态。
- 普通回复与 proactive 在 `PromptBuilder` 读取 Awareness 前先执行一次本地 `CurrentDeviceContextRefresher`，把生成当下的 screen/locked、粗粒度 current activity、近期 dominant activity、switching、busy 与 signal counts 刷新到会过期的 Awareness。
- proactive Gate、hard caps 与 Desire/Thought 选择仍使用原有调度和节流路径。即时刷新只改善“她开口时知道什么”，不增加“她多久开口一次”，也不因用户做每一个操作而调用模型。
- 刷新失败采用 best-effort：保留仍在有效期内的旧 Awareness，不让临时 Android channel 故障阻断用户回复；诊断记录的只有错误类型。
- 关系事实层明确用户为成年男性/男朋友；初始性格种子允许有判断、不同意和有因果的情绪，但仍受 Reality Grounding 与来源边界约束。
