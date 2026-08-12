# v0.31.1 开发状态 · Proactive Grounding + Chat Timestamps

- 版本：`0.31.1+41`；数据库仍为 **schema v18**，无迁移。
- v0.31.0 真机已经证明 Conversation Grounding 数据层判断正确：`lastUserAnswered=true / pendingUserTurn=false / userSpokeAfterLastAssistant=false`，但 DeepSeek proactive reasoning 仍可能把已回答的“你好”当普通 current user turn。
- v0.31.1 将 proactive 历史从 role 序列改成只读 `ANSWERED CHAT HISTORY` system transcript；本轮不再存在 current `role=user`。
- 新增 `CURRENT TURN CONTRACT`：`CURRENT_USER_TURN=NONE / ANSWERED_HISTORY_ONLY=true`，约束 reasoning 与正文都不得把历史 user 消息重新当待回复输入。
- 新增 `ProactiveReasoningGroundingGuard`：当 SQLite 明确用户沉默且最后 user turn 已回答时，检测 reasoning 是否又进入“回复/回答用户上一句”的模式。
- proactive candidate 若正文或 reasoning 首次违反 Grounding，会自动做 **一次且仅一次**纠正重试；第二次仍违规则整条 proactive 不落库，不把错误 reasoning 展示给用户。
- 脱敏诊断新增 proactive Grounding retry count/last reason，不含聊天正文。
- 主聊天 UI 新增每条消息 `HH:mm` 时间戳与跨日日期分隔；时间仅来自 `ChatMessage.createdAt` metadata。
- TTS 继续只读取 `message.content`，不会朗读 UI 时间戳或日期分隔。
- Overlay/WindowManager Android 源码未修改，悬浮球 file-picker 已知问题继续 FROZEN。
- Desire Core v2 数值策略、Presence、Active Brain、TTS A2/native 均保持 v0.31.0 行为。
- 下一批 v0.31.x：当前手机粗粒度上下文强化、baseline pullback、self-drive response outcome、Wildcard、Intent/Action 完整映射；主动联系逻辑稳定后再做消息提示音/锁屏通知体验。
