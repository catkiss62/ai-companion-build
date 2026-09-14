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
| 当前开发分支 | `agent/v04178-stop-transfer-interlock` |
| 当前目标版本 | `v0.41.78+222 / schema 61 / Snapshot protocol 6` |
| 当前状态 | `IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING` |
| 当前真机失败基线 | `v0.41.77+221`；停止“正在回复”后旧后台请求仍占写入租约，聊天、保存和恢复可一起被阻塞 |
| `main` | 仍是 v0.38.5 旧基线；不得作为 v0.41.x 后续开发起点，本批不合并 |
| +219 构建提交 | 远端功能 head `0295ceeeafe9e18f057b6f8f5d54a8dae8820ed2`；tree `3cf8a09813c135b8bce4e5b9a66381ba2a03f5cf` |
| +220 构建提交 | 远端功能 head `f3a4e95e35c5ca47fb68e84aa8d12a850cfbd91a`；tree `0efb121197441a2522f987a5b506e32dda53e555` |
| +221 构建提交 | 远端功能 head `bf4c8216235d067884bb2f5fa303d17eec8eb6a3`；tree `125c47730e7b5c37ab74af4721904db194742e75` |
| 上一构建产物 | `AI-Companion-v0.41.77-221-Cedar-Background-Turn-Loop-APK.apk`；SHA-256 `6d74a7c622a80f0d57a97b94249a4ac0cd6f17a3102c6084cd2d22e9eefb9270` |

既有能力保护索引：Desire / Thought / Intent / Gate、Somatic 双通道、玩游 Key、普通聊天、沉浸房间、查手机、造梗来源、D6、Phase 2B、App 内 Agent 能力桥、Memory 2D、`fact_state / attention_state / recall_policy`、`spontaneous_salience`、`reminiscence/identity`、Skills、MCP、`【检查系统】`、中断灰显、Token 命中/缓存优化、Phase 3、Harness、`screen_observation.inspect`、Genie-TTS 四音色、schema 61 与 Snapshot protocol 6 均不得回归。

## 4. 当前任务：v0.41.78+222 停止与备份互锁

### 真机证据与确定根因

- 输入诊断：`ai_companion_diagnostics_2026-09-14T19-26-44-504222Z.txt` 与 `ai_companion_diagnostics_2026-09-14T19-36-04-931983Z.txt`；输入备份仅在临时工作区校验，不进入 Git。旧备份 ZIP、32 个条目及其 31 个声明 SHA-256 均通过，因此“不能读档”不是备份文件损坏。
- 两份诊断的 `stateGeneration` 从 144 变为 145，同时中断展示数从 22 回到旧备份中的 20；结合恢复算法 `max(local, backup)+1`，证明期间至少有一次恢复真实成功。19:36 诊断生成早于 03:38 的失败提示，不能拿其空闲快照否定恢复时仍有写入者。
- 停止键原先只把 SQLite generation job 标成 `cancelled_by_user` 并取消当前 FlutterEngine 的内存 token。若回复已由后台 FlutterEngine 恢复，前台拿不到其 token；后台 runner 也没有 token，只在收到下一段 SSE 时复查数据库。Provider 卡住且不再发 delta 时，UI 看似已停止，HTTP 仍可活到 120 秒超时并继续持有 `chat_turn_lease`。
- 后台 `RecoveryOrchestrator` 可在 Cedar/Memory JSON 网络调用期间持有 `recovery_orchestrator_lease_until` 六分钟；普通备份/恢复只等写入者 90 秒。原后台 `DeepSeekClient` 不观察 `transfer_lock`，所以冻结无法中断网络等待，90 秒报错是必然并发结果，不是正常导出耗时。
- 普通备份使用无所有者的全局 `transfer_lock=0/1`。旧页面或旧异步操作的 `finally` 能在新操作已置 1 后再写回 0，随后 `SnapshotService` 的内部锁检查就会报“创建普通备份前必须先冻结本机写入”。这是确定的旧操作误解锁新操作竞态。

### 本批实现与完成判据

1. `DurableGenerationRunner` 每 250 ms 读取 durable job 状态；跨 FlutterEngine 看见 `cancelled_by_user` 后立即取消有效 token并关闭专属 stream/JSON HTTP client，不再依赖下一段 SSE。停止按钮最长等待 5 秒确认 `chat_turn_lease` 真正释放；若极端情况下仍未退出，明确提示尚未停止完成，不再假装成功。
2. 后台 `DeepSeekClient` 增加 runtime gate。备份/恢复置锁后，后台 stream 与 JSON 请求立即关闭；这是运行时暂停，不冒充用户停止，也不删除待恢复用户轮。Cedar Outcome 核验与 NSFW 路由沿同一取消边界传播，不在冻结后继续写状态。
3. 普通保存/恢复改用 `transfer_lock_owner` 所有权 token。只有持有同一 token 的操作才能验锁和解锁；旧页面的迟到 `finally` 无法清掉新锁。ZIP 按状态与媒体哈希清单生成后先解冻，再打开系统保存页；用户选定位置后由 Android 独立执行 portable-ZIP、源/目标字节与 SHA-256 复核。删除了保存框之前重复的一次完整解包/哈希，并增加“冻结→整理生成→打开保存位置”阶段提示，既保留最终完整性边界，也避免无反馈地重复扫描几十 MiB。
4. 脱敏诊断新增全部状态写入 lease 的 held/到期元数据与具体阻塞项，不包含 lease owner token、聊天正文、房间消息或凭据。新测试模拟永不返回的 HTTP 请求，验证用户 Stop 和 transfer freeze 都会在 2 秒内关闭它，并加入源码合同测试覆盖 durable poll、owned freeze 和停止等待。
5. `git diff --check`、workflow YAML、Python compileall、当前总账门、+222/+221/+220 Cedar 与 Stop 专项门均通过；Actions 当前源码门中本机可执行的 `99/99` validators 通过。另 3 项依赖 Actions 恢复的私有桌宠/LingChat 载荷或本机不存在的 `kotlinc`。本地无 Flutter/Dart，必须由 CI 完成 Analyze、全量 Flutter tests、arm64 Release、签名、Artifact 与未发布 Draft。当前尚未推送；用户对 +221 分支的公开推送授权不自动扩展为 +222，推送前需取得本版明确授权。自动化通过后仍为 `TRUE DEVICE PENDING`。

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
| P0 | +222 CI/APK 完成 | 真机复现“正在回复→停止→立即新对话/保存/恢复”，确认旧请求真实退出且无半覆盖，再联合回归 Cedar 网页连续换手 |
| P1 | 停止与备份互锁真机通过 | 继续验证自行建房、无需 APK 内催促的自动连续落子/对白、盲玩隔离、防沉迷 rest、暂离恢复、中文面板与房间 DeepSeek |
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
