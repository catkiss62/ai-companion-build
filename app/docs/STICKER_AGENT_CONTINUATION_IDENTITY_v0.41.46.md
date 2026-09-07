# v0.41.46 · Sticker Agent + Continuation Identity

## 目标

本版只收口三个已确认缺口：

1. 用户明确说“发个表情包”时，必须经过真实 `sticker.send` Agent 工具，不能用文字假装发送。
2. 沉浸房间的第二次请求只修复明确截断，不再为固定字数补写。
3. Rule 01 称呼不再枚举容易被模型跳跃抽取的绰号示例。

## 表情包 Agent 合同

- `sticker.send` 是 proposal-risk、user-turn-only 的本地能力；不进入自主竞争，不改 Desire / Thought / Moe。
- 只有明确发送指令走确定性快路；能力询问、否定和普通讨论不触发。
- 选择器只从已启用内部图库中取图，遵守 disabled / bold / NSFW 边界和近期去重。
- 图片先绑定当前 assistant message ID，附件和文本只在同一生成任务成功后显示；取消、重试失败或写入权转移时清理未引用文件。
- 工具结果把 index caption 提供给当轮模型；附件历史用“我发送了一张表情包”和同一 caption 进入后续 Prompt。
- 只有本轮 `sticker.send=succeeded` 才允许可见文本声称已发送；无包、无匹配或失败必须照实说。
- 表情包仍保存在 App 内部目录，不写入查手机相册；公开仓库和 APK 不包含用户私人图库。

## 沉浸续写合同

- `finish_reason=length` 一定视为截断；`stop` 只在句尾或中文引号明显未闭合时继续。
- 字数不参与二次请求判定。完整的短回复不续写。
- 续写只完成当前节拍和未完成句，不新开姿势、阶段、高潮或场景。
- 第二次请求的私下 reasoning 不显示、不持久化；用户仍只看到第一段当下内心。
- 末端续写再次固定女性 AI 第一人称 reasoning 和正文“她 / 你”坐标；不使用优先级 1000 世界书作为补丁。

## Rule 01 迁移

新默认文案强调称呼应从当下情绪、长期相处习惯和真实对话自然形成，不因规则中出现过某词而突然使用，也不为变化刻意轮换。数据库只在现有 Rule 01 的 SHA-256 与 v0.41.45 默认完全一致时替换；手工编辑内容始终保留。

## 上游与隐私

表情包格式和选择思路延续参考 [dsh-meme](https://github.com/yyh-001/dsh-meme) 与 [dsh-meme-packs](https://github.com/yyh-001/dsh-meme-packs)；Agent 工具真值思路参考 [dafeiyu-qq-bot](https://github.com/nanbengxian-cyber/dafeiyu-qq-bot)。三个图库 ZIP、68 张私人图片、诊断、备份、密钥和聊天内容均不进入公开提交、Actions Artifact 或 Release。

## 验证

- Dart 回归：明确表情命令/能力询问/否定路由，语义 mood，发送声明的 Outcome grounding，续写触发/边界/隐藏 reasoning，Rule 01 默认与 legacy hash。
- 结构校验：registry、planner、runner、attachment transaction、cleanup、self reader、continuation、rule migration、workflow 和隐私排除。
- CI：全部历史 validators、Flutter analyze/tests、Kotlin、Release APK、签名、原生库与素材完整性。
