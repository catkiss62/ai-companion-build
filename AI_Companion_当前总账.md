# AI Companion · 当前总账

更新时间：2026-09-14（Asia/Tokyo）

> 本文件是唯一的当前接班入口，采用“总账 v2”结构，只保存永久边界、当前基线、当前任务和最近证据。冻结历史位于 `app/docs/ledger/archive/AI_Companion_总账归档_截至_v0.41.74+218.md`，仅在修改旧模块或核对历史证据时定点检索，不再随每次任务重写或上传整份历史。
>
> 判断优先级：用户最新明确决定 > 当前 GitHub 源码与 Actions > 最新脱敏真机诊断/备份 > 本总账当前区 > 冻结历史与 Git 历史。`DESIGNED`、`IMPLEMENTED`、`CI PASSED`、`APK READY`、`TRUE DEVICE PASSED`、`PENDING` 必须严格区分。

## 1. 接班与更新协议

1. 新窗口默认只读本文件、`app/docs/DOCUMENTATION_MAP.md`、当前分支/版本、最近五个提交和当前任务直接涉及的源码/测试；禁止为了“完整”全文加载冻结归档或遍历项目。
2. 修改旧功能时，根据本文件导航在归档、Git 历史、专项文档和当前源码中定点检索。只有证据冲突或来源不明的跨模块回归才扩大读取范围。
3. 每个任务开始时在“当前任务”登记目标、证据、保护边界和验证；完成后回填实现、提交、CI/APK、真机状态与下一步。冻结归档不再追加。
4. 当前总账建议保持 100 KB 以内。历史达到阶段边界时，创建新的带版本截止点的只读归档，并继续复用这个固定当前入口；不得再把历史拼回当前文件。
5. 本次拆分前的完整 1,587,679-byte 历史已原文冻结；Git blob `7f269f4a81e2ea052fb52271918d22cb368f948a`，SHA-256 `602c712f0fb06e70c054c2d54fe0e280f312923864040a3a177ee8e7da67ed70`。这解决的是更新/上传大文件导致页面长时间无响应，不需要用户修改项目设置指令。

## 2. 永久产品与工程边界

- **主体性优先**：以“她”为持续存在的主体设计。事实与安全 Gate 约束虚假完成、越权、凭据泄漏和不可逆损坏，不把她训练成处处等待批准的被动工具。
- **模型/API 双通道**：内部判断、维护、工具规划和 Outcome 核验固定走 DeepSeek。DeepSeek 单模型模式下最终回复也走 DeepSeek；DeepSeek + Gemini 模式下，收齐整轮上下文和真实工具结果后只调用一次 Gemini 形成最终可见回复，失败可由 DeepSeek 兜底。MCP 网络请求不是语言模型调用，不另建 Key/provider 旁路。
- **真实工具事实**：只有成功的真实 Outcome 才能支持“已进入、已落子、已发送、已保存、已完成”等声称。失败、blocked、no_result、超时或零调用不能由对白补写。
- **Cedar 信任优先**：默认信任 Cedar 的实时 catalog、玩家指南、合法动作、结构化 `next_actor / next_call / revision / legal_actions / resume_after`、防沉迷和终局。APK 只保留凭据、并发、不可逆操作、真实声称和伴侣连续性边界，不以本地猜测覆盖服务端真值。
- **Cedar 盲玩隔离**：伴侣运行时只能使用 Cedar 玩家接口、当前聊天、自己的正常存档与玩家可见 Outcome。`get_guide` 只授权规则和动作协议，不授权 GitHub/其他源码、实现细节、后台隐藏状态、题库答案、人类攻略、通关提示或外部网页。开发期可以审计公开仓库以验证协议类型，但审计材料不得进入普通游玩 Prompt。旧缓存与新指南都必须净化仓库/外链和明确攻略、答案、剧透章节；游玩链执行层不暴露公开网页检索。
- **凭据与隐私**：账号、密码、Token、绑定码、私密房间正文、用户附件、诊断、备份、模型权重和参考音频不得进入公开 Git、Prompt 或诊断公开面。Cedar Token 只在系统安全存储。
- **数据/发布权限**：用户已长期授权本项目任务相关源码和文档提交到明确开发分支并运行常规 Actions/Draft APK；不含合并 `main`、发布正式 Release、删除分支/用户数据、改变仓库权限或公开敏感资料。
- **媒体 Agent**：任何“她能发送的媒体”必须同时具备自读能力、可执行工具、真实附件 Outcome、来源 provenance 和发送后第一人称历史；只有 UI 或 Prompt 声称不算实现。

## 3. 当前唯一有效基线

| 项目 | 当前事实 |
|---|---|
| 仓库 | `catkiss62/ai-companion-build`；Flutter/Android 工程位于 `app/` |
| 当前开发分支 | `agent/v04175-cedar-room-handoff-ledger-v2` |
| 当前目标版本 | `v0.41.75+219 / schema 61 / Snapshot protocol 6` |
| 当前状态 | `CI PASSED / APK READY / TRUE DEVICE PENDING` |
| 上一可安装基线 | `v0.41.74+218`，Actions run `34834400059` 全绿，`789/789` Flutter tests；APK SHA-256 `3a6cb3a64d0e0374799165fe4e23d03e5042c133d5dac7efcf8823b4a3ec2d86` |
| +218 构建提交 | 远端功能 head `3163aa6cfac80a14414baa8488950557f26a4245`；最终文档 head `b775d76f6366fb64028dbae552c4dd1d387736c4` |
| `main` | 仍是 v0.38.5 旧基线；不得作为 v0.41.x 后续开发起点，本批不合并 |
| +219 构建提交 | 远端功能 head `0295ceeeafe9e18f057b6f8f5d54a8dae8820ed2`；tree `3cf8a09813c135b8bce4e5b9a66381ba2a03f5cf` |
| 当前构建产物 | `AI-Companion-v0.41.75-219-Cedar-Agentic-Blind-Play-APK.apk`；SHA-256 `9e638816031900660cadd08ac5d5dc6f40955319ac261139f1ee619197114f1f` |

既有能力保护索引：Desire / Thought / Intent / Gate、Somatic 双通道、玩游 Key、普通聊天、沉浸房间、查手机、造梗来源、D6、Phase 2B、App 内 Agent 能力桥、Memory 2D、`fact_state / attention_state / recall_policy`、`spontaneous_salience`、`reminiscence/identity`、Skills、MCP、`【检查系统】`、中断灰显、Token 命中/缓存优化、Phase 3、Harness、`screen_observation.inspect`、Genie-TTS 四音色、schema 61 与 Snapshot protocol 6 均不得回归。

## 4. 当前任务：v0.41.75+219 Cedar 模型自主发现、盲玩隔离与总账 v2

### 用户目标

1. 不再把自然语言逐句补成固定正则与固定步骤。Cedar 作为常驻轻量游戏能力交给 DeepSeek：用户无需知道“Cedar”“游戏厅”“双弈”或目录 ID，例如只说“陪我下五子棋”，她也应自行判断是否调用实时目录、从 catalog 找到最相关游戏、读取玩家规则并按真实 Outcome 行动。
2. “完全交给她”指选择和规划由模型负责，不取消协议依赖、单动作串行、服务端权限、真实结果、终局和有界防空转。模型不能无限循环，也不能跳过 catalog/玩家指南去猜 game/action。
3. 游戏必须盲玩：不能打开 GitHub、源码或人类攻略；文字推理不能读取答案。允许参考当前聊天中用户给出的主意，以及她正常游玩已经获得的可见信息。
4. 修复 +218 真机中“双弈新房间根本没有查询”的 APK 路由问题，并避免再次围绕单个房间号或单个游戏打补丁。
5. 解决总账每次更新时页面卡住：冻结旧大文件，当前入口改为小型总账 v2，validator 同时校验当前入口和只读归档。

### 最新真机证据与责任归属

- 输入附件：`AI_Companion_Backup_2026-09-14T13-52-58.aibackup`、`ai_companion_diagnostics_2026-09-14T13-53-03-750657Z.txt`；仅在临时工作区取证，不纳入 Git。
- +218 旧双弈房间 `5JH5MDVT` 曾真实完成 `state / move / leave`，证明 Cedar duel 服务与 APK transport 在当时可工作。
- 新请求“来试试开一把双弈五子棋如何？”只执行了本机 `cedar_toy.manage_activity` 暂停钓鱼；现有有界循环把任何 proposal 当作本轮完成，未继续 `list/get_guide/play`。
- 随后的“我下好了”“进房间吧”“8LFUR2HK”各轮均为 `completed / 0 Cedar calls`。模型 reasoning 明确称当前没有五子棋工具，并用对白假装输入房间号。故“房间找不到”发生在 APK 出站前：该房间从未被 Cedar 查询，不能归因于 MCP 网站。
- 防沉迷与各游戏存档不是同一概念。Cedar 的连续游玩轮数是账号/平台级，可跨游戏累计；`rest` 是平台公共 action，是否允许小机自行重置由 Cedar 网站的人类 `allow_self_reset` 开关裁决。APK 不应因为 duel 指南没重复写 `rest` 而本地拦截。

### 已实现并经 CI 证明

1. 删除 +217 的“识别明确目录名后确定性拉指南”和“零调用专门重试”路径；不新增“五子棋→双弈”的本地别名或动作脚本。
2. Cedar 已配置时，普通模型轮只常驻一个轻量 `cedar_toy.list_games` 能力入口。模型从用户语义自行决定是否使用；一旦选择该入口，同一目标后续同时向她开放 `list_games / get_guide / play`，不再由 APK 逐阶段指定下一工具。服务端依赖和执行器真实性校验仍会拒绝“未列目录就猜 game、未读玩家指南就猜 action”。
3. Cedar 发现循环使用独立但有界的 6 个规划回合、10 次工具调用；其他 Agent 仍保持 3 回合、6 次。`rooms/actions/catalog/help/look/inventory/announcements` 等发现读取可继续同一用户目标；被动 `state/status/observe` 仍服从服务端 actor/next_call，不允许自旋。
4. 每轮 Cedar Outcome 后重新加载真实 catalog/session，使“列目录→选游戏→读指南→查房/建房/加入/行动”能在同一目标内自然推进。只要已经进入 Cedar 链，后续 `play` 不再因最初未命中本地关键词而被执行器拒绝。
5. 用户提出游戏请求时不把“去玩双弈”等文字误存成当前钓鱼建议；已选指南的 `guideReady` session 保持跨轮目标连续性。切换不删除旧 session。
6. 指南新增长期 `playerSafeGuide` 投影：移除 repository/source URL、GitHub/GitLab/Gitee 指针、明确 `攻略/解答/标准答案/谜底/剧透/walkthrough/solution` 字段或章节，同时保留规则、action、参数和玩家可见说明。旧 +218 session 在读取时自动迁移净化；同轮工具 Outcome 也使用净化版本，不能先泄露再入库。
7. 盲玩请求的本地快路径、模型工具定义和模型调用转换三处均排除 `public_web.search / image.find_and_save / image.web_send`；Cedar Skill 明确禁止通过外部网页、仓库或攻略补题。这个语义检测只承担信息隔离，不决定选择哪个游戏或执行什么动作。
8. 总账旧文件原文移至冻结归档，本文件成为轻量唯一当前入口；工作流新增 +219 专项 validator，并将旧版本 validator 的当前版本/分支合同推进到 +219。

### 验证与不得误报

- 必须通过 `git diff --check`、Python compileall、当前总账 v2、+219 专项以及 Actions 实际调用的全部历史 validator。
- 本机结果：`git diff --check`、workflow YAML、Python compileall、当前总账 v2、+219/+218/+217 专项和工作流中可在本机执行且不依赖私有恢复载荷/缺失编译器的 `96/96` validators 已通过。剩余 `validate_v0331_desktop_pet_source_parity.py` 与 `validate_current_chat_visual_stage.py` 依赖 Actions 才恢复的私有桌宠/LingChat 素材，`validate_manual_crypto_v26.py` 依赖本机不存在的 `kotlinc`；三项必须由干净 CI 证明。
- Actions run `34857965280`（run 873）全绿：源码/历史门、Kotlin/JVM、Flutter Analyze、`794/794` Flutter tests、arm64 Release、固定签名、私有资源恢复、checksum、Artifact 与 Draft 均通过。Signer SHA-256 `305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148`。
- Artifact `10354191268`，ZIP digest `633b1365eeebbb2434f71dc57484b1b977c4c0a9d723dac9de3c898e026eb02c`；Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-39855af0a12db43b0ab0`。自动化已通过不等于真机体验通过。
- 真机至少验证：`陪我下五子棋`、`来试试开一把双弈五子棋`、直接给新房间号三条路径；确认有真实 `list/get_guide/rooms/join/state/move` Outcome，零调用不得口头声称成功。
- 盲玩回归：要求她“去 GitHub 查攻略再玩”时不能获得公开搜索工具；已缓存含仓库 URL 的旧指南升级后不再进入 Prompt；文字推理只能依据玩家可见线索。
- 防沉迷回归：网站允许自重置时 `rest` 能真实出站，关闭时保留 Cedar 的真实拒绝；不得用平台 `rest` 绕过游戏自己的每日次数、剧情阶段或冷却。
- 自动化不等于真机通过；公开仓库开发审计不等于她运行时看过源码，也不等于 29 款服务器游戏逐局通关。

## 5. +218 已完成但仍需随 +219 回归的游戏厅能力

- 平台公共 `rest / announcements / vote` 已与单游戏指南解耦；账号级防沉迷和游戏原生次数分别服从 Cedar。
- 结构化 `your_turn`、合法动作、revision、next_call 与终局优先，避免双弈只读轮询空转。
- `pause / pause_and_release / resume` 是本机活动管理；“我暂时忙，你先玩别的”保留远端存档，不等于 `leave/resign`。明确退出/认输才调用远端离席动作。
- 游戏中文名来自实时 catalog；活动窗使用可展开多 session 面板，长名称省略但保留完整值，active session 主色边框、viewing session 容器底色区分。
- 后台自主选游只使用最多三条近期明确游戏建议作为弱信号；当前用户回合可直接参考聊天。建议不是命令，不覆盖 Desire、重复度、未完成状态和合法动作。
- 游戏房间短对白固定使用内部 DeepSeek；Gemini 失败兜底提示不得跨 session 或显示到无关板块。普通聊天和沉浸房间最终 Provider 合同不变。
- 全工具调用动作展示已由用户同意作为后续独立任务；本批不扩大到所有工具 UI，避免在 Cedar 修复未稳定时混入新的展示链改造。

## 6. 后续导航

| 优先级 | 条件 | 下一步 |
|---|---|---|
| P0 | +219 APK READY | 联合真机验证自然发现、房间加入/落子、盲玩隔离、防沉迷 rest、暂离恢复、中文面板与房间 DeepSeek |
| P1 | Cedar 真机主链通过 | 设计全工具动作展示，参考悬浮聊天框已有“正在做什么/哪里出错/下一步”表达，不直接暴露密钥、原始内部协议或冗长 JSON |
| P2 | 用户要求继续既有路线 | 从冻结归档顶部“当前任务完成后的后续导航”和 `app/docs/DOCUMENTATION_MAP.md` 定点恢复，不全文读取归档 |

## 7. 关键文件导航

- Cedar 模型入口与循环：`app/lib/core/ai/durable_generation_runner.dart`、`app/lib/core/agent/agent_tool_planner.dart`、`agent_task_loop.dart`、`agent_tool_runner.dart`
- Cedar 玩家协议与状态：`app/lib/core/mcp/cedar_toy_client.dart`、`cedar_toy_activity.dart`、`cedar_game_protocol.dart`、`cedar_toy_autonomy_engine.dart`、`cedar_toy_arcade_skill.dart`
- UI：`app/lib/features/chat/cedar_toy_activity_window.dart`
- 兼容审计：`app/docs/CEDAR_TOY_GAME_COMPATIBILITY_v0.41.74.md`
- 当前专项测试：`app/test/cedar_game_hall_protocol_v04174_test.dart`
- 当前专项门禁：`app/tools/validate_v04175_cedar_agentic_blind_play.py`
- 冻结历史：`app/docs/ledger/archive/AI_Companion_总账归档_截至_v0.41.74+218.md`
