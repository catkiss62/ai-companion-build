# v0.31.0 开发状态 · Grounded Desire Core

- 版本：`0.31.0+40`；数据库仍为 **schema v18**，无迁移。
- Reality Grounding 已接入普通聊天与主动联系：真实本地日期/时间/UTC offset/星期/daypart、last user/assistant、last user answered、pending user turn、用户是否在 AI 上次发言后再次说话。
- Grounding 查询使用 metadata-only message headers；诊断不读取/导出聊天正文。
- `generation_jobs user_message_id -> assistant_message_id` 用于确认真实 user turn 是否已经完成回复；历史数据仍有非 proactive assistant fallback。
- 主动联系不再把 `intent.reason` 当成 `latestUserText`；内部 Thought/reason 只作为检索 query 和明确标注的内部原因。
- 新增 `ProactiveGroundingGuard`：用户真实沉默时，模型候选若虚构“你刚才说/回复了……”会在持久化前被硬拦截。
- Thought 新增 provenance：`user_message / awareness / memory / self_experience / inference / internal`。
- 新增纯 `DesireCorePolicy`：8 Drive、显式 now、fatigue rest gate、bounded Thought/Fixation boost、per-drive refractory、bounded coupling、action-aware satisfy。
- Presence Momentum 继续作为现实活动输入，但 Proactive Gate 的直接 `presenceBoost=0`，避免手机行为在 Desire 与 Gate 双重计分。
- 脱敏诊断新增 `database.grounding` / `database.desireCore`；`她的内心`页显示 Grounding 与候选 Intent。
- Overlay 冻结：文件选择器返回后可能 input channel 卡死，回主 App 可恢复；不再单独追版本。
- TTS A2 冻结/非阻断，native/model/队列不改。
- 下一批 v0.31.x：baseline pullback、self-drive response outcome、wildcard pressure-release、libido/Intimacy 更细映射；之后进入 HyperOS 长后台、长期记忆压力、双机 Active Brain 真机接管。
