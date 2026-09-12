# Cedar Toy MCP · v0.41.67+211

## 目标

让 AI Companion 能在用户明确邀请时连接 Cedar Toy 游戏厅，并沿现有 Agent 循环取得真实列表、真实指南和真实游玩 Outcome。Cedar 的 HTTPS/MCP 请求只是外部工具传输，不是语言模型调用。

## 固定调用链

1. `cedar_toy.list_games`：先读取此刻远端实际开放的全部游戏；不在客户端写死游戏目录。
2. `cedar_toy.get_guide`：`game` 必须出自本轮列表；取得该游戏的真实动作和参数指南。
3. `cedar_toy.play`：`game` 与 `action` 分别受本轮列表和指南约束；只有真实成功 Outcome 才能支持得分、胜负、进度或经历声明。

每个阶段只向 DeepSeek 暴露下一项工具。失败、空结果、未配置、参数错误或取消都会形成终态 Outcome，不能由模型补写。

## 模型与计费合同

- DeepSeek 单模型模式：内部规划、维护、核验与最终可见回复都由 DeepSeek 完成。
- DeepSeek + Gemini 模式：DeepSeek 完成工具选择与 Outcome 核验；收齐整轮上下文和所有真实工具结果后，只调用一次 Gemini 形成完整最终可见回复。
- Cedar MCP 请求不会调用模型；它的结果作为工具消息进入既有循环。不得因为接入 Cedar 新建独立模型 Key/provider，也不得把同一轮拆成多次 Gemini 子调用。

## 凭据与隐私

小机密码只在设置页内用于一次 HTTPS 登录并随即清空。Cedar Token 只保存到系统安全存储。账号、密码、Token 和绑定码都不得进入聊天 Prompt、模型参数、工具审计正文、诊断或备份。

## 自主性边界

用户本轮明确提到 Cedar Toy、游戏厅或一起玩小游戏才开放工具。一次游玩只是一段真实经历，不自动写成永久爱好。v0.41.66 Phase 3C 的成熟兴趣消费入口在本版撤回；Desire、Thought、Intent、Gate 与原有自主联网仍是主体性主链。
