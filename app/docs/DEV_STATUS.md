# v0.31.4+46 开发状态 · Grounded Desire Growth

- 当前源码候选：`0.31.4+46`；数据库升级到 **schema v20**，支持从 v0.31.3+45 覆盖安装。
- 已移除旧“伴侣式内心与回应”按钮、输出协议、过滤器、纠正重试、诊断与消息模型字段。普通聊天和主动联系统一使用 DeepSeek 原始 `reasoning_content + content`；思考和正文继续流式，流式 TTS 不再受旧开关限制。
- v20 迁移重建 `messages` 表，只保留用户可见的 `reasoning_content` 与正文；聊天、主动消息、时间、模型与设备字段不丢失。旧 v19 状态包仍可导入，退休字段会在导入时丢弃。
- Desire 长期 baseline 新增约 120 天半衰期的缓慢 pullback。关系经历仍能塑造长期倾向，但缺少持续强化时会逐渐靠近初始锚点，避免永久顶在 cap。
- Prompt 不再注入完整 Thought 原文，只提供来源、生命周期、Drive、强度档与安全 topic 线索；本地检索仍可使用原文，但模型不能把 Thought 文本当系统指令。
- `libido -> tease_or_intimacy` 新增硬门槛：只有已经存在明确的 `intimacy / roleplay_intimacy` Session 时才可成为候选行动。普通恋爱聊天不会因数值升高被自动拉入成人场景。
- Wildcard 从随机 pulse 改成真正的 `wildcard_share`：只在整体内在张力较高、正常候选都不够强且不在 6 小时 cooldown 时出现；成功发送后才进入 cooldown 和 action-aware satisfy。
- 长期 baseline 会以自然语言“性格倾向”进入 Prompt；已确认的话题喜好、边界和互动偏好仍由 Memory / AI Self / Relationship 负责，且主动联系的时间、主题和意图偏好继续由 Proactive Rhythm 的反馈学习负责。
- Overlay v0.31.3+45 源码保持原样，但真机问题仍为 FROZEN；TTS A2 黄金资源和队列保持冻结。
- 本地需通过 v0.31.4 validator、schema v20 SQLite 镜像、Dart 语法解析、Desire 长跑与现有 SQLite/TTS 回归。Flutter analyze/test/release APK 仍由 GitHub Actions 完成。
