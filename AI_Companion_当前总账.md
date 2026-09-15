# AI Companion · 当前总账

更新时间：2026-09-15（Asia/Tokyo）

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
| 当前开发分支 | `agent/v04182-cedar-state-machine-e2e` |
| 当前目标版本 | `v0.41.82+226 / schema 61 / Snapshot protocol 6` |
| 当前状态 | `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING` |
| 当前真机失败基线 | `v0.41.81+225`；Cedar 已成功建房并返回真实回合信息，但前台 `wait=true` 写请求先被 25 秒 MCP transport 判超时；后台动作规划超时不重试并退避，普通聊天页可见时又禁止 Cedar 续跑，形成“网站已成功、APK 卡住不动” |
| `main` | 仍是 v0.38.5 旧基线；不得作为 v0.41.x 后续开发起点，本批不合并 |
| +219 构建提交 | 远端功能 head `0295ceeeafe9e18f057b6f8f5d54a8dae8820ed2`；tree `3cf8a09813c135b8bce4e5b9a66381ba2a03f5cf` |
| +220 构建提交 | 远端功能 head `f3a4e95e35c5ca47fb68e84aa8d12a850cfbd91a`；tree `0efb121197441a2522f987a5b506e32dda53e555` |
| +221 构建提交 | 远端功能 head `bf4c8216235d067884bb2f5fa303d17eec8eb6a3`；tree `125c47730e7b5c37ab74af4721904db194742e75` |
| +222 构建提交 | 远端功能提交 `ccbe5bcbe9b3fc65941846f74aa4d95b6be50c7d`；授权提交/head `93fcb2fbbf78be80a5da9724fd6b051956e1ff34`；最终 tree `f167bdf6a16700333a978f5f6b99498fdfec3974` |
| +223 构建提交 | 远端功能提交 `2217a5021b9175cd612fadd45fa9b68a58b9ea24`；实现总账提交 `54ea75e50501fd27281cc4d985e76dabd8aca7d9`；构建触发 head `c90b60d5d456e5d30512a088592cf94f2ce4478f`；构建 tree `342d431730d6d3f0568b4e2525d8ab9b0e36a7c5` |
| +226 构建提交 | 权威状态机功能提交 `d1b3c0dcb45ac9aad1c808452bb3c8ce4c8ce4e5`；构建准备提交 `c37f02d6a2a06678ffc83cd493e296aadd2be22d`；最终构建 head `7fe5930f7776d6e2c69659b7ac3644b7255a65a1`；最终 tree `4fafd7c4fbf94b84b9d446d1a6565455fc654cb8` |
| 当前构建产物 | Actions run `34957849643`；Artifact `10392840422`（ZIP digest `e88cb2422f94f88f681003dc9ce3a91ac8631c14d3ef858815f5639bfebe8837`）；未发布 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-6fff0a6242b90c8e0f99`；APK SHA-256 `6ec8dddade41518e90af053c03bd500f64d3e8e5938807bf62ad6a366d6d804c` |

既有能力保护索引：Desire / Thought / Intent / Gate、Somatic 双通道、玩游 Key、普通聊天、沉浸房间、查手机、造梗来源、D6、Phase 2B、App 内 Agent 能力桥、Memory 2D、`fact_state / attention_state / recall_policy`、`spontaneous_salience`、`reminiscence/identity`、Skills、MCP、`【检查系统】`、中断灰显、Token 命中/缓存优化、Phase 3、Harness、`screen_observation.inspect`、Genie-TTS 四音色、schema 61 与 Snapshot protocol 6 均不得回归。

## 4. 当前任务：v0.41.82+226 Cedar 权威状态机端到端闭环

### +225 真机证据、上游协议与已确认结构根因

- 最新诊断显示 `active/multiplayer/nextActor=companion/lastAction=new`，Cedar 后台大脑健康、无在途 execution，但前台最后一次 `cedar_toy.play` 为 `cedar_network_or_timeout`；备份同时证明远端房间已经创建、网页落子和消息已经推进 revision，故障位于 APK 收到/等待回包后的状态出口，不是 Cedar 网站没有返回。
- CedarDuet 当前公开协议明确：`rooms → state → move` 可恢复房间；`state(wait=true)` 是 30 秒短心跳，`still_waiting` 需要续订；`revision` 与结构化回合状态是权威；普通房间消息在非本机回合不会单独唤醒小机，而会在真正轮到它时随可见 events 一并交付。
- APK 把 `new/move + wait=true` 的“写入”和“等待下一回合”耦合在同一个请求，而通用 MCP 客户端 25 秒先于 Cedar 30 秒心跳超时，所以远端已提交、本机却判失败。前台与后台在收到成功 Outcome 后还先等待一次非必要模型分类，导致权威状态迟迟不落库。
- 后台 planner 固定 30 秒且明确排除 timeout 重试，外层失败后又退避 5 分钟；普通聊天页只要可见（即使没有 chat writer lease）也会阻止 Cedar；Stop 的 SQL 又遗漏 `awaiting_confirmation`，一次卡住的回复可留下永久 blocking job，连聊天和备份一起封死。

### 本批实现与完成判据

1. 双弈普通 `new/join/move/...` 一律 `wait=false` 立即取得并持久化写结果；只有服务端签发或本机安全派生的只读 `state(wait=true)` 由后台观察器执行。Cedar 专用 transport 为 40 秒，完整接住上游 30 秒 heartbeat。
2. Cedar 结构化 `next_actor/revision/resume_after/next_call` 到达后直接作为控制状态落库，不再先等 DeepSeek 做第二次裁判；模型仍负责真正需要判断的动作选择和可选房间表达，不能覆盖服务端回合真值。
3. `new/move` 回包丢失时禁止原样重放：已有 room_id 只做 `state(full_state=true,wait=false)`，无 room_id 先做 `rooms`，再从唯一活跃房间建立只读 observer。成功 poll 返回 `your_turn=true` 时清除旧 wait continuation，随后由原生 `cedar_toy.play` 工具规划并落子。
4. 页面可见不再等同于聊天写入；只有真实 `chat_turn_lease` 抢占 Cedar。动作 lease 在长规划中周期续约且仍受 Active Brain、transfer freeze、双开关和 execution fence 中断。规划 timeout 允许一次 20 秒有界 fallback，失败 15 秒后重试，不再静默五分钟。
5. 夜间 00:00–07:00 在未主动观看时硬性睡眠到 07:00，强 Thought 不能让后台游戏整夜空转；主动观看仍可明确覆盖。关闭 Cedar 或自主游戏开关会原子暂停并 fence 当前执行，清除 next-action 时钟，远端存档保留。
6. Stop 可终止 `pending/running/retry_wait/awaiting_confirmation/failed` 任一未完成回复；真实 SQLite 测试证明幽灵 job 被删除为非阻塞状态后，普通备份 freeze 可以立即取得。
7. 新测试不是源码字符串：使用 `sqflite_common_ffi` 打开真实 AppDatabase schema，并以 fake DeepSeek 原生 tool-call + fake MCP 完成 `new → 她落子 → state 长轮询 → 网页落子/消息 → 她再次自动落子`；同时断言写操作永不携带 long-poll、服务端结构化状态不触发第二次模型等待、开关关闭清时钟、写超时只读同步和 Stop/备份互锁。
8. 本机没有 Flutter/Dart SDK；提交前 `git diff --check` 与 +211～+225 Cedar 专项 Python 门已通过。Actions run `34957849643`（run 889）随后全绿：源码与历史门、Kotlin/JVM、Flutter Analyze、全量 Flutter tests、arm64 Release、固定签名、Genie/桌宠/LingChat/塔罗载荷、checksum、Artifact 与未发布 Draft 均成功。Artifact `10392840422`，ZIP digest `e88cb2422f94f88f681003dc9ce3a91ac8631c14d3ef858815f5639bfebe8837`；Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-6fff0a6242b90c8e0f99`；APK SHA-256 `6ec8dddade41518e90af053c03bd500f64d3e8e5938807bf62ad6a366d6d804c`。当前严格为 `CI PASSED / APK READY / TRUE DEVICE PENDING`，自动化端到端通过不等于真机已经修好。

## 5. 上一基线：v0.41.81+225 Cedar 后台原生 Agent 工具闭环

### +224 真机证据与已确认根因

- 同时刻诊断与备份证明 Cedar 房间、身份绑定、长轮询、房间消息、revision 和回合识别都已工作：活动 session 为 `active/multiplayer`，`next_actor=companion`，最近一次 `state` Outcome 明确 `your_turn=true`，且待回复房间消息已经进入本机。
- 该次成功 `state` 后没有任何 `move` 事件。约 18 秒后记录 `empty_model_content`，再约 2.6 秒 session 被写成“15 秒后继续”，精确命中后台 `invalid_action_choice / read_only_loop_blocked` 分支；累计 `jsonRetryCount=58`。
- 代码确认前台用户轮通过 `DeepSeekClient.streamChat(tools: ...)` 与原生 Agent tool-call 规划；后台 `_advanceSessionLocked` 却仍调用 `_judge → jsonCompletion`，让模型以自由 JSON 填 `action/params`。+224 只共享了 Prompt、Gate 和部分循环条件，并没有共享真实工具规划通道。这就是“看到轮到她但不落子、每 15 秒转一次”的直接结构断点。

### 本批实现与完成判据

1. 后台可执行动作改由 `CedarAgentActionPlanner` 通过前台同源的 `AgentToolPlanner.nativeToolDefinitionsFor` 获取唯一 `cedar_toy.play` schema，并以 `tool_choice=required` 请求原生函数调用；自然语言正文、空正文和自由 JSON 一律不能授权动作。
2. 工具 schema 把 `game` 锁定为当前 session ID；返回必须恰好一个 `cedar_toy_play`，且 action 在完整指南或公共平台动作中、params 为 JSON object。错误游戏、错误工具、损坏参数或未调用工具均拒绝。
3. 当服务端已经显示 `next_actor=companion` 且上一动作是只读查询时，新的只读 action 在本地立即拒绝；允许一次带具体拒绝原因的 non-thinking 工具重规划。第二次仍失败则抛出分类错误，由既有执行外层清除 execution fence、释放狭义 Cedar lease 并延后，不得无限占住聊天、备份或其他游戏。
4. 结果分类、房间短对白和目录偏好等非执行判断可以继续使用 JSON/文本通道；只有“下一步要执行什么”强制走工具调用。本批不重写停止/备份互锁、夜间 Desire/Thought Gate、服务端 `next_call` 权威、写入不确定同步或游戏厅双开关。
5. 新固定测试覆盖：正文为空但存在原生工具调用仍成功；首次重复 `state` 后第二次 `move`；错误游戏 ID 纠正；连续两次无效动作有界失败；供应商把 `params_json` 返回 object 时的防御解析。诊断新增 `agentActionRetryCount / LastCategory / LastAt`，不记录房间号、消息或参数。
6. 本地功能/封装提交为 `83c3234 / cc3ff0f`；远端等价功能/封装提交为 `99b9de8 / d237873`，最终源码 tree 与本地精确同为 `6cf01e86f60b821fdef4d2f3217bb234370d77a0`。本机无 Flutter/Dart SDK，提交前 `git diff --check`、Python 语法、Workflow YAML、当前总账门和 +215～+225 Cedar 专项门通过；当时仍为 `CI PENDING / TRUE DEVICE PENDING`。
7. Actions run `34942815929` 全绿：完整源码/历史门、Kotlin/JVM、Flutter Analyze、`821` 项 Flutter tests、arm64 Release、固定签名、Genie/桌宠/LingChat/塔罗载荷、checksum、Artifact 与未发布 Draft 均通过。Signer SHA-256 `305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148`；Artifact `10386601803`（ZIP digest `d9c7296525ad8a8526fdb11e421cb608acf060ced6732631d2170ab77b1375ad`）；Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-c67e2101abe1e5aa26e9`；APK SHA-256 `921c7df125c57a208a67b21aee5401ba9c54ab6937aa1843d96300d8d2dac1f3`。当前严格为 `CI PASSED / APK READY / TRUE DEVICE PENDING`，需真机证明网页落子后她无需 APK 催促即可连续接招；不得把自动化通过写成真机已经修好。

## 5. 上一基线：v0.41.80+224 Cedar Agent 完整续接链

### 已确认的跨层根因

- 前台用户回合与后台游戏厅各有一套停止条件、参与模式和续接门禁；“给 Agent 权限”进入模型后，仍会被本地重复分类和单步关环覆盖。
- `list_games/get_guide` 的机器动作曾被中文展示名替代，发现动作无法可靠继续；一次 `play` 又被通用 proposal 规则直接当成整项任务完成。
- Cedar 已签发 `next_call` 后，本地仍要求精简指南重复动作名并重新猜 participation mode，导致真实房间的服务端续接被 APK 自己否决。
- 刷新指南会重建 session，把 active/waiting/paused、next_actor、next_call、房间消息和别名重置成 guideReady；停止若发生在远端写回之后、本机落状态之前，也会丢掉已知 Outcome。
- 真机 +222 备份显示 fishing 为 `active/solo/companion`、后台 JSON 重试 14 次且最后超时 120 秒，duel 已是 `completed/leave`；这是钓鱼持续转圈并挤占系统、下棋提前结束的直接状态证据。

### 本批实现与完成判据

1. `CedarAgentLoopPolicy` 统一前台停止合同：目录、指南、发现查询和 `next_actor=companion` 均继续同一个用户目标；只有服务端交给用户/远端、终局、不可恢复写入不确定或 10 轮/16 调用硬预算才收尾。
2. 每个真实 Cedar 阶段允许一次零调用复核，并在每次 Outcome 后重新注入最新 catalog、完整指南、实时玩家 schema 与 session；保留真实 machine action，中文仅作展示。
3. `next_call` 的精确 action/params 视为 Cedar 服务端续接能力，不再由 participation_mode、旧邀请标记或精简指南二次否决；普通“我们下棋，你建房，我加入”直接构成共玩许可。
4. 前台写超时进入“结果未知/同步”而不击穿整条聊天；远端 Outcome 已返回时必须先保存 next_actor/next_call/消息去重与别名，再响应停止或前台抢占，且绝不重放写动作。
5. 再读指南只更新元数据，保留已有房间状态。后台与前台共用同一 Cedar Skill 和服务端续接权威；夜间竞争、双开关暂停、狭义动作锁、备份冻结和全局聊天抢占继续沿用 +223。
6. 新固定脚本测试覆盖“目录→指南→建房/加入→服务端挂等→用户网页落子/发言→她自动落子/回话”的停止合同、服务端续接、许可识别和可恢复门禁；CI 还必须跑全部历史门、Analyze、Flutter tests、Kotlin/JVM、arm64 Release、签名与 Draft。
7. 用户补充的“花园与猫停在等待游戏、无动作且不再切换”已定位为另一条同源死锁：`waiting_remote + next_actor=wait` 在既无 `next_call` 也无唤醒时间时，不归续跑时钟接管，却被新游戏可用性永久视为占用。本批在 Outcome 落库边界直接暂存远端进度并释放活动位，同时为旧存档增加恢复停放；有明确服务端续接或定时的等待不受影响。
8. 首次 Actions run `34924279335` 在源码门提前失败：历史 `validate_v04172_cedar_trust_watch_modes.py` 仍把 MCP 客户端版本固定为 `0.41.79`，尚未进入 Flutter 编译/测试；该合同已更新为 `0.41.80`。本地 `git diff --check`、workflow YAML、Python compileall、+224 专项门及工作流中可本机执行的 `101/101` validators 已通过；余下 3 项依赖 CI 私有素材或缺失编译器，Analyze、Flutter tests、Kotlin/JVM、arm64 Release、签名与 Draft 均等待重新运行证明。
9. 第二次 Actions run `34925158591` 已通过完整源码门，但 Kotlin/JVM 步骤触发 Flutter debug 编译后发现两处确定性类型错误：统一循环仍引用已移除的 `verifiedContinuation`，以及可变 nullable session 跨闭包失去类型提升。前者已改为本轮真实 Cedar 结果的 continuation 汇总，后者在空/终局分支返回后固定非空 activeSession；需重新运行 CI 证明编译与后续全链。
10. 第三次 Actions run `34925717983` 全绿：完整源码/历史门、Kotlin/JVM、Flutter Analyze、`816/816` Flutter tests、arm64 Release、固定签名、Genie/桌宠/塔罗载荷、checksum、Artifact 与未发布 Draft 均通过。Artifact `10379647780`（ZIP digest `5539fbeaff65cabaa66a9a2e0f369f9d1c94452683d4cc8ccae82af413b5e8aa`）；Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-c9a13c9a99a54cb6df4c`；APK SHA-256 `dada0ff780f3a704a01af4b9cae94a8cd9b8ce13f4a5055aa570a459c69ff5bc`。当前严格为 `CI PASSED / APK READY / TRUE DEVICE PENDING`，仍需真机证明“建房→网页加入/发言/落子→她自动接招”和“无路由等待释放”体验。

## 5. 上一自动化基线：v0.41.79+223 Cedar 运行时抢占、开关与夜间节律

### 真机证据与确定根因

- 最新同时刻诊断 `ai_companion_diagnostics_2026-09-14T20-59-35-975006Z.txt` 与真机截图相互印证：当时没有活跃 chat job，`chat_turn_lease=false`，但 `recovery_orchestrator_lease_until` 处于 running，Cedar 活动状态一直是“规划下一步 / fishing”。因此不是 NSFW、主聊天网络或 UI 动画本身卡住。
- Cedar `_judge` 的单次请求可等 120 秒，超时后又被当成瞬态故障立即重试；整个网络等待同时持有六分钟恢复器全局写租约。这正好解释“钓鱼永远转圈、聊天/备份/恢复全部像死机”。
- 原实现只在启动后台 Cedar 前检查开关，没有在请求期间监视关闭、前台聊天或备份冻结；迟到的远端结果还能把已暂停状态覆盖回“正在执行”。
- 04:40 诊断中疲劳已为 `0.74`，但已承诺的 Cedar session 绕过 Desire/Thought 竞争直接续步；所以原先“夜间依思考、疲劳和困意降低频率、优先睡觉”只管到选游戏，没有管到正在玩的游戏。

### 本批实现与完成判据

1. Cedar 网络调用改为独立 30 秒上限；provider 超时不在同一轮再试一次。空/损坏 JSON 和 429/5xx 仍保留最多一次改变策略的窄重试。
2. 每次 Cedar 动作使用独立 `executionId` 与 SQLite 原子 fence。请求期间每 200 ms 观察 Active Brain/transfer freeze、主/自主开关、前台 `chat_turn_lease` 与 fence；触发后立即关闭 HTTP，迟到结果无权写回。升级或恢复遇到旧执行动画也会自动判为孤儿状态清理。
3. `RecoveryOrchestrator` 在 Cedar 网络等待前释放全局恢复器租约，只留 `cedar_toy_action_lease_until` 这一狭义动作锁。聊天可直接取得前台租约并抢占 Cedar；备份/恢复冻结会中断 Cedar，等狭义锁退出后再制作快照。
4. 关闭“Cedar Toy”或“允许她自主玩”任一开关都会原子暂停当前 session、清除执行动画、保留远端存档；只有两个开关都再开启时，才自动恢复“因开关而暂停”的游戏，不会擅自恢复用户手动暂停的对局。
5. 已承诺 session 续步前也进入与 Desire Core 同源的疲劳/休息竞争，叠加本局 Thought 强度和用户是否在观看。例如 04:40、疲劳 0.74、无强烈玩游戏念头时至少延后 45 分钟；进度不删除，真正强烈的念头仍可胜出。
6. 新固定测试覆盖夜间休息胜出、强 Thought 例外、阻塞 Cedar JSON 立即取消、超时不同轮重试、执行代号序列化与源码跨模块合同。自动化通过后仍为 `TRUE DEVICE PENDING`。
7. 本地 `git diff --check`、workflow YAML、Python compileall、当前总账门与 +215—+223 Cedar/Stop 专项门通过；Actions 实际列出的 103 个源码门本地通过 100 个。剩余 3 个分别依赖 CI 恢复的 417 文件桌宠资源、LingChat 私有资源和本机不存在的 `kotlinc`；本机同样没有 Flutter/Dart，因此 Analyze、Flutter tests、Kotlin/JVM、arm64 Release 和签名必须由 Actions 证明。
8. Actions run `34901268674`（run 878）全绿：CI 恢复私有资源后 `103/103` 源码/历史门、Kotlin/JVM、Flutter Analyze、`810/810` Flutter tests、arm64 Release、固定签名、载荷完整性、checksum、Artifact 与 Draft 全部通过。Signer SHA-256 `305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148`。
9. Artifact `10370718232`，ZIP digest `b229a85ed25e5a18b41e19f30e5d641278277463b694c6876022a3ae33b107e2`；未发布 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-b128b3cec07cc4161679`。APK 本体 SHA-256 `4ae81e27c5787171649e2dcdadf9c8a298335fc48b8136cda6e97ed2607cae2b`。当前只到 `CI PASSED / APK READY / TRUE DEVICE PENDING`，不得把自动化通过写成真机故障已经消失。

## 5. 上一已完成基线：v0.41.78+222 停止与备份互锁

- 两个 +222 提交位于 `agent/v04178-stop-transfer-interlock`。Actions run `34892223932`（run 876）全绿，`805/805` Flutter tests、arm64 Release、固定签名、Artifact 和 Draft 均通过。
- Artifact `10367902104`，Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-70f3bfb17381ac00cd4f`，APK SHA-256 `5034db229522d55882bdc62a5bc0c097bd9145cdda178bf8befbc032dbf80bf8`。+222 修复了跨 FlutterEngine Stop 与 `transfer_lock_owner` owned freeze，但最新真机证明 Cedar 自己的长网络等待仍可饿饿全局系统。

## 5. 上一已完成基线：v0.41.77+221 Cedar 后台换手闭环

### 新真机证据与已证实根因

- 根因已由同一时刻备份、诊断与源码三方证明；以下链路不是概率推断。
- 输入附件：`AI_Companion_Backup_2026-09-14T17-21-26(1).aibackup`、`ai_companion_diagnostics_2026-09-14T17-21-30-335220Z(1).txt`，仅用于临时取证，不进入 Git。
- 房间 `NDNSYLER` 的长轮询已成功取得网页用户消息和落子；服务端真实返回 `revision=4 / your_turn=true`，本地也正确保存 `next_actor=companion / continuation_pending=true / pending_room_message=true`。因此网页、绑定身份、房间、长轮询和回合判定均不是本次断点。
- 紧接着后台规划在 `DeepSeekClient.jsonCompletion` 对空 `message.content` 直接执行 `jsonDecode`，留下原始错误 `FormatException: Unexpected end of input (at character 1)`。+220 的两次请求完全相同，诊断累计 `jsonRetryCount=8` 后仍失败；规划未产出 action/params，所以既不落子也不把待回复房间消息随动作发回。主聊天的 Agent 路径仍可落子，因而形成“只有在 APK 内逐步催促才继续”的表象。
- +220 测试只证明 `FormatException` 属于可重试错误，没有模拟思考响应 `reasoning_content` 非空但 `content` 为空，也没有覆盖“网页发言并落子 → 长轮询 → 后台规划 → 房间回复与合法落子”的完整换手链。这是 CI 全绿仍漏报的原因。

### 本批实现边界与完成判据

1. Cedar 后台 JSON 决策必须为短小结构化任务保留足够正文预算；空正文不得直接交给 `jsonDecode`，错误需要携带脱敏类别而不记录推理或房间正文。
2. 窄重试仍最多一次，但第二次必须改变请求：关闭高强度思考、增加正文预算并明确要求立刻输出 JSON；不得原样重复同一失败请求。
3. `your_turn=true` 与待回复房间消息恢复后，下一次后台 tick 必须选出真实 action/params，房间对白只随将要提交的合法动作发送；不得写死房间号、五子棋落点或棋类策略。
4. 保留 +220 玩家协议缓存、盲玩隔离、真实 action 名、DeepSeek 内部调用单通道、单动作串行和服务端结构化回合真值；不扩大到全工具 UI。
5. 固定测试至少覆盖：空正文检测；第二次请求策略不同；稳定 401/403 不重试；模拟网页消息与 `your_turn=true` 后进入动作规划；生成的房间 `message` 与合法 `move` 同次提交。完成后跑全量 validators、Flutter analyze/tests、arm64 Release、签名、Artifact 与 Draft；自动化通过仍标记 `TRUE DEVICE PENDING`。

### 当前实现与验证

- `DeepSeekClient.jsonCompletion` 现在把成功 HTTP 响应中的空/缺失正文识别为不携带 Prompt、推理或房间内容的 `EmptyJsonCompletionException`，并把非 object 的 choice/message/JSON 正文统一收敛为格式错误；脱敏诊断分类为 `empty_model_content` 或 `malformed_model_json`。
- `CedarJsonDecisionExecutor` 取代 `_judge` 内的原样循环：第一次使用 high thinking 与 2400 token 保留棋局判断能力；仅在空/损坏 JSON 或瞬时网络、429/5xx 时重试一次，第二次切到 non-thinking/low/1400 token 并追加立即输出完整 JSON 的恢复指令；401/403 不重试。
- 共玩动作通过 `CedarRoomActionPayload` 把已生成短对白复制进将提交的同一 params，不改变 move/revision/wait；主聊天结果将真实 `new/join/state/move` 作为机器 Prompt action，同时保留中文“游玩”展示词。恢复循环成功后清除旧 `cedar_toy_last_continuation_error`。
- 新增真实失败形状测试：第一次响应只有 `reasoning_content` 且 `content=""`，第二次必须以不同请求产出 `move` JSON；另覆盖 401 单次失败，以及 `your_turn=true + pending room message` 的 session 仍可行动、对白与 move 同 payload。`git diff --check`、workflow YAML、Python compileall、+221 专项及 Actions 当前源码门中本机可执行的 `98/98` validators 已通过；另 3 项依赖 Actions 恢复的私有桌宠/LingChat 载荷或本机不存在的 `kotlinc`。本机无 Flutter/Dart，编译、Analyze、全量 Flutter tests、arm64 APK 与签名必须由 CI 证明。
- 用户已明确授权把 +221 两个提交推送到公开仓库的 `agent/v04177-cedar-background-turn-loop`，功能 tree 与本地 `f1712da` 完全一致；远端构建功能 head 为 `bf4c8216235d067884bb2f5fa303d17eec8eb6a3`。
- Actions run `34882529012`（run 875）全绿：源码/历史门、Kotlin/JVM、Flutter Analyze、`801/801` Flutter tests、arm64 Release、固定签名、私有资源恢复与完整性检查、checksum、Artifact 和 Draft 均通过。Signer SHA-256 `305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148`。
- Artifact `10363514027`，ZIP digest `e114c7ea5f0e0e312e3937c88933fbc475d48ad37570ccdb4b15abf0614eee16`；Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-ebb3a7c0512aee5ca374`。APK SHA-256 `6d74a7c622a80f0d57a97b94249a4ac0cd6f17a3102c6084cd2d22e9eefb9270`。当前为 `CI PASSED / APK READY / TRUE DEVICE PENDING`；自动化通过不等于网页换手体验已获真机证明。

## 5. 已完成但真机失败基线：v0.41.76+220 Cedar 玩家协议与后台连续行动收口

### 新真机证据与根因

- 输入附件：`AI_Companion_Backup_2026-09-14T15-16-48.aibackup`、`ai_companion_diagnostics_2026-09-14T15-16-51-222859Z.txt`，仅用于临时取证，不进入 Git。
- +219 已明显改善自然发现：用户说“游戏厅的五子棋”后，真实完成 `list_games / get_guide / rooms`；用户建立新房后又真实完成 `rooms / state / move`，revision 从 1 推进到 5。故 Cedar 双弈房间服务与 APK transport 均可工作。
- 建房仍失败：模型已经判断下一步应调用 `new`，但 Cedar 玩家指南只写“new 开房”，没有给出精确参数签名；模型又误以为工具额度耗尽，结束成对白。远端公开玩家协议显示开房需要 `game_type / mode` 等参数。这是“上游玩家指南不完整 + APK 无调用时过早关环”的组合问题，不是房间服务拒绝。
- 连续行动仍失败：长轮询已经取得用户的新落子与房间消息，本地状态为 `next_actor=companion / continuation_pending=true / pending_room_message=true`；紧接着后台 `_judge` 收到空 JSON 正文并抛出 `FormatException: Unexpected end of input`。现有单次 JSON 规划不重试，导致行动与房间对白留在队列，只有下一条主聊天消息再次驱动。

### 本批实现边界

1. 不写死房间号、五子棋落点或棋类策略。Cedar `tools/list` 中 `play` 的实时玩家操作 schema 必须经盲玩净化后缓存并与游戏指南一起提供给 DeepSeek；只提供参数签名，不提供 GitHub、源码、人类攻略、答案或隐藏状态。
2. 若实时 schema 暂时缺少双弈建房签名，允许加入经开发审计确认的最小玩家协议契约（`new` 的参数名/类型），但不得规定开局策略或替模型选择落点。模型仍自行选择游戏、模式和行动。
3. Cedar 发现结果声明应继续规划、用户目标尚无真实写入 Outcome、且总预算仍充足时，模型无调用不得直接关环；给一次明确剩余预算的内部完成度复核。仍无调用则如实收尾，禁止说“正在建房”。
4. 后台 Cedar JSON 规划遇空正文、格式不完整或瞬时 429/5xx 时窄重试一次；权限、配置和稳定 4xx 不重试。成功取得对方事件并确认 `next_actor=companion` 后，应在下一 tick 自行规划并落子，不依赖主聊天提醒。
5. 保持 +219 盲玩隔离、+218 防沉迷公共 `rest`、暂离恢复、中文面板、房间 DeepSeek 单通道、schema 61 与 Snapshot protocol 6；全工具动作展示仍是后续独立任务。

### 完成判据

- 固定测试覆盖：实时玩家 schema 的净化/缓存；“发现后无调用”一次复核且有界；空 JSON 第一次失败第二次成功；稳定 401/403 不重试；收到 `your_turn:true + pending room message` 后进入动作规划而非停在队列。
- CI 必须通过全部历史门、Kotlin/JVM、Flutter Analyze/tests、arm64 Release、固定签名、Artifact 与 Draft。真机需再次验证她自己建房、用户建房后无主聊天提醒连续落子、房间对白随同下一次合法动作发出。

### 本地实现与验证

- `CedarToyClient` 现在只从 MCP `tools/list` 选取 `play` 描述与 input schema，经现有盲玩净化后保存到新的 `cedar_toy_play_protocol_v2`；不保存或暴露其他工具、输出 schema、仓库、攻略或隐藏状态。用户首次列目录即可取得，后续用户回合与后台连续规划共同复用。
- `CedarPlayerProtocolContract` 仅对当前已证实遗漏参数的 duel `new` 补充玩家动作签名：`game_type / mode / stake / target_player_count / fill_with_npcs`。它不包含房间号、对手身份、棋谱、落点或胜负策略，所有实际值仍由实时 catalog、用户意图和模型决定。
- 用户回合在发现类 Outcome 后若第一次无调用，会在剩余总预算内进行至多一次目标完成度复核；次数写入脱敏诊断 `noCallRecheckCount`。后台 `_judge` 对空/损坏 JSON 或 429/5xx 至多重试一次，401/403 不重试；次数和错误类别写入脱敏诊断，但不写房间正文、参数或身份。
- `git diff --check`、workflow YAML、Python compileall、+220/+219/+218/+217/+215 专项及 Actions 当前源码门中本机可执行的 `97/97` validators 已通过。另 3 项依赖 Actions 恢复的私有桌宠/LingChat 载荷或本机不存在的 `kotlinc`；本机同样没有 Dart/Flutter，必须由 CI 证明编译、测试和 APK。
- Actions run `34866765746`（run 874）全绿：源码/历史门、Kotlin/JVM、Flutter Analyze、`798/798` Flutter tests、arm64 Release、固定签名、私有资源恢复、checksum、Artifact 与 Draft 均通过。Signer SHA-256 `305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148`。
- Artifact `10357153245`，ZIP digest `e465865a8d8f38c79d7bf7c820442a6def710d1b36fe7bb2de564819e122411b`；Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-390da0c4ad01f6d108aa`。自动化已通过不等于真机体验通过。

## 5. 已完成基线：v0.41.75+219 Cedar 模型自主发现、盲玩隔离与总账 v2

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

## 6. +218 已完成但仍需随 +220 回归的游戏厅能力

- 平台公共 `rest / announcements / vote` 已与单游戏指南解耦；账号级防沉迷和游戏原生次数分别服从 Cedar。
- 结构化 `your_turn`、合法动作、revision、next_call 与终局优先，避免双弈只读轮询空转。
- `pause / pause_and_release / resume` 是本机活动管理；“我暂时忙，你先玩别的”保留远端存档，不等于 `leave/resign`。明确退出/认输才调用远端离席动作。
- 游戏中文名来自实时 catalog；活动窗使用可展开多 session 面板，长名称省略但保留完整值，active session 主色边框、viewing session 容器底色区分。
- 后台自主选游只使用最多三条近期明确游戏建议作为弱信号；当前用户回合可直接参考聊天。建议不是命令，不覆盖 Desire、重复度、未完成状态和合法动作。
- 游戏房间短对白固定使用内部 DeepSeek；Gemini 失败兜底提示不得跨 session 或显示到无关板块。普通聊天和沉浸房间最终 Provider 合同不变。
- 全工具调用动作展示已由用户同意作为后续独立任务；本批不扩大到所有工具 UI，避免在 Cedar 修复未稳定时混入新的展示链改造。

## 7. 后续导航

| 优先级 | 条件 | 下一步 |
|---|---|---|
| P0 | 安装 +226 Draft APK | 验证 `new/join/move` 写入后立即落库；在 Cedar 网页落子并发房间消息后，不在 APK 内催促，确认她能经后台观察器自动接招并回复 |
| P1 | +226 连续换手通过 | 在 Cedar 正在规划时分别关闭两个开关、发普通聊天、保存/恢复备份；确认规划立即退出、无迟到写回且普通聊天与备份不再被拖死；另验证 00:00–07:00 未主动观看时休眠、主动观看可覆盖 |
| P2 | 用户要求继续既有路线 | 从冻结归档顶部“当前任务完成后的后续导航”和 `app/docs/DOCUMENTATION_MAP.md` 定点恢复，不全文读取归档 |

## 8. 关键文件导航

- Cedar 模型入口与循环：`app/lib/core/ai/durable_generation_runner.dart`、`app/lib/core/agent/agent_tool_planner.dart`、`agent_task_loop.dart`、`agent_tool_runner.dart`
- Cedar 玩家协议与状态：`app/lib/core/mcp/cedar_toy_client.dart`、`cedar_toy_activity.dart`、`cedar_game_protocol.dart`、`cedar_toy_autonomy_engine.dart`、`cedar_toy_arcade_skill.dart`
- UI：`app/lib/features/chat/cedar_toy_activity_window.dart`
- 停止与跨引擎生成：`app/lib/features/chat/chat_controller.dart`、`app/lib/core/ai/durable_generation_runner.dart`、`deepseek_client.dart`、`durable_generation_recovery.dart`
- 备份冻结与诊断：`app/lib/features/transfer/transfer_page.dart`、`app/lib/core/database/app_database.dart`、`app/lib/core/sync/snapshot_service.dart`、`app/lib/core/diagnostics/preflight_diagnostics.dart`
- 兼容审计：`app/docs/CEDAR_TOY_GAME_COMPATIBILITY_v0.41.74.md`
- 当前专项测试：`app/test/cedar_game_hall_protocol_v04174_test.dart`
- 当前专项测试与门禁：`app/test/stop_transfer_interlock_v04178_test.dart`、`app/tools/validate_v04178_stop_transfer_interlock.py`
- 冻结历史：`app/docs/ledger/archive/AI_Companion_总账归档_截至_v0.41.74+218.md`
