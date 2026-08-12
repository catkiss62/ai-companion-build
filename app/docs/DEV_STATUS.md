# v0.30.2 开发状态 · Overlay Resume + Presence Intelligence

- 版本：`0.30.2+38`；数据库 schema 仍为 v18，无迁移。
- v0.30.1 真机确认：后台大脑与悬浮聊天可用；发现 100% 可复现的系统文件选择器场景——系统页面遮盖悬浮球后，返回普通 App 时悬浮球可能可见但输入通道失效，打开完整 AI Companion 后会恢复。
- v0.30.2 增加外部 window transition 驱动的 input-channel rebuild；恢复 reason 不包含包名/页面文本。View window visibility 从隐藏恢复到可见时也会做一次去抖恢复。
- Overlay 诊断新增 inputSuspect / systemCover / coverRecoveryCount 等字段，用来区分“WindowManager 看起来可触摸”和“系统输入通道真实恢复”。
- Presence Intelligence 新增会衰减的 Presence Momentum：单次弱事件不足以形成 Thought；多次粗粒度活动、切换、通知/Accessibility 计数可逐渐累积。
- Momentum 达到阈值后只向 `presence:phone_activity` 这一可合并 Thought 喂低强度 attachment/curiosity，不记录外部 App 包名、通知正文或 Accessibility 正文。
- Proactive Gate 只获得小幅、有上限的 Presence boost；Active Brain、chat/proactive lease、busy soft multiplier、rhythm learning、2h/24h hard caps 全部保留。
- TTS A2 baseline 冻结；本轮不改 native/MNN/queue。
