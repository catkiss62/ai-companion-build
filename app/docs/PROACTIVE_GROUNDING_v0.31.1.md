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
