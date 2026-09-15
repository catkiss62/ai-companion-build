# AI Companion · 当前总账

更新时间：2026-09-15（Asia/Tokyo）

> 本文件是唯一的当前接班入口，采用“总账 v2”轻量结构。冻结历史位于 `app/docs/ledger/archive/AI_Companion_总账归档_截至_v0.41.74+218.md`，只在修改旧模块或核对冲突证据时定点检索，不全文加载、不随任务重写。
>
> 判断优先级：用户最新明确决定 > 当前 GitHub 源码与 Actions > 最新脱敏真机诊断/备份 > 本总账 > 冻结历史。`DESIGNED / IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PASSED / PENDING` 必须严格区分。

## 1. 接班与更新协议

1. 新窗口默认只读本文件、`app/docs/DOCUMENTATION_MAP.md`、当前分支/版本、最近五个提交和当前任务直接涉及的文件。
2. 每个任务只改本文件的当前基线、当前任务、证据和下一步；冻结归档不追加。当前总账必须保持 100 KB 内。
3. 本次拆分前的 1,587,679-byte 完整历史已原文冻结：Git blob `7f269f4a81e2ea052fb52271918d22cb368f948a`，SHA-256 `602c712f0fb06e70c054c2d54fe0e280f312923864040a3a177ee8e7da67ed70`。总账页面曾卡住是因为重复上传/改写旧 1.57 MB 文件；现在只更新此轻量入口，用户无需修改项目设置。

## 2. 永久产品与工程边界

- **主体性优先**：事实与安全 Gate 约束虚假完成、越权、凭据泄漏和不可逆损坏，不把她训练成处处等待批准的被动工具。
- **模型/API 双通道**：内部判断、维护、工具规划和 Outcome 核验走 DeepSeek。DeepSeek + Gemini 模式只在整轮真实结果收齐后调用一次 Gemini 形成最终普通回复；失败可由 DeepSeek 兜底。Cedar 游戏房间对白固定 DeepSeek，提示不得跨板块显示。
- **真实工具事实**：只有成功的真实 Outcome 才支持“已进入、已落子、已发送、已保存、已完成”。失败、blocked、no_result、超时或零调用不能由对白补写。
- **Cedar 信任优先**：信任实时 catalog、完整玩家指南、合法动作、结构化 `next_actor / next_call / revision / legal_actions / resume_after`、防沉迷和终局；APK 不以本地猜测覆盖服务端真值。
- **Cedar 模型自主发现与盲玩隔离**：用户可只说“陪我下五子棋”，由 Agent 从实时目录找游戏。伴侣运行时只能使用玩家接口、当前聊天、正常存档与玩家可见 Outcome；`playerSafeGuide` 必须过滤 GitHub/仓库、源码、后台隐藏状态、题库答案、人类攻略、谜底和剧透；游戏链不得获得 `public_web.search`。开发期可以审计公开仓库的玩家接入协议，但不能把审计材料喂给她。
- **防沉迷**：平台连续游玩轮数可跨游戏累计；`rest` 是否允许小机自行重置只由 Cedar 网站的 `allow_self_reset` 开关裁决，APK 不另行封死。平台 rest 不绕过游戏自己的每日次数、剧情阶段或冷却。
- **生命周期**：本机 `pause / pause_and_release / resume` 保留远端存档；只有明确离席、认输或永久结束才调用远端 `leave / resign`。
- **凭据与隐私**：账号、密码、Token、绑定码、私密房间正文、附件、诊断、备份、模型权重和参考音频不得进入公开 Git、Prompt 或公开诊断；Cedar Token 只在安全存储。
- **数据/发布权限**：用户已长期授权本项目相关源码和文档提交到明确开发分支，并运行常规 Actions、生成 Draft APK；不含合并 `main`、正式 Release、删除分支/用户数据或改变仓库权限。
- **媒体 Agent**：可发送媒体必须同时具备自读、可执行工具、真实附件 Outcome、provenance 和发送后第一人称历史；只有 UI 或 Prompt 声称不算实现。

## 3. 当前唯一有效基线

| 项目 | 当前事实 |
|---|---|
| 仓库 | `catkiss62/ai-companion-build`；Flutter/Android 工程位于 `app/` |
| 当前开发分支 | `agent/v04177-cedar-agent-runtime` |
| 当前目标版本 | `v0.41.77+221 / schema 61 / Snapshot protocol 6` |
| 当前状态 | `IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING` |
| 上一构建基线 | `v0.41.76+220`，Actions run `34866765746` 全绿，`798/798` Flutter tests；APK SHA-256 `3bcab458f8138d97f4f150c5e92d1f5653e018ee87e5a64cbdde6b56f8a2a6d9` |
| `main` | 仍是 v0.38.5 旧基线；不得作为 v0.41.x 开发起点，本批不合并 |
| 本批构建提交 | PENDING |
| 本批 APK | PENDING |

既有能力保护索引：Desire / Thought / Intent / Gate、Somatic、普通聊天、沉浸房间、查手机、Phase 2B/3、Agent 能力桥、Memory 2D、Skills、MCP、`【检查系统】`、中断恢复、screen observation、Genie-TTS 四音色、schema 61 与 Snapshot protocol 6 均不得回归。全工具调用动作展示是后续独立任务，本批只重构 MCP 游戏厅。

## 4. 当前任务：v0.41.77+221 Cedar 统一 Agent 游戏运行时

### 用户目标与最新证据

- 用户明确要求停止按双弈某一步打补丁，读取所有游戏的接入机制后，把 MCP 游戏厅作为一个统一插入能力重构；她应自行发现、读取、决策、调用和续玩，而不是“读完游戏就等待”或用户说一句才走一步。
- +220 真机已证明 Cedar transport 和双弈服务可用：目录、指南、房间、新建、状态、落子都曾成功；失败发生在 APK 控制层。长轮询已得到 `your_turn=true`，本地也保存 `next_actor=companion`，但后台连续 8 次出现 `FormatException: Unexpected end of input`，所以只在下一条用户聊天到来时才继续。
- 前台根因：`AgentToolRunner` 把真实 `catalog / rooms / new / move` 统一改名为“游玩”，`continuationRecommended` 因而看不到真实动作；`durable_generation_runner` 又把任何一次 `cedar_toy.play` 且未推荐继续的结果直接当成交棒，在无调用复核前关环。
- 后台根因：单独的 `_judge` 依赖普通 JSON 正文，900 token 高推理可能只返回 reasoning 而正文为空；解析失败重复同一请求，最终没有动作。后台还在 DeepSeek 规划前占用 5 分钟 Cedar 动作锁，导致规划慢/失败时用户游戏请求只会排队。
- 花园与猫“读了指南后进入等待游戏”与双弈同源：`recordGuide` 本已设为 `guideReady / next_actor=companion / due=now`，是后台规划和错误停止语义丢失，不是各游戏要求等用户。

### 全游戏接入审计结论

- 已于 2026-09-15 复核当前 29 项目录：9 个 Cedar 站内游戏按实时指南；20 个公开项目逐一读取玩家入口、MCP 工具签名或 AI play guide。开发矩阵在 `app/docs/CEDAR_TOY_GAME_COMPATIBILITY_v0.41.74.md`。
- 公开项目覆盖 `cmd` 单入口、建局参数、严格 `available_actions`、惰性时间、共享网页、多人房间/long-poll、多工具旅程。它们都能通过 Cedar 聚合层归一为 `list_games → get_guide → play(game, action, params)`，不需要 APK 写 29 套游戏步骤。
- 唯一允许的已审计补充仍是 duel 紧凑指南遗漏的玩家参数签名 `game_type / mode / stake / target_player_count / fill_with_npcs`；不含房间号、落点、棋谱、谜底或策略。

### 本批已实现

1. 新增 `CedarAgentDecisionModel`：选游戏、回合决策、Outcome 分类全部用 DeepSeek 原生 required function call，控制载荷不再藏在普通 JSON 正文。首轮完整性/格式失败会换成低推理请求重试一次；第二次仍不完整则抛出真实故障，绝不落成“等待游戏”。
2. 回合决策显式区分 `act / invite_user / await_user / await_remote / complete`。`act` 直接携带指南 action 和 params；前后台共享 `CedarAgentTurnPolicy` 的继续/停止语义。
3. 目录、指南和 play 保留真实机器动作名。`list_games / get_guide / rooms / catalog` 等发现动作可继续当前用户目标；真实 `next_actor=companion` 的写操作也继续。删除 `cedarTurnHandedOff` 一次 play 自动关环。
4. “陪我下五子棋”等自然命令现在会真正打开 Cedar gateway，并被视为立即游玩意图；目录仍由模型匹配，不写死“五子棋→duel”。普通“我今天下棋输了”不误触发。
5. 仅仅读完指南时，Agent 不允许写入等待或结束；第一次语义选择无效会在同一 tick 收到协议纠正并重规划一次。仍无合法动作才记录可重试故障，不假装服务端要求等待。
6. 后台模型规划、语义重规划和房间台词生成全部移出 Cedar 动作锁；只在准备提交真实 `play` 或落本地停止态前占锁，并重新核对 session 时间戳与 active game。状态已被用户/另一轮改变时丢弃旧计划并重规划，不执行过期动作。
7. 真实 play 已成功但自由文本分类失败时，默认保持可运行以便下一轮用已保存 Outcome 做状态核对；结构化 Cedar actor 始终优先，写入超时仍先同步而不重放。
8. 新增原生函数流截断/重试、第二次失败不变等待、前台目录→指南→伴侣动作连续性、后台续接和“指南不能直接等待”的固定测试；新增 +221 静态门验证全部 29 个目录项仍在兼容矩阵，统一控制器不得出现游戏 ID 分支。

### 当前验证与待办

- 已通过：`git diff --check`、workflow YAML、Python compileall，以及 Actions 当前列出的本机可执行 `98/101` validators。余下桌宠源码一致性、聊天视觉私有载荷和手工加密 Kotlin 三项依赖 Actions 恢复的私有资源/本机缺失编译器；本机无 Dart/Flutter，编译、Analyze、Flutter tests、Kotlin/JVM、arm64 APK、签名、Artifact 与 Draft 必须由 CI 证明。
- 尚未完成：完整工作流 validators、本地差异复核、提交/推送、Actions 与 APK。因此当前不能声称已经修好或真机通过。
- 真机必须验证：自然说“陪我下五子棋”能自行找到双弈并建/进房；轮到她后无需主聊天提醒会自动落子；花园与猫读指南后会实际开始/恢复；聊天不再因后台规划锁排队；网站允许时 `rest` 可出站；暂离保留 session；盲玩隔离与房间 DeepSeek 不回归。

## 5. 最近基线导航

- `v0.41.76+220 Cedar 玩家协议与后台连续行动收口`：加入实时 play schema 和 duel 参数签名、发现后一次无调用复核；CI 通过但真机暴露 `Unexpected end of input` 与错误交棒，已被 +221 的原生 Agent 通道替代。
- `v0.41.75+219 模型自主发现、盲玩隔离、总账 v2`：建立轻量 gateway、玩家指南净化和轻量总账；保留。
- `v0.41.74+218 游戏厅全量协议审计`：平台 `rest / announcements / vote`、暂停恢复、中文面板、房间 DeepSeek 与兼容矩阵；保留并由 +221 统一执行层承接。

## 6. 后续导航

| 优先级 | 条件 | 下一步 |
|---|---|---|
| P0 | +221 CI/APK 就绪 | 联合真机跑双弈、花园与猫及一项严格合法动作游戏；先看真实调用序列，不再让用户猜根因 |
| P1 | 统一游戏运行时真机通过 | 设计全工具调用动作展示，参考悬浮聊天框“正在做什么/哪里出错/下一步”表达，不直接显示密钥或冗长原始协议 |
| P2 | 后续出现新游戏 | 只在服务器返回矩阵之外的新协议结构时扩充公共解析器，不按 game id 增加步骤脚本 |

## 7. 关键文件

- 前台 Agent 循环：`app/lib/core/ai/durable_generation_runner.dart`、`app/lib/core/agent/agent_tool_planner.dart`、`agent_tool_runner.dart`
- 统一 Cedar 决策与状态：`app/lib/core/mcp/cedar_agent_decision.dart`、`cedar_game_protocol.dart`、`cedar_toy_activity.dart`、`cedar_toy_autonomy_engine.dart`、`cedar_toy_client.dart`
- 盲玩 Skill：`app/lib/core/mcp/cedar_toy_arcade_skill.dart`
- UI：`app/lib/features/chat/cedar_toy_activity_window.dart`
- 全游戏兼容审计：`app/docs/CEDAR_TOY_GAME_COMPATIBILITY_v0.41.74.md`
- 当前测试/门禁：`app/test/cedar_agent_runtime_v04177_test.dart`、`app/tools/validate_v04177_cedar_agent_runtime.py`
- 冻结历史：`app/docs/ledger/archive/AI_Companion_总账归档_截至_v0.41.74+218.md`
