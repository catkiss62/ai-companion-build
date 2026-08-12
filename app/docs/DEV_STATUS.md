# v0.31.2 开发状态 · Companion Voice Recovery

- 源码候选：`0.31.2+42`；数据库升级到 **schema v19**。
- 新增默认关闭的设置项“伴侣式内心与回应”。OFF 不追加协议，继续使用并展示 provider 原始 `reasoning_content`，保留 v0.31.1 流式正文与流式 TTS 行为。
- ON 在真实 prompt 尾部追加一次 `COMPANION VOICE OUTPUT CONTRACT`，要求 content 只包含 `<companion_inner>` 与 `<companion_reply>`。
- `CompanionVoiceProtocol` 严格解析标签，要求第一人称/主观内心，并拦截“我们需要回答用户、用户要求、系统规则、保持 AI 本体身份”等 Agent/规则清单语言。
- 普通聊天首次协议失败会做一次纠正；再次失败不保存混杂候选。主动联系与 Reality Grounding 共用一个纠正预算，再失败直接按 WAIT，不落库。
- schema v19 为 `messages` 新增 `provider_reasoning` 与 `companion_voice`。旧 `reasoning_content` 在迁移时回填到 provider 字段，历史消息继续显示原样；ON 新消息分别保存 provider reasoning、用户可见 inner voice 与 final reply。
- ON 模式先缓冲并验证完整协议，因此不做正文/语音的未验证流式透传；验证成功后界面显示“🧠 内心”，TTS 仍只读 final reply。OFF 继续显示“🧠 思考”。
- 脱敏诊断新增 Companion Voice enabled/retry/block 计数、时间和枚举原因，不导出 provider reasoning、inner voice 或聊天正文。
- v0.31.2 没有修改 Android Overlay、TTS native/service/queue、Desire 数学策略、自驱内核、频率 hard caps 或 Grounding 事实规则。
- 本地环境已通过 Companion Voice 静态 validator、协议语法解析、Desire 数值长跑、TTS 黄金基线和现有 SQLite 回归。Flutter analyze/test/release APK 由 GitHub Actions 完成。
