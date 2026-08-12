# v0.31.2+44 开发状态 · Streaming Inner & Richer Voice

- 源码候选：`0.31.2+44`；数据库保持 **schema v19**，可覆盖安装 v0.31.2+43。
- 新增默认关闭的设置项“伴侣式内心与回应”。OFF 不追加协议，继续使用并展示 provider 原始 `reasoning_content`，保留 v0.31.1 流式正文与流式 TTS 行为。
- v0.31.2+42 真机诊断发现：DeepSeek V4 Pro 把内心放入原生 `reasoning_content`、回复放入 `content` 时，被仅检查 content 双标签的解析器误判为 `protocol_shape`，导致普通用户轮次连续两次失败。
- v0.31.2+43 优先兼容 DeepSeek 原生双通道，同时保留旧双标签和“标签内心位于 reasoning、正文位于 content”的跨通道形态。
- v0.31.2+44 将 ON 模式的 provider reasoning 做成**可撤回的过滤流式预览**：累计内容只有满足第一人称主观条件且未命中 Agent 规划时才整体显示；后续若出现污染立即清空，最终用验证后的 inner voice 整体替换。正文仍在完整验证后显示，TTS 仍只读正文。
- Companion Voice 提示增加展开度：普通陪伴对话通常 2～4 个自然段、3～7 句、约 80～220 中文字；深夜/玩笑/亲近语境通常自然加入一处、最多两处全角括号神态/停顿。严肃办事/技术答复可短且无动作，不强制固定滤镜。
- `CompanionVoiceProtocol` 仍要求第一人称/主观内心，并拦截“我们需要回答用户、用户要求、系统规则、保持 AI 本体身份”等 Agent/规则清单语言。
- 普通聊天首次协议失败会做一次纠正；再次失败时若 `content` 是安全自然正文，就保存正文并仅隐藏该轮内心，不能再让用户消息悬空。协议标签或 Agent 计划仍禁止降级透传。主动联系失败仍按 WAIT，不落库。
- schema v19 为 `messages` 新增 `provider_reasoning` 与 `companion_voice`。旧 `reasoning_content` 在迁移时回填到 provider 字段，历史消息继续显示原样；ON 新消息分别保存 provider reasoning、用户可见 inner voice 与 final reply。
- ON 模式只流式显示可撤回的过滤内心，不流式透传未验证正文/语音；验证成功后界面保留“🧠 内心”，TTS 仍只读 final reply。OFF 继续显示“🧠 思考”并保持原版正文/思考流式路径。
- 脱敏诊断新增 Companion Voice enabled/retry/block 计数、时间和枚举原因，不导出 provider reasoning、inner voice 或聊天正文。
- v0.31.2 没有修改 Android Overlay、TTS native/service/queue、Desire 数学策略、自驱内核、频率 hard caps 或 Grounding 事实规则。
- 本地环境已通过 Companion Voice 静态 validator、协议语法解析、Desire 数值长跑、TTS 黄金基线和现有 SQLite 回归。Flutter analyze/test/release APK 由 GitHub Actions 完成。
