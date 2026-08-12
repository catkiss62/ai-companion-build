# v0.31.1 真机检查 · Proactive Grounding + Chat Timestamps

本轮不追悬浮球 file-picker 已知问题。重点确认 proactive 的“当前轮次”与 UI 时间 metadata。

1. **时间戳 UI**：发送两三条消息，用户和 AI 气泡下方应显示 `HH:mm`；跨日期历史应出现“今天/昨天/日期 · 周X”分隔。
2. **TTS 不读时间**：手动朗读一条 AI 回复，只应朗读正文，不应念出 `23:21`、日期或“周三”。
3. **已回答“你好”不再成为 current turn**：发送“你好”，等 AI 正常回复，然后不再发言；到“她的内心”强制测试一次主动联系。reasoning 和正文都应作为新的主动开口，不能以“回复/回答你好”为任务。
4. **连续沉默 proactive**：用户仍不说话时再测试一次；不得虚构“你刚才说/回复了某句”。
5. **纠正重试可观测性**：不要求一定触发。若模型第一次走偏，浅层诊断中的 `proactiveGroundingRetryCount` 可增加；最终用户不应看到被拦截的错误 candidate。
6. **浅层诊断**：不点深度自检直接导出，重点看 `database.grounding`、`database.desireCore`、`backgroundPresence.lastGateBreakdown`；诊断仍不能包含聊天正文/Thought 正文/raw Android payload。
7. **基本回归**：普通聊天、reasoning/body 顺序、TTS、Active Brain、Presence 无明显回归。Overlay 的已知 file-picker 卡死不判本轮失败。
