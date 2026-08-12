# v0.30.0 开发状态 · Background Presence

- 版本：`0.30.0+36`；数据库 schema 仍为 v18，无迁移。
- 最近完整真机稳定基底：v0.29.0 Clean Baseline；v0.29.1 的 TTS/UI polish 已真机运行，但发现 native overlay 展开后后台 Dart command server 未就绪，历史为空且发送显示“她还在重新连接”。
- v0.30.0 首要修复 background FlutterEngine 的 Dart entrypoint 可达性与 ready handshake race。
- 悬浮聊天在后台未 ready 时保留输入，不再清空用户文字；ready 后自动刷新最近 8 条历史。
- Notification / Accessibility window change / device unlock 只发送粗粒度 `signal:*` wake；native 与 Dart 双层 90 秒去抖。
- reactive wake 只提前运行现有 Perception -> Thought/Desire -> Proactive Gate，不绕过 Gate、hard caps、busy soft multiplier、Active Brain/transfer fencing。
- TTS v0.29 A2 baseline 冻结；轻微停顿不再阻塞主线。
- 下一真机重点：后台大脑连接、悬浮聊天真实收发、切 App/收通知/解锁后 backgroundPresence 诊断是否推进，以及是否能在合理 Gate 条件下产生主动联系。
