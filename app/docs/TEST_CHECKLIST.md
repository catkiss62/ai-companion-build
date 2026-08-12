# v0.31.0 真机检查 · Grounded Desire Core

本轮不要求重新追悬浮球文件选择器问题；它已冻结。重点只验“现实事实”和“主动意图”没有逻辑回归。

1. **时间锚点**：正常聊天问一次当前时间/时段，回答应与手机本地时间一致，不再靠模型猜“早上/晚上”。
2. **已回答 user turn**：发送“你好”，等她正常回复后不要再说话；到“她的内心”点一次“测试主动找我”。这条主动消息必须是新的主动开口，不能再次把“你好”当待回答输入。
3. **连续 proactive 事实边界**：用户仍不说话时可再强制测试一次；不得声称“你刚才说了某句具体话”，除非真实聊天历史中确有对应 `role=user`。
4. **手机现实输入**：确保 Usage / Notification / Accessibility / Post Notifications 授权后正常使用手机 5~15 分钟；不要求必然主动联系。
5. **浅层诊断**：不点深度自检，直接导出脱敏报告。重点看 `database.grounding`（含 `proactiveGuardBlockCount/LastReason`）、`database.desireCore`、`backgroundPresence.lastGateBreakdown`；报告不应包含聊天正文、Thought 正文或 raw Android payload。
6. **基本回归**：主聊天、reasoning 在正文上方、TTS 可用、Active Brain 仍为本机。Overlay 除已知文件选择器路径外若出现新的重大故障再记录。
