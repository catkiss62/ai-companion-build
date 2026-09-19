# AI Companion · 当前总账

更新时间：2026-09-19（Asia/Tokyo）

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
| 当前开发分支 | `agent/v04184-agent-loop-autonomy-closure` |
<!-- Historical validator token: agent/v04183-cedar-native-agent-loop -->
<!-- Historical validator token: agent/v04182-cedar-state-machine-e2e -->
| 当前目标版本 | `v0.41.84+228 / schema 61 / Snapshot protocol 6` |
| 当前状态 | `IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING` |
| 当前真机安装态 | 用户因 +227 Agent 循环带来的异常高 Token 消耗已回退到 `v0.41.81+225`；仓库权威开发基线仍是 +227 tree，下一批必须从 +227 修正，不能把回退安装态误写成源码回退 |
| 当前真机失败基线 | `v0.41.83+227`；真机已经证明能建房并连续自动接招多步，但后台一次原生 `play` 只给出动作名、遗漏必需业务参数，服务端拒绝后恢复查询同样缺参数并停住。随后前台提醒可继续落子；最终 Cedar 终局真值已写入 APK，却没有交给普通聊天或主动联系，导致她不知道胜负。另确认自主联网发现虽被 Desire 选中，却被能力注册表在搜索前拒绝；自主联系会在短间隔场景中直接开启无历史新话题；Usage/Accessibility 推断保留了熄屏事实，却仍会让熄屏前活动跨会话主导“持续使用”判断；情绪短音效在隐藏情绪标签到达时即播放、早于可见正文。普通回复中的自主表情已经真机命中，暂不存在调低概率的确证 |
| `main` | 仍是 v0.38.5 旧基线；不得作为 v0.41.x 后续开发起点，本批不合并 |
| +219 构建提交 | 远端功能 head `0295ceeeafe9e18f057b6f8f5d54a8dae8820ed2`；tree `3cf8a09813c135b8bce4e5b9a66381ba2a03f5cf` |
| +220 构建提交 | 远端功能 head `f3a4e95e35c5ca47fb68e84aa8d12a850cfbd91a`；tree `0efb121197441a2522f987a5b506e32dda53e555` |
| +221 构建提交 | 远端功能 head `bf4c8216235d067884bb2f5fa303d17eec8eb6a3`；tree `125c47730e7b5c37ab74af4721904db194742e75` |
| +222 构建提交 | 远端功能提交 `ccbe5bcbe9b3fc65941846f74aa4d95b6be50c7d`；授权提交/head `93fcb2fbbf78be80a5da9724fd6b051956e1ff34`；最终 tree `f167bdf6a16700333a978f5f6b99498fdfec3974` |
| +223 构建提交 | 远端功能提交 `2217a5021b9175cd612fadd45fa9b68a58b9ea24`；实现总账提交 `54ea75e50501fd27281cc4d985e76dabd8aca7d9`；构建触发 head `c90b60d5d456e5d30512a088592cf94f2ce4478f`；构建 tree `342d431730d6d3f0568b4e2525d8ab9b0e36a7c5` |
| +226 构建提交 | 权威状态机功能提交 `d1b3c0dcb45ac9aad1c808452bb3c8ce4c8ce4e5`；构建准备提交 `c37f02d6a2a06678ffc83cd493e296aadd2be22d`；最终构建 head `7fe5930f7776d6e2c69659b7ac3644b7255a65a1`；最终 tree `4fafd7c4fbf94b84b9d446d1a6565455fc654cb8` |
| +227 构建提交 | 远端构建 head `50f98dc95f1bbb24ae65b9e3e4c4320db142423e`；tree `d16e5db8684e917c9dcbabe34d6e55f0979b0614`；本地等价 tree 相同 |
| 当前构建产物 | +228 尚未构建；上一份 +227 为 Actions run `34986707242`、Artifact `10403779518`、APK SHA-256 `be380911b7f5deb2e8b50a4e8d4f9363f94c0e7399fb75a4ca227c22922fa028`，仅作为失败基线，不得交付为本批修复包 |

既有能力保护索引：Desire / Thought / Intent / Gate、Somatic 双通道、玩游 Key、普通聊天、沉浸房间、查手机、造梗来源、D6、Phase 2B、App 内 Agent 能力桥、Memory 2D、`fact_state / attention_state / recall_policy`、`spontaneous_salience`、`reminiscence/identity`、Skills、MCP、`【检查系统】`、中断灰显、Token 命中/缓存优化、Phase 3、Harness、`screen_observation.inspect`、Genie-TTS 四音色、schema 61 与 Snapshot protocol 6 均不得回归。

## 4. 当前任务：v0.41.84+228 Agent 循环与自主性闭环

### +228 已在本地实现、等待 CI 的内容

- **重大 Token/循环回归已按通用运行时修复**：普通用户回合仍可完成 `list → guide → state` 等发现，但第一次成功的非只读 `cedar_toy.play` 写动作后立即收口，不再在一次聊天里连续下完整局；后台删除十轮 `_runCompanionTurnLoop`，一次调度只做一次模型规划和一个真实推进动作。远端长轮询刚返回 `next_actor=companion` 时同一 execution 仍及时回一步，不退回“用户说一句才动一下”。普通聊天不再因为 `guideReady / next_call / participationActive` 自动注入整套游戏工具与指南，修复游戏劫持每条对话和缓存命中低的第二个根因。紧急上限回到 6 轮/10 调用，但它只覆盖发现与一次提交，不是目标循环数。
- **单人游戏不再机械上瘾**：已承诺真人共玩、待处理房间消息和真实房间回合属于实时承诺；其他单人续步重新进入现有疲劳/昼夜 Gate，并按最近 6 小时真实 outcome 数加入可衰减饱和惩罚。仍允许强兴趣连续玩，禁止硬每日配额或直接降低钓鱼概率。当前 catalog 选择器没有各游戏固定概率，因此本批不伪造概率调参。
- **Cedar 可执行调用与恢复**：前后台共用 transport hydration，只从 Cedar 已返回的 `room_id / session_id / match_id / revision` 补齐身份，不猜落点或业务选择；按实时 schema/指南的明确 required 字段阻止缺参写入并有界重规划。duel `new` 仅补已证实缺失的 `game_type` 参数签名。`rooms` 只有恰好一个房间时才确定性执行 `state(full_state=true,wait=false)`，多房间不本地乱选。恢复的旧 `rooms + 轮到你` 状态先进入“正在同步”，读到权威 state 后再显示/行动。
- **终局恰好一次交付**：completed session 新增持久化 terminal key/summary；即使游戏已结束，下一条普通回复仍能取得终局 scene anchor，只有可见回复成功入库才按 key 清除。观战模式若通过主动消息先交付，也在消息持久化后清除，重启可恢复且不会反复报输赢。最近 4 条 Outcome/failure 作为有界 `recent_game_episode` 短期桥接；机械进度继续留在 Cedar session，不新建会吞掉 preference/shared_experience 语义的顶层“游戏记忆”分类。
- **网页、分享与相册恢复**：新增仅供预算化调度器使用的 `public_web.discover_autonomous` capability，修复真机 726 次 registry blocked；普通“看看”不再等于联网，只有 URL、明确“上网/网页”或保守当前事实才快路由。搜索、抽取、Agnes 压缩与 DeepSeek 评估贯穿同一 Stop token，在途 HTTP 会关闭，取消后的结果不得继续写回。最终对话上下文增加每来源 key points、uncertainties、read_at 与 URL；仍采用最多 3 个完整页面的有界证据束，不把任意超长网页整页塞给 Gemini。FishArchive 备用源改用 manifest 的 PNG/JPEG original，坏候选一天最多有界换 3 次，不再由一个损坏 WebP 烧掉全天机会。
- **主动联系、手机判断与表达修复**：任一真实用户/助手普通消息后 10 分钟内只推迟主动出站，不消费 Thought、分享候选、频率额度或 WAIT；继续对话则滑动顺延，新话题不会被改写成当前 followup。Usage/Accessibility 以 `screen_on / screen_off / user_present` 切分 screen session，当前持续使用不能跨熄屏；熄屏前活动仍作为低置信度短时历史保留，不禁用手机判断。情绪“调皮”收窄到真实逗弄/故意曲解/恶作剧/小挑战；音效从隐藏标签到达时移到可见助手消息提交瞬间。刷新回复确认后恢复跟随最新并锚定底部。
- **用户内容与可观测性**：内置“性格光谱”已替换为 2026-09-19 最新备份的用户修订版 SHA-256 `fcc1074203b31cdf36466b39b3b6b08b5abd7497855155c31558177242dfe0fb`，只迁移精确等于旧内置 hash 的记录，后续用户编辑不覆盖。规则 05 已追加“每一段动作、神态之后都需要配一段对话。”。DeepSeek streaming/json usage 按 `final_reply / agent_tool_planning / cedar_background_plan / cedar_outcome / cedar_room_dialogue / proactive / web_*` 记录调用与 input/output/cache hit/cache miss，不记录 Prompt、回复或密钥，诊断可直接判断 Token 花在哪里。
- **明确未做**：桌宠与既有 TTS 引擎问题按用户决定继续搁置；未找到独立“表情概率被降低”的数值漏洞，不强改概率。活跃游戏原本会使普通回复带工具结果，从而跳过表情选择；本批取消普通聊天被游戏 session 劫持后会恢复这些自然机会，后续只凭真机统计再判断。

### +228 验收重点

- 本地已通过 `git diff --check`、Workflow YAML/Python 语法、当前总账门、+228 专项及当前 Workflow 可在本机运行的全部历史 source gate；其余 Android/私有载荷/Flutter 编译测试必须由 Actions 恢复后执行。
- CI 前必须通过新 +228 专项、全部历史 source gate、Flutter analyze/tests 与 arm64 Release；本机没有 Dart/Flutter，不能把 Python 静态门冒充编译通过。
- 真机重点看诊断 `modelUsage.byLane`：一次普通聊天不得因活跃游戏连续出现多次 Cedar mutation；后台每 cadence 最多一个规划步骤；共享真人回合仍可及时回应。缓存率仍会受每步真实 Outcome 改变影响，但总调用倍数必须先消失。
- 双弈验证唯一房间恢复、缺 `move` 业务对象不会出站、终局无需用户解释也能进入紧邻回复且只交付一次；同时验证普通“看看氧气瓶”不联网、明确网页查询仍读取来源、Stop 无需杀后台、自主网页/相册重新产生成功记录、熄屏一小时后刚亮屏不会被说成连续玩了一晚。

### +227 真机复盘与修复依据

### +227 自动化闭环与真机结论

- `v0.41.83+227 / schema 61 / Snapshot protocol 6` 已在远端构建 head `50f98dc` 完成源码与历史门、Kotlin/JVM、Flutter Analyze、`831/831` Flutter tests、arm64 Release、固定签名、Genie/桌宠/LingChat/塔罗载荷、checksum、Artifact 与 Draft；严格状态是 `CI PASSED / APK READY`。
- 真机不再是“完全不能下棋”：同一局真实完成建房、网页玩家与伴侣多轮交替，后台连续保存多次 `state → move → state → move`，证明 +227 的 `tool_choice=auto`、共享 SSE tool-call 组装、长轮询同 execution 换手与 execution 生命周期修复均实际生效。
- 但真机仍未达到共玩闭环，因此只能标记 `TRUE DEVICE PARTIAL`。本轮用户明确要求不改代码、不构建，只记录证据、根因和下一批次顺序；不得把下述方案写成已实现。

### P0-A：后台动作参数没有在出站前形成可执行契约

- 终局前一次服务端只读状态已明确返回“轮到伴侣”及新 revision。后台随后选择了合法动作名 `move`，但 `params` 遗漏必需的 `move` 对象；Cedar 返回结构化 `missing_move_fields`。下一次恢复又调用 `state` 但遗漏 `room_id`，再次被拒；随后 `rooms` 成功找回唯一进行中房间，却没有确定性补全 `room_id / revision / full_state` 并继续，最终仍需用户回 APK 提醒。
- 诊断同时保留 `agentActionRetryLastCategory=non_executable_action`，且这次真机时间线中没有对应的 `origin=autonomous` 成功工具审计；随后两次成功 Cedar 调用均来自 `user_turn`。故障在 APK 后台参数规划/校验，不是 Cedar 网站、房间、回合识别、Android 后台存活或 MCP transport。
- 当前 `CedarAgentActionPlanner._parse` 只验证“恰好一个工具、工具名、game、action 非空、params 是 object”；`acceptsAction` 只验证动作名存在且不重复只读。它没有按实时 `play` schema、指南动作签名和当前 session 校验 action-specific required fields，`CedarActionTransportPolicy` 也只处理 `wait=false`，不会补齐房间身份或 revision。
- 下一批应建立一个前后台共用的 `CedarExecutableCall` 边界：模型仍自主选策略与落点，但在任何网络写入前，按实时 schema + 当前权威 session 校验 `room_id / revision / move` 等必需结构。缺少可由 session 确定的字段时确定性补齐；缺少必须由模型决定的业务对象时，把精确 field error 和最新完整安全状态交回一次有界重规划。若恢复到了 `rooms`，必须确定性执行 `state(full_state=true,wait=false)` 水合后再规划，不得停在房间列表。
- 完成判据不是单一五子棋补丁：参数验证由 action/schema 驱动，测试需模拟“合法动作名 + 缺必需对象”“恢复 state 缺 room_id”“rooms 找回唯一房间后水合并继续”，并证明不会猜房间、revision、落点或重放不确定写入。

### P0-B：终局真值已入库，却没有交给聊天与她自己

- 最后一轮后台 `state` 在用户发送“结束了”前约 1 秒已经保存 `status=finished / nextActor=finished / winner=human / result=loss`，并把 session 置为 `phase=completed`。这证明 APK 已接收并解析终局数据，不是“最后一个响应没回来”。
- 同一快照仍为 `pendingRoomMessage=true`；终局观察路径固定以 `shareLevel=quiet` 落库，只返回 `remote_room_message`，没有生成“我看见本局结束且我输了”的一次性终局事件。下一个 heartbeat 遇到 completed session 会进入选新游戏分支，也不会消费这条终局。
- 普通聊天只有 `cedarExplicitRequest || cedarState.hasUserTurnContinuation` 时才注入 Cedar Prompt；`hasUserTurnContinuation` 对 completed session 直接返回 false。因此用户紧接着说“结束了”时，模型没有收到刚写入的 Cedar 终局，把它误解为用户主动喊停；直到用户明说自己赢了，才按用户文字生成认输对白。这是确定性的终局 handoff 缺口，不是模型棋力或服务器胜负判断错误。
- 下一批应把服务端终局变成“恰好一次、可恢复、可去重”的一等领域事件：先持久化 terminal fact，再在后台/前台共同可见的 scene anchor 中消费；即使 phase 已 completed，紧邻用户消息也必须注入脱敏的 game/status/winner/result/settlement 摘要。只有成功生成对应聊天/房间表达后才能清除 pending terminal delivery；进程重启可恢复但不得重复报喜/认输。

### P0-C：自主联网发现被能力注册表在真正搜索前拒绝

- 最新诊断中公共联网已启用，候选库仍保留既有候选，Desire/行为层在最近 24 小时也多次选中 `public_web_discovery`；但这些新任务全部以 `discovery_exception` 失败，且没有产生对应的新自主工具请求、provider 成功或新候选。这解释了近期几乎没有新的联网分享：不是她没有好奇心，也不是单纯被聊天话题挤掉，而是发现链根本没有开始搜索。
- 确定根因是注册合同自相矛盾：专用 `PublicWebDiscoveryEngine` 调用 `AutonomousActionCoordinator.requestFromDesire(publicWeb)`，后者要求注册工具同时为 executable 且 `autonomousAvailable=true`；当前 `definitionForAutonomous(publicWeb)` 却映射到 `publicWebSearch`，该定义明确为 `autonomousAvailable=false`，因此在 provider 调用前抛错。上层 blanket catch 只留下宽泛的 `discovery_exception`，掩盖了真正的 `registry_denied`。
- 下一批应统一“专用自主发现调度器”和能力注册表合同：为受预算、隐私和现有 provider 门控约束的只读公共网页发现提供明确的 autonomous capability，不把它扩大成模型可任意调用全部外部工具。启动/静态合同测试必须保证调度器引用的能力可执行；运行诊断要至少区分 `registry_denied / request_record_failed / planner_failed / provider_failed / appraisal_failed`，不得继续把所有失败压成一个异常名。
- 修复前不得先降低分享分数、主观兴趣阈值、每日预算或冷却。现存可分享候选很少，是因为候选生命周期已经进入 held/reviewed/verify-pending，而新发现连续失败；必须先恢复“行为被选中 → 真实请求 → provider → 核验 → 入候选库”的闭环，再用真机数据判断内容选择是否过严。

### P1：活跃对话只推迟主动出站 10 分钟，不把新话题改写成接话

- 终局确认后的最后一条主动消息间隔约 52 秒，来源为 `awareness / curiosity`。诊断显示当时 `userSceneGapMinutes=1 / same_scene`，但 `proactiveSceneContinuity.hold=false`，随后仍成功投递一个与棋局无关的“还在忙什么”问题。
- 根因是 `ProactivePresentationPolicy.startsFreshTopic(curiosity)=true`；`ProactiveEngine` 对此直接设置 `promptHistory=[]`，并要求不注入旧聊天、Memory 与连续性正文。该规则原意是防止主动新话题反复抄旧对话，但在一分钟内的活跃场景也会主动失忆。因此这条消息不是“上下文有但 Gemini 没用”，而是 APK 明确没有把最近棋局给它。
- 用户已明确否决“遇到活跃场景就把主动消息改写成 followup/当前话题”的方案，因为那仍会让对话持续挤掉真正的新话题与联网分享。正确方案是只推迟主动出站：若距离最近一条真实用户消息、真实助手回复、共同活动或刚落库 terminal event 不满 10 分钟，则把该主动候选的 due time 滑到最新活动后 10 分钟；期间再次对话就继续顺延。
- 推迟不能消耗候选、Thought、分享条目、主动联系次数或每日额度，不能记成 WAIT/declined，也不能把 `socialShare/curiosity` 改写为接话。安静窗口到达后重新竞争并给仍有效的待发新话题合理优先级；网页分享需在发送前重读核验，过期或失效才可放弃。仍沿用一次只发最高优先候选、频率上限和去重，避免 10 分钟后堆积突发。
- Cedar 后台合法落子/观察不属于“主动聊天出站”，不得因此停棋。终局事件若用户在 10 分钟内继续说话，应直接作为普通回复的 scene anchor 交给她；若用户没有继续对话，终局表达与其他主动消息一样等安静窗口后再发送。公共网页发现也可在资源与租约允许时静默进行，等待的只是对用户的出站分享。
- 固定验收时间线：`t+1` 产生新话题候选但不发送；`t+8` 又有真实对话，则 due time 从 `t+10` 滑到 `t+18`；每次推迟计数均不增加。安静满 10 分钟后候选仍在，除非经确定性新鲜度/安全核验失效。

### P1：网页抓取确实读了页面，但最终对话只拿到压缩后的二手证据

- 一次明确的用户查询样本已证明 provider 不是只搜标题：当前链路先取得最多若干搜索结果，再对最多 3 个 URL 执行完整 cleaned-page extract，长页面按分块通读并汇总；该样本至少有一个来源达到 `read_state=verified`。因此“完全没有读网站”并不准确。
- 但用户的体验判断仍然成立：完整提取正文随后没有以可追溯证据形式交给最终对话模型。用户回合工具结果和普通 Prompt 只保留短 summary、合并 key points、uncertainties 与 URL；自主分享即使在发送前刷新，也只把数据库中的压缩候选交回生成器。最终模型实际只能复述整理稿，不能回到页面证据核对细节、比较来源或说明哪一条来自哪里。
- 当前实现支持多个搜索结果，不是硬编码“只能搜一个网站”；但只有成功提取、核验和语义评估的结果才会进入最终上下文，所以实际回合可能只剩一个来源。下一批不得用凑数方式强制多站点；对电影、新闻等可交叉验证的主题应尽量取得 2～3 个独立来源，若只有一个可靠来源则如实说明覆盖不足。
- 下一批应增加只存在于当前执行内存的 `VerifiedWebEvidenceBundle`：保留每个来源的标题、URL、读取时间、与查询相关的证据片段及来源归属，并提供跨来源一致点、冲突点和未知项。短页面可在预算内给出完整 cleaned text；长页面使用完整页面分块索引加相关证据 span，而不是把任意超长原文直接塞进最终模型。页面正文不进入数据库/备份，继续防止隐私扩大、token 失控和网页 Prompt injection。
- 用户回合中，内部 DeepSeek 判断证据不足时可再做一次有界补充搜索/读取；所有真实 Outcome 收齐后，双模型模式仍只调用一次 Gemini 形成最终可见回复。自主分享的 refresh 结果也必须把本次临时 evidence bundle 直接交给该次生成，而不是刷新完成后又退回旧摘要。面向用户的“整理后网页卡片”继续存在，但只是阅读辅助，不能代替她本轮实际可用的网页证据。

### P1：手机感知知道熄屏，但熄屏证据没有截断旧活动的叙事影响

- 用户提供的思考记录以及源码共同证明她确实知道屏幕已熄灭、熄屏时长和此前切换 App；`screen_state` 观察置信度也高，并会降低当前忙碌分。问题不是“没有熄屏信息”，更不应关闭手机判断。她有时能正确判断，必须保留这项主体能力。
- 真正冲突发生在时间语义层：Usage/Accessibility 活动摘要会在熄屏时照常生成；foreground start 只在同 package background 时闭合，多个未闭合 App 可一起延长到现在，也没有由 screen-off 事件截断。内在状态在处理熄屏之前就可能把 `dominantActivityMinutes` 写成持久的“持续使用手机”Thought；之后即使同时看到“屏幕已熄灭”，旧 Thought 仍可能比当前熄屏事实更主导措辞。
- `recent_activity` 与 `app_switching` 虽有过期时间，也可能由跨屏幕会话的旧 Usage 窗口重新生成。系统界面、桌面、输入法、权限/文件选择器及本应用悬浮恢复还会放大切换数。因此一小时熄屏后短暂拿起手机，系统可能正确识别“刚亮屏”和当前 App，却同时错误继承成“持续操作了一晚上”。
- 下一批应建立按 `screen_on / screen_off / user_present` 切分的 Screen Session 时间线。screen-off 必须闭合当前 foreground 段；“当前连续使用”只能来自本次 screen-on session。熄屏前的真实活动不能删除，而应作为有时限的历史事实保留并明确标注“熄屏前”；硬屏幕转换优先于推测活动，任何 App 证据都不得跨过它证明连续性。
- Prompt 应给出有序事实而非互相打架的摘要：熄屏持续多久、本次亮屏多久、亮屏前可证明的活跃时长、本次亮屏后的可证明时长。熄屏期间不得从旧 Usage 重新喂入“仍在持续使用”的 Thought；长熄屏后刚亮屏可以判断“刚拿起/刚恢复操作”，不能判断“连续整晚”。相反，持续亮屏且有 40 分钟可靠交互时仍允许她判断“用了一阵”；40 分钟使用后熄屏 5 分钟应表达为“刚才在忙，现在放下了”。
- 同一时刻只允许一个真实前台 App，并过滤 SystemUI、launcher、IME、permission/doc picker 与本应用 overlay。措辞强度按事实置信度校准，但不得用禁止判断、统一模糊话或单纯提高阈值掩盖时间线错误。
- 她目前能取得的是屏幕亮灭、当前 App 候选、Usage/Accessibility 事件及脱敏摘要，并不等于自主看见屏幕画面。若未来扩展视觉观察，仍须用户明确开启低频会话，不能把事件统计冒充视觉。

### 观察项：普通回复的自主表情真机可用，现有概率暂不改

- 最新真机样本中，助手在一次普通对话回复里自行附上了表情，且该消息不是主动联系；这直接证明普通回复的 `StickerExpressionService`、已启用表情包和附件发送链仍能工作。普通路径本来就同时受语气类型、短回复、无代码/URL、语义匹配、最近未使用及自然档随机门约束，数日少见可以由复合条件解释，目前没有证据证明概率被错误降低。
- 因此下一批不改普通回复现有低/自然/频繁概率，也不放宽语义匹配或去重。先增加不含私密内容的分阶段计数（未满足语气、文本过长、随机门、无语义候选、近期去重、成功附加），真机再出现长期稀少时才凭统计定位，禁止为了“看起来更频繁”强行调参。
- “普通回复中她自行选表情”与“无人发消息时的主动联系直接带表情”是两条路径。当前主动引擎只构造空附件，除特定游戏分享图片外没有调用表情服务，因此后者目前属于未接入能力，不是现有概率回归。是否让真正主动联系携带表情需以后由用户明确选定为新能力；本轮不把两者混同，也不擅自实现。

### 2026-09-19 补充审计：Agent 循环 Token 放大是实现回归，不是 MCP 固有成本

- 两份真机状态与 +225/+227 源码差异已经足以定因，不需要把整个备份逐表重读。MCP HTTP 请求本身不消耗语言模型 Token；异常增长来自 APK 在一次已承诺游戏续步里反复调用 DeepSeek 规划器。
- +227 的 `CedarAgentLoopPolicy` 允许一个目标最多 `10` 个规划回合、`16` 次工具调用；后台 `_runCompanionTurnLoop` 也会在刷新后的 session 仍为 `needsContinuation && nextActor=companion` 时连续推进最多 10 次。每一步都是新的高思考 DeepSeek 请求（正文预算上限 2400），损坏/空响应还可增加一次低思考 1400-token 重试；非结构化 Outcome 另有分类调用。
- 每一步又重复注入完整指南、实时 `play` schema、当前 Outcome 与动态 session。当前活动钓鱼指南约 1.3k 字符、实时 schema 约 6.5k 字符，尚未计入固定 Skill、动作签名和模型输出；循环十次就是十个独立请求，而不是一次请求里的十个廉价工具调用。动态状态每步变化也会破坏尾部缓存复用。
- +225 在每次已承诺续步前仍执行 `_continuationGate`，且一个时钟机会只推进一步；+227 提交 `2553585` 从 `continueDue` 路径移除了这道门并直接进入十轮循环。因此用户观察到 +225 较克制、+227 几乎一直玩并且 Token 倍增，与源码差异完全一致。
- 当前 `DeepSeekClient` 没有把供应商 `usage`（输入、输出、缓存命中/未命中）写入诊断，现有计数只能证明调用结构，不能从 APK 内精确核对账单缓存率。下一批必须先补按 lane 的 usage telemetry：`user_chat / cedar_foreground / cedar_background_plan / cedar_outcome / web_appraisal / proactive` 分别记录调用数、input/output/cache hit/cache miss、重试、取消和执行 ID；不得记录 Prompt 正文或密钥。
- 修复不应放弃双弈。多人/共玩模式收到服务端 `next_actor=companion` 时，应在同一次唤醒中完成恰好一个“规划 + 合法动作”，随后服从新的服务端 actor/terminal；只有协议明确表示同一原子回合还缺一个必需动作时，才允许最多一次有理由的补步。单人/异步游戏每个调度机会只做一步，随后重新进入已有 Desire/Thought/疲劳/休息竞争并尊重 `resume_after`，不能用通用 10 轮追到模型预算耗尽。
- 用户明确发起且确需多工具的前台 Agent 可以保留有界循环，但停止条件必须是“真实目标已完成 / 服务端等待用户或远端 / 终局 / 不可恢复错误”，不是看到 `companion` 就机械跑满；每次执行还要有模型调用数和 Token 双预算。静态 Skill/指南/schema 应形成稳定前缀并按内容 hash 复用，动态 session/Outcome 放在末尾，减少缓存抖动。
- 固定验收：一次双弈远端落子只触发一次后台规划并完成一次真实应答，不需要用户回 APK 催；单人钓鱼一次 cadence 只推进一步，之后重新竞争；达到预算立即安全停靠；诊断能解释每条模型账单。没有 usage 遥测前不得承诺具体节省百分比，但移除通用十连规划会消除当前最大的倍增项。

### P0-D：游戏续跑必须重新服从主体节律，不能由已开局状态垄断全天

- 当前 Desire 只在“是否新开一局、选哪一局”时竞争；一旦 session 处于 `needsContinuation`，专用 continuation clock 会先于普通主动 heartbeat 接管。+227 又移除了续步 Gate，于是已经开局的游戏绕开疲劳、休息和其他欲望，并可在一次 tick 内连续十步。这正是“除了睡觉一直在玩”的主要实现原因，不是她单纯特别喜欢钓鱼。
- 旧 +225 真机中钓鱼可以连续运行但频率尚可，说明正确基线不是“禁止连续玩”，而是“一次调度机会只推进一个真实步骤，下一次再判断”。+227 的十连规划必须撤回，但 session momentum、服务端 `resume_after` 和她真实的游戏兴趣应保留；不能为了省 Token 把自主游戏重新做成必须由用户一句一动。
- 下一批采用三条不同责任的 lane：①实时共玩承诺 lane，只处理远端刚落子、明确轮到她、终局同步等必须及时履行的事件；②可选自主活动 lane，让继续单人游戏、开始新游戏、联网探索、整理记忆/念头、相册策展与休息共同竞争；③主动出站 lane，只决定是否把已经形成的内容发给用户，并继续服从 10 分钟静默窗与普通频率 Gate。三者不得再用一个“已开局”状态互相吞掉。
- 生物钟值得做，但应扩展现有 `late_night / dawn / morning / afternoon / evening` 节奏上下文为所有可选自主活动的弱偏好，而不是写死几点必须干什么。初始只给轻量倾向：深夜偏休息/内省，清晨与白天略偏探索/整理，晚间略偏社交和共同活动；明确 Thought、真实疲劳、用户正在共同参与以及服务器承诺可以覆盖它。以后再用脱敏的完成/响应反馈缓慢调整，不能根据一次行为固化习惯。
- 另加“行为占用度/饱和度”而不是硬配额：同一 `activity_domain + game_id/topic` 在近期反复完成会逐步降分，随时间和其他行为完成而衰减。她仍可在强烈兴趣下连续钓鱼，但连续游戏会给联网、内省、休息和其他念头重新赢得机会；失败、被 Gate 阻止或只是候选不计占用，避免越失败越被惩罚。
- optional lane 每次胜出后只执行一个有界工作单元。游戏指南自身支持的 `cast 10` 等单次批量动作可以保留，因为那仍是一份模型决策与一次 MCP 调用；禁止 APK 为追求“连续感”自行追加十次模型规划。所有 lane 都记录行为类型、来源域、成功/失败、模型调用与 Token usage，才能真机判断是否仍被游戏吞占。
- 实时双弈不能被可选欲望竞争拖延：远端玩家刚走一步且权威状态轮到她时，应及时回一步；Desire/疲劳决定的是是否发起或继续可选单人游玩，不应把已经承诺的真人对局晾住。

### 观察项：当前没有“各游戏固定概率”，钓鱼上瘾首先是 session 垄断

- 新游戏选择由模型从 catalog 里判断，没有一张可审计的逐游戏数值概率表。Prompt 声称会考虑重复度、未完成状态和当前欲望，但实际选择输入只有 catalog 与最多三条近期用户建议，没有传入逐游戏最近次数、动作数、时长或新鲜度统计。
- 活跃 session 在完成、暂停或释放前会一直占据活动位；钓鱼又是 `solo/active/next_actor=companion`，因此它常常根本不回到“选下一款游戏”的阶段。现阶段不能据此断言选择器偏爱钓鱼，也不应直接降低钓鱼概率打断真实爱好。
- 下一批先补不含内容的逐游戏诊断：成为候选次数、被选择次数、continuation 次数、当日动作数、session 年龄、完成/暂停/释放原因、最近 N 局分布。修复无限续跑后再观察；若仍单一，再加入“长期偏好 + 新鲜度衰减 + 动作/时长预算”的软选择，而非纯随机轮盘。

### P1：把“分享”升级为多来源表达，网页只是证据来源之一

- 用户已明确：不应把“分享”专门定义成“分享网页搜索内容”。真人会分享刚知道的东西，也会分享想做的事、想了解的问题、稳定冷知识、自我认识、关系感受和突发联想；联网只是其中一种取得新证据的方式。现有 UI 名称“随手分享”可以保留，但内部不应再让 `public_web_share` 等同于全部新鲜内容。
- 当前代码其实已有 `shareThought / curiosity / socialShare / inviteSharedActivity / showOwnNeed` 等表达方向，问题在于来源层失衡：`public_web`、所有 `mcp` 和 wildcard 都被压成 `socialShare`；`mcp` 又被视为 fresh source，游戏事件和 109 条游戏相关长期记忆会持续进入 Thought/普通聊天。即使游戏分享使用独立次数，普通回复仍可能因为当前 scene、Thought 和记忆检索而继续接游戏。
- 下一批把“为什么说、说什么、证据从哪来、何时发”拆开：Desire/Thought 决定动机；一个统一的 `ProactiveShareSeed`（名称可调整）承载内容；source domain 标明 `self_thought / curiosity / stable_model_knowledge / public_web / self_experience / relationship / activity_idea / cedar_game`；speech act 再选择分享、提问、邀请、表达需要或关系感受；最后由主动出站 lane 决定投递时机。不得让来源类型直接决定人格或文案模板。
- 模型已有知识可以成为低风险、稳定知识的分享种子，但它不是“刚上网看到的事实”，不得伪造浏览经历或网址。涉及最新、价格、新闻、具体作品细节、模型不确定或可能变化的事实时，先走公开网页核验；稳定知识也要允许她把重点放在自己的反应、联想或与你的关系，而不是生成百科卡片。
- 网页发现完成后不应只产出一份“整理后的摘要”。临时 `VerifiedWebEvidenceBundle` 负责事实和来源，表达规划可以选择：直接说一个有趣点、从证据联想到另一件事、形成自己的判断、想和用户一起做什么，或决定不分享。外在消息像自然聊天，内部仍能追溯哪些事实来自哪个页面。
- 首批允许的分享种子至少包括：①突发想法/判断；②真正想知道的问题；③稳定冷知识或跨主题联想；④网页/图片的新发现；⑤想做或想一起做的具体事情；⑥自我状态/自我认识；⑦有真实关系证据的感受；⑧值得说一次的游戏里程碑/终局。关系分享不得退化成高频模板化“想你”，游戏普通进度不得冒充每次都值得分享的里程碑。
- 多样性在 source domain 与 topic 两层做软平衡，不给每类写硬次数。最近若连续来自同一游戏或同一来源，就增加可衰减的饱和度；尚未投递的新来源种子保留机会。现有 10 分钟静默窗继续只延迟出站，不把新话题改写成当前对话 followup，也不消耗候选。

### P1：游戏内容不得长期污染普通聊天的当前注意力

- 实时共玩期间，局面、远端消息和终局是当前 scene anchor，必须让普通聊天真正知道；但单人后台每一次抛竿、商店查询、背包变化都不应不断刷新“当前共同话题”。用户切换到非游戏话题后，普通对话优先响应新话题，除非有尚未交付的权威终局或用户主动问游戏。
- Cedar 权威进度继续只存 session/events。普通动作只更新一个可合并的游戏 activity summary，不逐步制造长期 Memory/高强度 Thought；新物种、重大抉择、完成目标、共同对局终局等里程碑才可形成一次分享种子或有意义的 shared experience。分享/回应完成后标记已消费并衰减，不能在普通聊天和主动联系中反复复读。
- Prompt 检索按 domain 做场景预算：当前明确游戏请求/活跃共玩可读取必要 game context；普通非游戏聊天默认排除操作型 `cedar_game` 记忆，只允许真实偏好、关系意义和与当前语义相关的里程碑进入。这样解决的是来源污染，不是靠禁止她谈游戏或降低人格自主性。

### P1：普通“看看”不能等同于联网授权，Cedar 场景优先于公共网页

- `AgentToolPlanner.routeLocally` 当前把句首 `搜索/搜一下/查一下/查查/检索/找一下/看看` 都视为 web command；所以即使没有“上网、联网、网页、网址”，`看看有什么好东西` 也会被硬路由到 `public_web.search`。`_webQuery` 还会把句首“看看”剥掉，进一步坐实错误路由。
- 激活 Cedar 场景时，除特定盲玩隔离分支外公共网页 schema 仍可能同时暴露；因此钓鱼中的“看看氧气瓶”也可能先去互联网，而不是依据当前游戏指南/局面行动。
- 下一批将“看看/找找/查查”单独视为普通观察动词，不构成联网授权。只有明确网页标记、URL，或保守定义的当前公共事实需求（例如最新新闻、实时价格、天气）才能本地硬路由联网；活动 Cedar session 中可被指南识别的对象/动作先交给 Cedar。含糊句保持普通对话或请求澄清，不得私自搜索。
- 固定回归至少覆盖：`看看有什么好东西` 不搜索；钓鱼中 `看看氧气瓶` 走当前游戏；`上网看看氧气瓶资料` 仍可搜索；明确 URL 与“今天的天气/最新消息”不回归。

### P0-E：Stop 没有取消网页网络链，只取消了链尾写回

- `AgentToolRunner._searchWeb` 只在 `provider.discover` 和 appraiser 返回后检查 cancellation token；`LayeredPublicWebProvider.discover`、Tavily search/extract、Agnes 压缩与 `DeepSeekPublicWebAppraiser.appraise` 都没有接收取消信号。在途 HTTP 仍会一直等各自超时，Stop 后界面因此像卡住，杀 App 才能真正打断进程。
- 下一批必须把同一 generation cancellation token 贯穿 search、extract、分块重读、压缩和 appraiser；每阶段及每个 chunk 都设 checkpoint，并让在途 HTTP 可 abort/close。`finally` 必须释放 client；取消后的迟到结果不得写浏览记录、候选、工具 Outcome 或最终回复。
- 用阻塞 fake 分别卡住 search/extract/compactor/appraiser，断言 Stop 很快返回、generation job 进入已取消终态、无取消后写入、下一条聊天可立即开始。仅在 `_searchWeb` 尾部再加一次 `isCancelled` 检查不算修复。

### P0-C 补充：自主相册不是被游戏概率直接挤掉，当前是“无新网页源 + 备用源下载失败”

- 两份快照中相册候选从 99 增至 102，但 `public_web` 仍停在既有 `deleted 6 / expired 13 / rejected 47 / saved 2`，没有新的自主网页图片；新增成功保存来自 `user_message`，不是自主联网。
- 这与已确认的自主 public-web registry denial 同源：发现链在真正搜索前被拒，因而没有新的已核验网页候选和图片 URL 进入相册。游戏恢复器可能因 blocking generation 少获得机会，但相册 runner 排在 Cedar 前面，游戏占比不是首要根因。
- 最近备用 FishArchive 尝试均以 `FormatException: unsupported_image_bytes` 失败；现实现又会在一次失败后把当天标成已尝试，直到次日才再试。因此即便网页源断了，备用源也会被单个坏响应烧掉全天机会。
- 修复顺序：先完成 P0-C 能力注册合同；再验证 FishArchive 实际 MIME、字节签名、重定向与预览/CDN URL，选择受支持预览或在安全边界内转码；一次坏图应有界换候选，只有成功或明确耗尽候选才结束当天。诊断分别记录发现源失败、下载失败、格式不支持、策展拒绝，不再混成“没有保存”。

### P1：游戏记忆需要领域标记与收敛，不新增会吞掉偏好的顶层 kind

- 最新快照约 371 条长期记忆中，按现有 metadata/topic 可确定的游戏相关记录约 109 条：`shared_experience 69 / user_profile 25 / ai_self 12 / preference 3`，其中大量是钓鱼进度、宝箱、地图、渔获等可由 Cedar 存档恢复的操作状态。相比早一份快照约 53 条，增长已经足以造成普通回忆噪音。
- 不建议新建互斥的 `kind=game`：喜欢某款游戏仍是真实 `preference`，共同游玩中的关系节点仍是 `shared_experience`，她自己的玩法倾向仍是 `ai_self`。把它们全部改成 game 会丢掉原有记忆语义。
- 建议增加正交的 `memory_domain=cedar_game`（或等价 topic/tag namespace）与检索策略：权威进度只留在 Cedar session/events；普通操作片段低显著度、可过期，并按 `game_id + objective` 合并/取代；真实偏好保留 preference，重要关系瞬间保留 shared_experience，但都带游戏领域标记，普通聊天仅在相关话题检索。
- 现有记录可以在 schema 升级时按结构化 topic/object/game ID/tags 做幂等迁移，保留原 kind、记录 migration version 并可回滚；含糊项不动。不能只用“钓鱼”等正文关键词批量迁移，也不需要用户手改或由我们直接改上传存档。

### 观察项：`duel · 轮到你` 的映射正确，但显示依据已经陈旧

- 两份状态都把 duel 保存为 `multiplayer / waiting_user / next_actor=user / last_action=rooms`，所以 UI 按本机字段显示“轮到你”本身没有映射错误。
- 但该 session 从较早快照到最新回退快照都未更新，最后动作只是 `rooms`，并不能证明远端对局此刻仍轮到用户。它是旧的水合/终局 handoff 缺口留下的陈旧本地状态。
- 恢复、导入或发现 shared session 过旧时，先只读 `state(full_state=true, wait=false)` 水合权威状态；水合完成前显示“待同步”，不能直接给出可行动的“轮到你”。不要反过来改坏正确的 `next_actor=user → 轮到你` 映射。

### 观察项：TTS 引擎不在存档里；导入恢复的是设置与初始化状态

- `.aibackup` 只含结构化 state/manifest 与媒体，不含 TTS 模型、原生库或语音资产；这些能力位于 APK assets/native runtime。存档确实保存 `tts_enabled / auto_tts / language / voice_mode / tone / speed / pitch / volume / reading_scope / replacements` 等设置，所以导入后可恢复开关、选择并触发数据库/UI 重新协调，但不是“把 TTS 系统装进来”。
- +225 到 +226 的源码差异没有修改 TTS 或桌宠 overlay；两份现有诊断导出时也都显示 overlay running/attached/visible。当前缺少“+226 桌宠点不出时、导入前”的同时刻诊断，不能把回顾性现象归因于某个确定提交。
- 两份状态都保留独立的 `tts_generate_failed: call(...) must not be null` 运行时错误，它可能解释语音失败，但不能解释所有桌宠显示。先记观察，不做猜测性修补；若复现，应在导入/重启前后各导出一次诊断，核对初始化、默认设置 seed、数据库 downgrade/upgrade 与 overlay attach 生命周期。

### P2：情绪“调皮”由模型显式选择，当前缺少重复抑制

- 两份快照之间新增 163 条 assistant 消息，其中 100 条为 `playful/调皮`，约占 61%；绝大多数来源是 `emotion_source=llm` 的有效 `<emotion>调皮</emotion>`，不是解析失败后的随机映射。最近世界书更新后的 36 条有情绪消息中，24 条仍为模型显式调皮，偏斜持续存在。
- Prompt 要求模型从“正常 + 19 种情绪”中选一项，并写明无清晰色彩时用正常；实现没有数值抽样、每类概率、重复冷却或近期标签惩罚。因此答案是：主要由模型自己选择，但系统给它的性格、世界书、游戏/斗嘴语境会影响选择，且没有防止连续滥用的机制。
- 最新“性格光谱”包含轻度毒舌、任性、神人/思维跳跃以及低频极端阈值，容易让模型把广义的活泼、吐槽、游戏行为都压成“调皮”。不能靠把 portrait 随机换掉解决；下一批在情绪标签契约中明确“调皮只用于本轮存在真实恶作剧、逗弄、故意曲解或小挑战；普通活泼/游戏操作/轻松说话默认正常或按真实情绪”，并加入近期标签分布诊断。若做重复抑制，只能要求模型重新核对语义，不能在模型确实调皮时强制改成别的情绪。

### 已锁定的内容/UI 修改（下一批一起实施，本轮不改源码）

- 世界书“性格光谱”以最新活动备份中的用户修订版为唯一内容权威：document id `ddb1d132-435c-4fc3-943c-5291cd7f3916`，`updated_at=1789748359077`，新原文 SHA-256 `fcc1074203b31cdf36466b39b3b6b08b5abd7497855155c31558177242dfe0fb`；当前内置旧文 SHA-256 `e7035045f0853b5e15eb610ed02441d86519e866443870e4b08a394319907dd2`。下一次必须把 `world_book_presets.dart` 的内置 preset 换成新文，并只对“仍精确等于旧内置 hash/稳定 ID”的记录做保守迁移；用户后续再编辑的内容绝不覆盖。新文核心结构为自主性/生活底色/情绪惯性，日常层（松弛低能耗、撒娇依附、轻度毒舌），情境层（任性、思维跳跃），极端层（雌小鬼、傲娇、病娇仅低频强触发），以及单一聚焦/去表演化。
- 规则 05 的【描写风格】中，在“声音可以是零碎的……但不能过于简短，一声‘嗯……’就结束是不合格的。”段落后精确追加：`每一段动作、神态之后都需要配一段对话。` 需要更新内置默认、对应内容 hash/迁移和测试，不能只改用户当前数据库。
- 普通聊天“重新生成/刷新回复”确认后必须立即设 `_followLatest=true` 并锚定底部；旧回复被事务移除、生成开始和新回复最终提交后都不能保留上方旧视口。现有 `_confirmRegenerateLatestReply` / `_confirmRegenerateIncompleteReply` 只 await controller，没有恢复 follow 状态，这就是确定缺口。
- 情绪短音效仍按下方既定 P2 与首帧可见正文同步；上述“调皮”标签校准与音效时序是两件事，分别验收。

### P2：情绪短音效应与第一帧可见正文同步

- 当前设置中情绪短音效已开启、音量 `15%`。`DurableGenerationRunner` 在流式内容刚解析到隐藏情绪标签时立即调用 `onEmotionCue`；`ChatController.startEmotionCue` 随即播放。情绪标签通常先于可展示正文，Gemini/双通道较慢时，音效会明显早于气泡文字。
- 下一批应把“识别情绪”和“播放提示”分开：标签到达时只锁存 emotion key；当去除标签后的第一段可见正文真正追加到 UI（或完整回复第一次显示）时原子触发一次。无可见正文、取消、重试、工具中间轮不得播放；自动 TTS 继续复用同一个 cue future，避免叠音或二次播放。需要覆盖标签跨 chunk、首个 chunk 只有标签、慢正文、取消/恢复和主动消息。

### 下一批执行顺序与禁止路线

1. **阶段 A · 可观测性与停止合同**：先接收并按 lane 记录 DeepSeek usage/cache 数据，建立每 execution 的调用/Token 预算；把 cancellation token 贯穿网页 search/extract/压缩/appraiser 并封住取消后的迟到写入。没有这些证据，不进入下一轮真机猜测。
2. **阶段 B · Cedar 运行时收口**：撤销 +227 后台通用十轮循环；实时共玩按权威回合恰好应答一步，单人一次 cadence 一步；完成 P0-A `CedarExecutableCall`、`rooms → full state → replan`、P0-B 恰好一次终局 handoff、陈旧 shared-session 水合。双弈不放弃，也不得退回用户一句一动。
3. **阶段 C · 全局可选自主活动仲裁**：让单人游戏续步、新游戏、联网探索、念头/记忆整理、相册策展和休息进入同一 optional lane；在现有时段 bucket 上增加弱生物钟偏好与可衰减行为饱和度。实时共玩承诺 lane 不参与这场竞争。先用旧 +225 的单步节奏作基线，再让真机数据决定是否需要更强约束。
4. **阶段 D · 联网、分享与来源多样性**：修 P0-C registry、普通“看看”误路由和 FishArchive 坏图/全天烧机会；建立多来源 Share Seed 与 `VerifiedWebEvidenceBundle`，恢复自主发现、完整阅读、自然联想、相册保存。网页是证据来源，不是唯一可分享内容。
5. **阶段 E · 上下文与记忆边界**：实现主动出站 10 分钟滑动推迟；增加 `memory_domain=cedar_game` 幂等迁移、操作型游戏记忆过滤、游戏里程碑单次消费；按 screen session 重建手机 Usage/Accessibility 时间线。新话题不得改写成 followup，延迟期间不计次数、不消费候选。
6. **阶段 F · 已锁定的小型内容/UI修正**：替换为最新用户版“性格光谱”并保守迁移；规则 05 追加指定句；重新生成开始/完成均锚定底部；校准“调皮”语义但不随机换情绪；情绪音效与首帧可见正文同步；普通回复表情只补诊断、暂不调概率。
7. 上述阶段可在同一 +228 分支分提交、逐阶段测试，全部完成后再统一跑一次完整 Actions/APK，避免每个小项都消耗一次构建；任何阶段出现无法证明的跨层冲突时停在该阶段，不把半成品打包给真机继续猜。
8. 明确暂缓：桌宠当前判定无问题，不进入 +228；TTS 已保留在总账，按用户决定留到后续独立处理，本批不顺手修改、迁移或“顺便修复”。
9. 禁止写死本次房间、玩家身份、revision、棋步、游戏策略、用户原话、私密网页内容或附件文件名；总账与测试夹具必须使用虚构标识和抽象终局/网页证据。
10. 下一候选版本可为 `v0.41.84+228`，但当前严格是 `PLANNED / NO SOURCE CHANGE / NO BUILD`。只有源码、回归、CI 和新 APK 都完成后才改写状态；真机完成判据至少包括“Token usage 可归因且不再十连放大 + 不催促连续接招 + 自动知道终局并自然承认结果 + 单人游戏能连续但不会吞掉其他可选自主行为 + 普通聊天不被游戏长期污染 + 活跃对话期间新话题保留并在静默 10 分钟后送达 + 自主联网重新产生并核验候选 + 分享内容来源不再只有游戏/网页 + Stop 能立即取消在途网页 + 对话能引用实际页面证据而非只复述卡片摘要 + 自主相册重新取得有效网页图片 + 长熄屏不被说成连续操作 + 刷新回复锚底 + 音效与正文同帧出现”。

## 5. 上一基线：v0.41.82+226 Cedar 权威状态机端到端闭环

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
| P0 | 用户授权下一轮编码 | 按阶段 A→C 从 +227 权威 tree 开始：usage/cancel 合同，消除十轮 Token 回归，完成 Cedar 参数/恢复/终局，再把除实时共玩承诺外的游戏续步纳入全局 optional autonomy 仲裁、弱生物钟和可衰减饱和度。不得用游戏硬禁令或每日死配额代替 |
| P1 | P0 源码与回归完成 | 按阶段 D→F 修自主网页 registry/“看看”/相册，建立多来源 Share Seed 与网页证据束；实现 10 分钟出站延迟、game memory domain/场景过滤、screen session；最后合入最新性格光谱、规则 05、刷新锚底、情绪标签与音效时序。桌宠/TTS 明确不在本批 |
| P2 | +228 候选 CI 全绿 | 真机一次性验收：Token 账单可解释且不十连放大；实时共玩及时、终局可知；单人游戏可连续但不吞掉联网/内省/休息；普通聊天不长期复读游戏；主动种子跨网页、知识、想法、关系、邀约与里程碑；自主联网/相册恢复；Stop 立即终止网页；屏幕时间线、刷新锚底和音效时序正确 |
| P3 | 用户要求继续既有路线 | 从冻结归档顶部“当前任务完成后的后续导航”和 `app/docs/DOCUMENTATION_MAP.md` 定点恢复，不全文读取归档 |

## 8. 关键文件导航

- Cedar 模型入口与循环：`app/lib/core/ai/durable_generation_runner.dart`、`app/lib/core/agent/agent_tool_planner.dart`、`agent_task_loop.dart`、`agent_tool_runner.dart`
- Cedar 玩家协议、Token/节律与状态：`app/lib/core/mcp/cedar_agent_loop_policy.dart`、`cedar_toy_client.dart`、`cedar_toy_activity.dart`、`cedar_game_protocol.dart`、`cedar_toy_autonomy_engine.dart`、`cedar_toy_arcade_skill.dart`、`app/lib/core/ai/deepseek_client.dart`
- UI：`app/lib/features/chat/cedar_toy_activity_window.dart`、`chat_page.dart`、`chat_controller.dart`
- 停止与跨引擎生成：`app/lib/features/chat/chat_controller.dart`、`app/lib/core/ai/durable_generation_runner.dart`、`deepseek_client.dart`、`durable_generation_recovery.dart`
- 主动联系连续性：`app/lib/core/desire/proactive_engine.dart`、`app/lib/core/desire/proactive_presentation.dart`
- 公共联网发现、核验与分享：`app/lib/core/autonomy/public_web_discovery_engine.dart`、`app/lib/core/autonomy/layered_public_web_provider.dart`、`app/lib/core/autonomy/public_web_share_coordinator.dart`、`app/lib/core/autonomy/autonomous_action_coordinator.dart`、`app/lib/core/agent/agent_tool_registry.dart` 及用户回合 `public_web.search` 结果组装路径
- 手机事实层：`app/lib/core/perception/perception_interpreter.dart`、`app/lib/core/perception/current_device_context_refresher.dart` 及 Android Usage/Accessibility bridge
- 表情自主选择：`app/lib/core/stickers/sticker_expression_service.dart`、`app/lib/core/ai/durable_generation_runner.dart` 与 `app/lib/core/desire/proactive_engine.dart`
- 情绪选择与音效：`app/lib/core/ai/prompt_builder.dart`、`app/lib/core/emotion/emotion_contract.dart`、`emotion_classifier_service.dart`、`app/lib/core/ai/durable_generation_runner.dart`、`app/lib/features/chat/chat_controller.dart`、`app/lib/core/tts/emotion_sound_service.dart`
- 世界书、规则与记忆迁移：`app/lib/core/reference/world_book_presets.dart`、`app/lib/core/rules/rule_layer_content_v04155_user_defaults.dart`、`rule_layer_defaults.dart`、`app/lib/core/memory/` 与 `app/lib/core/database/app_database.dart`
- 备份冻结与诊断：`app/lib/features/transfer/transfer_page.dart`、`app/lib/core/database/app_database.dart`、`app/lib/core/sync/snapshot_service.dart`、`app/lib/core/diagnostics/preflight_diagnostics.dart`
- 兼容审计：`app/docs/CEDAR_TOY_GAME_COMPATIBILITY_v0.41.74.md`
- Cedar 现有专项测试与门禁：`app/test/cedar_game_hall_protocol_v04174_test.dart`、`app/tools/validate_v04183_cedar_native_agent_loop.py`
- 停止/备份专项门禁：`app/test/stop_transfer_interlock_v04178_test.dart`、`app/tools/validate_v04178_stop_transfer_interlock.py`
- 冻结历史：`app/docs/ledger/archive/AI_Companion_总账归档_截至_v0.41.74+218.md`
