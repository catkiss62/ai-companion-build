# v0.29.1 开发状态 · TTS / UI Polish

- 版本：`0.29.1+35`，数据库 schema 仍为 v18。
- 最近真机稳定基底：v0.29.0 Clean Baseline。
- TTS native/model/runtime 冻结；A2 只按 `。！？；.!?;` 分句，generation-ahead + FIFO + ~200ms 保持。
- v0.29.1 在 A2 边界扫描前把 CR/LF/U+2028/U+2029 归一为空格，作为最后一轮非阻断 TTS 小优化。
- Chat 完成态/流式态均改为 reasoning 在正文上方。
- 悬浮球缩小，unread badge 强制置于最高视觉层。
- 悬浮聊天默认最近 8 条，并把历史读取从完整 ChatController warm-up 解耦；更早历史按需加载。
- 新增 `docs/HANDOFF.md`，今后每版同步维护。
- 本轮后主线转向手机行为感知 -> Thought/Desire -> 主动联系真机调优。
