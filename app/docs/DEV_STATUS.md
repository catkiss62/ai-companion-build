# v0.30.1 开发状态 · Overlay Touch Recovery

- 版本：`0.30.1+37`；数据库 schema 仍为 v18，无迁移。
- 最近真机确认基底：v0.30.0 Background Presence；后台大脑 ready、悬浮聊天收发与 Awareness→Perception 已通过，随后发现悬浮球偶发“可见但完全无法点击/拖动”。
- v0.30.1 首要修复 WindowManager overlay 的触摸/输入通道恢复与系统安全区域坐标。
- 悬浮聊天在后台未 ready 时保留输入，不再清空用户文字；ready 后自动刷新最近 8 条历史。
- Notification / Accessibility window change / device unlock 只发送粗粒度 `signal:*` wake；native 与 Dart 双层 90 秒去抖。
- reactive wake 只提前运行现有 Perception -> Thought/Desire -> Proactive Gate，不绕过 Gate、hard caps、busy soft multiplier、Active Brain/transfer fencing。
- TTS v0.29 A2 baseline 冻结；轻微停顿不再阻塞主线。
- 下一真机重点：悬浮球在聊天开/关、诊断导出往返、锁屏/解锁后是否持续可拖可点；若再次卡死优先导出 `overlayTouch` 诊断。

- 收起悬浮聊天后完全 removeViewImmediate，避免隐藏 overlay 留下 stale touch region。
- Activity 从诊断导出/文件选择器回来时重建 bubble input channel；30 秒 watchdog 负责轻量自愈。
- 脱敏诊断新增 overlayTouch 健康字段。
