# AI Companion · 当前总账

更新时间：2026-09-20（Asia/Tokyo）

> 本文件是唯一的当前接班入口，继续采用“总账 v2”。顶部是快速接班索引；标记后的正式记录按版本持续追加，不设总容量上限。
>
> 判断优先级：用户最新明确决定 > 当前 GitHub 源码与 Actions > 同时刻脱敏真机诊断/备份 > 本文件 > 冻结归档与 Git 历史。`DESIGNED`、`IMPLEMENTED`、`CI PASSED`、`APK READY`、`TRUE DEVICE PASSED`、`PENDING` 必须严格区分。

## 1. 接班协议

1. 新窗口先读本文件顶部至 `END QUICK HANDOFF INDEX`，再读取当前任务对应的正式记录、`app/docs/DOCUMENTATION_MAP.md`、当前分支/版本、最近提交和直接涉及的源码/测试；旧问题按索引定点查正文、归档或 Git 历史。
2. 每次正式修改前在“当前任务”登记目标、证据、保护边界与验证；完成后回填实现、提交、CI/APK、真机状态和下一步。
3. 容量约束只用于保持顶部快速索引简洁；标记后的正式内容没有字节上限，不因文件增长强制删减或滚动。自然阶段边界、操作性能明显下降或需要不可变证据快照时才建立只读归档。
4. 已有冻结归档：
   - `app/docs/ledger/archive/AI_Companion_总账归档_截至_v0.41.74+218.md`：1,587,679 bytes；SHA-256 `602c712f0fb06e70c054c2d54fe0e280f312923864040a3a177ee8e7da67ed70`。
   - `app/docs/ledger/archive/AI_Companion_总账归档_截至_v0.41.84+228.md`：98,372 bytes；SHA-256 `47d053d842a73e3ff8107dabe867bd503e8a7e77daaecc2afb1867068faa952c`。它是压缩前当前总账的逐字节快照，包含 +219～+228 的完整诊断、设计、实现与 Actions 证据。

## 2. 永久产品与工程边界

- **主体性优先**：事实与安全 Gate 约束虚假完成、越权、凭据泄漏和不可逆损坏，但不把她训练成处处等待批准的被动工具。
- **模型/API 双通道**：内部判断、维护、工具规划与 Outcome 核验走 DeepSeek；双模型模式只在收齐整轮上下文和真实工具结果后调用一次独立的 OpenAI-compatible 第二通道形成可见回复。第二通道地址和模型可由用户配置，默认仍是原玩游 Gemini 地址与模型；非 Gemini 模型不得收到 Gemini 专属 `google.thinking_config`。MCP 网络请求不是模型调用。
- **真实工具事实**：只有成功的真实 Outcome 能支持“已进入、已落子、已发送、已保存、已完成”。失败、blocked、no_result、超时或零调用不能由对白补写。
- **唯一循环所有权（未来功能开工前必查）**：每个会连续推进的能力必须只有一个 continuation owner，并在设计时写清 `execution_id`、唯一触发源、一次唤醒最多规划轮数/工具调用数/真实 mutation 数、终止条件、Stop、崩溃/主后台切换后的恢复规则。用户回合、后台 cadence、工具 Outcome、UI 轮询和平台 callback 可以提供事件，但不得各自继续同一 execution；`next_call / continuation / resume_after` 是权威事实，不是再启动一条循环的许可。Cedar 曾经让前台 Agent 循环、后台游戏循环和 Outcome 续接同时推进，造成重复调用、Token 暴涨、终局丢失与 Stop 不彻底；此事故模式是永久踩雷样本。
- **循环能力首版诊断（随功能一起交付）**：任何新的 MCP、工作区、视频、提醒、Live2D 长任务或其他可续接能力，第一版就必须以脱敏方式记录 `feature / execution_id / trigger_source / continuation_owner / phase / planning_rounds / tool_calls / committed_mutations / continuation_requested / terminal / preempt / late_write / usage_lane`。诊断不得保存 Prompt、Thought 私密正文、密钥、房间凭据或用户文件内容；没有这组证据，不允许靠继续加 retry/delay 猜修循环。
- **Cortico 低风险参考（未来功能设计索引）**：参考项目为 `https://github.com/Pal-AI-Lab/Cortico`。只吸收两个边界思想：一是外部环境通过“可观察事实 + 可执行工具”接入，World/事件事实不直接等于聊天、记忆或成功声明；二是把 `preempt / flush / debounce / piggyback` 当作按功能选择的投递语义词汇。当前项目不移植 Cortico 的中央 Event Stream、World 容器、完整队列/状态机或记忆连续性取舍，不推倒现有自主逻辑。新增能力逐项建立小型隔离适配层即可：输入只形成验证过的观察，执行只经现有 Agent/Outcome 真值链，是否进入对话、短期桥或长期记忆仍由本项目现有策略决定。
- **Cedar 信任优先**：实时 catalog、玩家指南、合法动作、`next_actor / next_call / revision / legal_actions / resume_after`、防沉迷和终局以服务端为权威；APK 不以本地猜测覆盖。
- **Cedar 盲玩隔离**：运行时只使用 Cedar 玩家接口、当前聊天、正常存档与玩家可见 Outcome；`playerSafeGuide` 不得泄露仓库、源码、隐藏状态、题库答案、攻略、剧透或外部网页。游玩链不暴露 `public_web.search`。
- **自然语义 Agent**：允许“陪我下五子棋”等自然表达触发模型自主发现；普通“看看”不是联网授权。Cedar 的账号级 `allow_self_reset` 服从网站设置。用户已决定暂不增加 Agent 确认弹窗，直到未来加入修改/破坏性能力再设计确认。
- **媒体 Agent**：她能发送的媒体必须同时具备自读能力、可执行工具、真实附件 Outcome、来源 provenance 与发送后第一人称历史；只在 UI 或 Prompt 声称不算完成。
- **隐私与发布**：Token、绑定码、私密房间正文、用户附件、诊断、备份、模型权重和参考音频不得进入公开 Git/Prompt/公开诊断。用户持续授权推送明确开发分支并运行常规 Actions/Draft APK；不含合并 `main`、正式 Release、删除分支/用户数据、改变仓库权限。
- **冻结范围**：桌宠当前无确证问题；TTS 已留在旧归档，均不得在当前批次顺手修改。普通回复表情包已真机重新出现，未发现概率数值漏洞时不强改。

## 3. 当前基线

| 项目 | 当前事实 |
|---|---|
| 仓库 | `catkiss62/ai-companion-build`；Flutter/Android 工程位于 `app/` |
| 功能基线 | `agent/v04184-agent-loop-autonomy-closure`，`v0.41.84+228 / schema 61 / Snapshot protocol 6` |
| 功能状态 | `CI PASSED / APK READY / TRUE DEVICE PENDING` |
| +228 远端 | head `29e87d016c8bd81f52f89f95191bd1a1a01a5b57`；tree `c4a112a56d8b634cf3a1a66636979a0833538b7d`；Actions `35440359036`；Artifact `10583263879`；APK SHA-256 `159e283173e49da2924d25b37ba7647893cdafdcc31b63f0e31b7c64e086849b` |
| 仓库维护基线 | `maintenance/repository-governance-20260919`；远端文档 head `123e272196e8ae93f3518157917d76f6af4f1784`；完整构建 head `fa99f32012fa1a0716b746d36b958a8e777ef9b8`；Actions `35446649873` 全绿；文档-only run `35447342921` 正确跳过 APK |
| 当前功能分支 | `agent/v04193-game-reality-grounding`，从 +236 本地文档 head `1827524` 分出；候选版本 `v0.41.93+237` |
| 当前任务状态 | `IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING`；修复未实际游玩的钓鱼事项被写成“挂着鱼漂等待/漂没动”，+235 疲劳与 +236 欲望竞争继续自然观察，见 6.10 |
| +237 当前任务 | 将未完成游戏事项、旧 ASSISTANT 场景与真实 Cedar 游玩状态分开：没有当前成功 Outcome 时只能说“还没玩/想去玩/之前玩过”，不得虚构正在钓、等待咬钩或图鉴刚才没涨；兼容纠正 +236 前已持久化为 attachment 的游戏 thread Thought |
| +236 当前任务 | 吸收欲望系统 2.0 的可验证因果账本与竞争诊断，不引入女性向保护欲或第二套欲望真值；把游戏“上瘾”改为可被心境、新兴趣与饱和打断、冷却后可重新点燃的短时投入；过滤 `not_due` 空候选、统一游戏语义域并区分游玩与分享 |
| +236 远端 | 构建 head `8ab3beb8997cb146a8499d00acfdf726e2121a2f`；tree `910c3950d354734adca82c58b5db8559fbbcb861`；Actions `35506384676` 全绿；Artifact `10604605761`；APK SHA-256 `b2aad7f827c64e82e58cd88d71db6690c721941d684abe40c80eee537d52bf22` |
| +235 当前任务 | 保留现有昼夜身体疲劳与连续 `rest_need`，新增有界、短时的正向激活与负面难安静调制；自主主动消息和 Cedar 真实推进在高疲劳时积累睡眠债，经过真实安静窗才回补；用户主动聊天始终正常回应，不新增循环、不改 schema、人格、世界书、最终回复通道或 TTS |
| +235 远端 | 构建 head `8ecbcbcaab339fc4ecd0b9c616db2ceacdc83d16`；tree `ee125bd9967b277975decec70b551ba1c7e7918b`；Actions `35501928714` 全绿；Artifact `10602523875`；APK SHA-256 `1489ba5a886d3323f1b68ca913a8f5d166f68133d7786974c04c514abf10e628` |
| +234 当前任务 | Cedar 五槽事实、已有/turn 0 存档续玩、已知空槽自主开档与破坏性覆盖确认边界；将固定玩游 Gemini 选项改为“`双模型（自定义最终回复）`”，地址/模型可编辑并以旧值预填；不改 schema、人格、疲劳、TTS 或内部 DeepSeek 通道 |
| +234 远端 | 构建 head `16589fc8a88574f5a77f0731f8972e65fe990538`；tree `60060c335ba1b064c950ea97a5274bd5fa06f7b5`；Actions `35498575549` 全绿；Artifact `10601008319`；APK SHA-256 `38aadaa9ffb1f2ac3ddac85fffc9311f4c9c75950692130b7c29eee3fa9210f3` |
| +233 当前任务 | 先修 Cedar Outcome Thought 的事件身份、一次分享与时间锚定；再做愿望单安全主题投影；最后只做语义等价的 DeepSeek 缓存观测/低风险优化。三部分独立提交与验证门，不改人格、疲劳、Cedar 玩法/循环所有权或 Gemini 按次回复链 |
| +233 远端 | 构建 head `2892e67d91652b3d8cdec6a989c8467ed0193764`；tree `36747406e22a5accd35f879d7284a0d3370e5a7c`；Actions `35475970152` 全绿；Artifact `10593264636`；APK SHA-256 `ffe58c0dc10f145ec4ce91489478b3b9327304aab8aa1b39a02f58b13229f6e3` |
| +232 目标 | 游戏厅“最近进展”窄面板复用“游戏活动”同款 Card 颜色；愿望单按安全主题表达并合并同主题活动愿望；登记 Cortico 低风险参考、唯一循环所有权与后续诊断护栏；不改 Agent 循环、疲劳、缓存、TTS、schema、世界书或人格 |
| +232 远端 | 构建 head `3783aa7ccae0d547d4a0a1c18d4f388c398be574`；tree `54da8912e76ce5d59ec142387f1708a972196640`；Actions `35469452065` 全绿；Artifact `10592781832`；APK SHA-256 `ccb0352275d197592b1fd5b9a1ca479f89ec21101f472b234e85f8f7d5968622` |
| +231 远端 | 构建 head `75d9e0a311d5b322f53a742b9016aac16d44c9d9`；tree `2b337e3b4d23a1c4bdc097ee999fc569ddafb7fe`；Actions `35464168272` 全绿；Artifact `10591085711`；APK SHA-256 `1b10c1f49f0d192913c2f15e9f46345160cc2c0ee22acf751eb6755a70a3e565` |
| +230 远端 | 构建 head `6c53a40b5d7413942c12ca84001bb66205c160d1`；tree `9c3674e87f37798964e293b1ffdeaedf4e582c74`；Actions `35458277355`（attempt 2 全绿）；Artifact `10589621373`；APK SHA-256 `de27ec0c0146ef3a879f0bb9d8ae2c06dbfdc3225d8f6694fe8e01c7c5ab8d4a` |
| +229 远端 | 构建 head `0f4ffc6c2b08a310a5f04919a045c98b2e8e63e3`；tree `9e0913202787feca13462c07fdd0941f10d0d4b9`；Actions `35450357850`；Artifact `10587305305`；APK SHA-256 `acbd5c81be69c5c27ae2822ea112fb2b0639a00636b61af7b0f642c02fbcddc6` |
| `main` | 仍为 v0.38.5 旧基线；不得作为 v0.41.x 起点，本批不合并 |

历史兼容与未来扩展索引：`v0.41.82+226` / `agent/v04182-cedar-state-machine-e2e`；`v0.41.83+227` / `agent/v04183-cedar-native-agent-loop`；`v0.41.81+225`；`模型自主发现`；`陪我下五子棋`；`全工具调用动作展示`仍是后续独立任务。任何新 MCP、工作区、视频理解、Live2D、提醒或长任务先查本文件的 **“唯一循环所有权”**、**“Cortico 低风险参考”** 与 **“循环能力首版诊断”**，不得再复制 Cedar 曾出现的多套循环。

<!-- END QUICK HANDOFF INDEX -->

## 正式记录（无容量上限）

## 4. +228 已完成、只等待真机验收

- Agent 循环重大回归已收口：前台首次成功 mutation 后结束本轮，后台每 cadence 仅一次规划/一次真实推进；普通聊天不再被活跃游戏自动注入整套工具。DeepSeek usage/cache 已按 lane 记录，诊断查看 `modelUsage.byLane`。
- `CedarExecutableCall`、唯一房间 `rooms → full state → replan`、陈旧 session 水合、终局恰好一次 handoff、`recent_game_episode` 有界短期桥接已实现；不新增吞掉 preference/shared_experience 的顶层 game memory kind。
- 单人游戏进入疲劳/昼夜 Gate 与可衰减饱和仲裁；实时共玩承诺不参与竞争。没有伪造各游戏固定概率或硬每日配额。
- 自主网页能力注册、完整来源证据束、普通“看看”误路由、Stop 贯穿 search/extract/压缩/appraiser、FishArchive 有界换候选、自主相册来源已修复。
- 主动联系以真实普通消息后 10 分钟滑动静默窗推迟；不消费 Thought、分享候选或频率额度，不把新话题改写成 followup。
- `screen_on / screen_off / user_present` 已切分 screen session；长熄屏前活动只能作为低置信度短时历史，不能跨会话冒充持续使用。
- “调皮”收窄到真实逗弄/故意曲解/恶作剧/小挑战；音效在第一段可见正文提交时一次触发；刷新回复恢复跟随最新并锚底。
- 用户新版“性格光谱”已作为内置 preset，SHA-256 `fcc1074203b31cdf36466b39b3b6b08b5abd7497855155c31558177242dfe0fb`，仅保守迁移仍等于旧内置 hash 的记录；规则 05 已加入“每一段动作、神态之后都需要配一段对话。”。

真机必须继续验证：一次聊天不出现多次 Cedar mutation；后台每 cadence 至多一步；真人回合仍及时回应；终局只交付一次；普通“看看氧气瓶”不联网；明确网页查询能引用实际页面证据；Stop 无需杀后台；自主网页/相册恢复；熄屏一小时后不说成连续使用；主动新话题在静默 10 分钟后仍送达；刷新锚底；音效与正文同帧。

## 5. 当前任务：v0.41.85+229 Cedar 结构化远程媒体桥

历史实现分支：`agent/v04185-cedar-media-bridge`。

### 已登记证据

- 最新旅行备份中 `cedar_toy.play` 成功，文本 Outcome 内有多个真实 HTTPS `photo_url`，但事件为 `content_kinds=[text]`、`image_data/viewer_url` 为空，最终消息没有 `assistant_mcp_image`。下矿存在同类协议能力。
- `AgentToolRunner._cedarImageAttachments` 和 `CedarToyActivityStore.recordPlay` 只消费 MCP 标准 `type=image` Base64 block；嵌在结构化结果或 JSON 文本中的明确媒体字段只被当文字。
- 这是 APK 的缺失桥接，不是 Cedar 网络失败、模型忘记发图或游戏厅活动窗识别错误。

### 本批目标

1. 只从 Cedar 成功 Outcome 的协议明确媒体字段提取 HTTPS 图片候选，支持结构化 object/list 以及文本 block 中可安全解析的 JSON；不得扫描自然语言中的任意 URL。
2. 复用现有安全公开图片下载边界：HTTPS、重定向、MIME、字节签名、大小与超时保护；每步限制数量并去重。不得为附件触发 `public_web.search`。
3. 下载一次得到的不可变字节同时用于 `MessageAttachment` 与 Cedar activity/history，避免聊天图、活动窗图和模型所见内容不一致。
4. 任一候选失败只保留真实文本/失败分类，不得声称图片已发出；取消后不得迟到写回。标准 MCP Base64 image 行为不得回归。
5. 增加固定回归：旅行 `photo_url`、下矿等价字段、嵌套 JSON、任意正文 URL 拒绝、非 HTTPS 拒绝、重复/超量、下载成功/失败、附件提交、活动记录、Stop/迟到写入。

### 保护边界

- 不改 Cedar 玩法、回合策略、概率、房间身份、revision、棋步或防沉迷；不写死真机 URL/房间/附件文件名。
- 不扩大为通用网页抓图，不改变公共联网授权判断；不把远程 URL 长期当附件，必须先固化受检字节。
- 本批不处理桌宠、TTS、表情概率、`main` 合并、正式发布或历史清理。

### 验证与完成标准

- 修改前后运行当前总账门、+228 与新增 +229 专项门、全部 validator、`git diff --check`、Flutter Analyze/tests、Kotlin/JVM/Android tests、arm64 Release、签名与载荷检查。
- Actions 与 APK 完成后才可写 `CI PASSED / APK READY`；真机必须分别看到旅行/下矿成功附件和失败降级，才可写 `TRUE DEVICE PASSED`。

### 本地实现与验证（2026-09-19）

- 新增 `CedarOutcomeMediaBridge`：只解析成功 Outcome 的明确协议媒体字段与完整 JSON 文档；拒绝正文 URL 扫描、HTTP、重复项和超量项，最多固化 3 张远程图片、单次 Outcome 总附件最多 4 张。
- `AgentToolRunner` 在 Cedar execution fence 内完成安全下载、字节签名检查、附件固化、Stop 清理与 activity 引用写入；标准 MCP Base64 图片路径保留。单张远程图片失败只降级为真实文本 Outcome，不伪造“已发送”。
- `CedarGameEvent.imageReference` 与聊天附件共用同一个持久媒体引用；活动窗优先读取该引用，旧 `image_data` 仍兼容。
- 新增 `cedar_outcome_media_v04185_test.dart` 和 `validate_v04185_cedar_outcome_media.py`；验证清单已登记旅行、下矿、失败降级、Stop 和诊断证据。
- 本地已通过：109 项 validator manifest 检查、当前总账门、+228/+229 专项门、相关历史门、Python 语法检查、Workflow YAML 解析与 `git diff --check`。本机没有 Flutter/Dart SDK，完整 Analyze/tests/Android Release 必须由 GitHub Actions 判定；在 Actions 成功前保持 `CI PENDING`。

### Actions 与交付证据（2026-09-19）

- 首轮 Actions `35449949853` 在 Flutter analyze 发现新增测试文件末尾误留重复 `import`，构建按预期阻断；已删除该指令，并把“声明后不得再出现 import”加入 +229 专项门，没有绕过分析器。
- 修复后的 Actions `35450357850` 全绿：109 个源码门、Kotlin 桌宠/悬浮层测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/塔罗载荷、Artifact 与 Draft 上传均成功。
- 构建 head `0f4ffc6c2b08a310a5f04919a045c98b2e8e63e3`；tree `9e0913202787feca13462c07fdd0941f10d0d4b9`；Artifact `10587305305`，ZIP digest `16978dba71bc9b581b47f3e2be4113762819a636015fa7a8e417eaa37c3ec024`，大小 `538,036,212` bytes。
- Draft Release `392107130`；APK asset `574973863`，大小 `544,913,702` bytes，SHA-256 `acbd5c81be69c5c27ae2822ea112fb2b0639a00636b61af7b0f642c02fbcddc6`；稳定测试签名未变。
- 当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。仍需真机分别验证旅行与下矿返回真实图片时：聊天附件出现、活动窗显示同一内容、失败只保留文本、Stop 后不迟到补图。

## 6. 后续待办与观察项

### 6.1 2026-09-20 MCP 真机结果后的前置设计记录（已由 6.2 覆盖）

> 本节保留 +230 开工前的证据与设计推导；其中 `PENDING IMPLEMENTATION / PENDING INTEGRATION` 是当时状态，当前事实以 6.2 的已实现、Actions 与真机回填为准，不得再从本节重复开工。

- **MCP 当前结论**：用户已真机确认双弈五子棋完整打通，正常自然语言也能让 Agent 查看/调用 MCP；可把 MCP 主链视为基本完善。该结论证明双弈共玩与 Agent 执行链，不自动替代旅行/下矿远程图片桥的专项验收。
- **游戏兴趣轨迹冻结**：不增加每游戏固定概率、复杂好感/受挫轨迹或新的顶层“贪玩” Drive。模型可依据实时目录、指南、局面、结果和 Cedar Thought 自然形成临时偏向；花园与猫咪等内容较少的游戏可自然失去吸引力，但不伪造持久偏好。
- **游戏重新竞争方案已接受（DESIGNED / PENDING IMPLEMENTATION）**：单人游戏保留短活动惯性；每累计 3 次真正改变远端状态的成功 Outcome，或活动持续 25 分钟（先到者为准），到达一次 episode checkpoint。checkpoint 后把同一局作为可恢复的 `resume_game` 候选，重新与公开网页发现/分享、普通主动联系、休息和沉默走既有 Desire/Thought 仲裁；其他行为胜出时只暂停、不丢远端存档。实时共玩在合法轮到 companion 时继续履行回合承诺，但服务端防沉迷仍是权威硬边界。不得每一步随机换游戏，也不得把“近似并列采样”扩大成纯随机竞争。
- **相册边界**：相册候选处理当前在 Cedar 推进前运行，并非直接被游戏关闭；但游戏每轮成功后会跳过普通主动联网/聊天，可能让网页图片来源枯竭。恢复统一竞争后先观察来源是否恢复，不单独提高相册保存概率。
- **Cedar 防沉迷一手证据（OFFICIAL UI / PENDING INTEGRATION）**：官网设置实际按“连续游玩轮数”计数，不是按连续分钟计数；页面默认 30 轮提醒、50 轮锁定、锁定 30 分钟后自动重置，也允许网页手动重置，存档不受影响。账号开关 `allow_self_reset` 只代表允许小机自行重置，不代表 APK 应自动重置。
- **现有实现与缺口**：休闲模式本地步进间隔为 2 分钟，快速/观战为 5/10 秒；它与服务端轮数/锁定计数是两层机制，本身不冲突。项目已把平台 `rest / announcements / vote` 交给 Cedar 服务端最终授权，并明确 `rest` 只能用于真实防沉迷提醒/锁定；但尚未把提醒、锁定、剩余时间或重置结果解析成持久状态。现有 `recordPlatformAction` 在 session 仍可继续时会于成功 `rest` 后约 1 秒再次推进，不能直接作为最终防沉迷闭环。
- **防沉迷建议（DESIGNED / 等用户最终选择）**：服务端提醒应强制形成 episode checkpoint；服务端锁定时移除普通 `resume_game` 并把游戏 defer 到权威恢复时间。若网站真实返回 `allow_self_reset=true`，可额外生成带明显继续成本的 `self_reset_and_resume` 候选，与联网、主动联系和休息同场竞争；只有它真实胜出才调用一次 `rest`，随后开启新 episode 并恢复正常 2 分钟休闲节奏，禁止 1 秒续跑。没有真实提醒/锁定证据时不得主动猜测或调用 `rest`。
- **最新同刻备份/诊断证据**：`2026-09-20 00:43` 备份和诊断中没有任何 Cedar `rest` 防沉迷动作或自主重置事件；出现的钓鱼“重开新局”属于游戏存档重开，不能当作防沉迷重置。诊断仍显示曾有 `recentActionCount=24 / saturationPenalty=0.28 / playScore=0.8613 / restScore=0` 的继续游玩判定，支持“活动后只和休息竞争”的结构性根因。
- **TTS 音色小改（DECIDED / PENDING IMPLEMENTATION）**：只把“高兴”从“活泼”改为“可爱”；其余情绪映射不动。
- **TTS 参考语音问题（DIAGNOSTIC FIRST）**：用户已确认现象更像播放/复现 `jiuhu_bento_tools.wav`，不是模型随机串入日语。当前生产调用链没有 `playReferenceAsset` 调用者，临时输出也使用 UUID，不先猜测根修。下一批先扩展脱敏诊断：记录语言、voice key、reference case id、清理前后字符类别计数、有效音素数、首轮立即停止、语义 token 数/哈希、输出 PCM 时长/哈希及 `reference_echo_suspected`；不记录正文。四套参考语音 `jiuhu_bento_tools / jiuhu_dream_days / jiuhu_idle50 / jiuhu_devotion` 统一覆盖。拿到同一时刻诊断后再决定是否修复标点/空音素、立即停止强塞 token 0 或输出回声拦截。

### 6.2 v0.41.86+230 实施登记（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

历史实现分支：`agent/v04186-autonomy-tts-diagnostics`。

本批只实施用户已经确认的三组变更：

1. TTS 自动音色只把 `happy / 高兴` 从 `lively / 活泼` 改为 `cute / 可爱`；其他情绪、固定音色、情绪音效和声学模型不动。
2. TTS 只增强脱敏诊断，不在本批猜测根修或阻断输出：覆盖四套 reference case，记录 voice/reference id、输入与前端规范化后的字符类别计数、有效音素、Decoder 首轮停止、语义 token、输出 PCM 时长/哈希及基于退化推理证据的 `reference_echo_suspected`；仍不得写入正文或参考音频路径。
3. 单人 Cedar 活动增加持久 episode checkpoint：每 3 个成功且真正改变远端状态的 Outcome，或 25 分钟先到者触发。checkpoint 只暂停本地续步，不结束、不换局、不损坏远端存档；`resume_game` 回到现有 Desire/Thought 统一选择，与网页发现/分享、主动联系、休息和沉默竞争。实时共玩承诺保持原优先级。

防沉迷实现边界：只解析服务端明确的结构化提醒/锁定/恢复时间/`allow_self_reset`，以及明确包含“防沉迷”的文本提示；普通游戏冷却或失败不得误判。提醒强制 checkpoint；锁定期间移除普通恢复候选。仅当真实证据同时表明提醒或锁定且 `allow_self_reset=true` 时，才提供带明显分数成本的 `self_reset_and_resume`；胜出后只调用一次平台 `rest`，成功后开启新 episode，并按当前休闲/观看节奏继续，禁止旧有成功后 1 秒续跑。没有证据不得调用 `rest`。

明确冻结：不增加“贪玩” Drive、不建立复杂游戏兴趣/受挫轨迹、不修改每游戏概率、不扩大 Agent 确认弹窗、不处理 TTS 声学根因、桌宠、`main` 合并或正式 Release。

完成门：新增纯策略回归与运行链回归；更新当前总账门、版本与测试清单；运行全部 validator、`git diff --check`、Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、签名与载荷检查。只有 Actions 全绿后才写 `CI PASSED / APK READY`；TTS 参考音频和单人 episode 仍需真机报告后才能升级为 `TRUE DEVICE PASSED`。

本地实现与验证：

- `happy` 已单独迁到 `cute`；`excited/surprised` 保持 `lively`。四 reference case 的脱敏 checkpoint/运行诊断已加入原始/规范化字符类别、有效音素、Decoder 次数/首轮停止、语义序列、PCM 时长/哈希和回声怀疑标记；没有增加输出拦截或声学猜修。
- 新增 `CedarSoloEpisodePolicy` 与 `CedarAntiAddictionParser`。episode 状态保存在 settings，不改 schema；只计成功的非只读、非平台、非退出远端动作。第三步或 25 分钟触发 checkpoint，`resume_game / self_reset_and_resume` 进入既有 selector；后者必须同时满足真实防沉迷信号与 `allow_self_reset=true`。普通游戏锁定文本有负例保护。
- `rest` 的后台执行增加本地证据门；成功后由原 1 秒改为当前 viewing pace（休闲默认 2 分钟）。恢复同局若本次真实推进失败，会恢复 checkpoint 并延后 8 分钟，不把失败当成已开启新 episode。实时共玩判定和回合优先级未改。
- 新增 Flutter 纯策略测试、Kotlin TTS 证据测试、+230 跨模块源码门，并更新 110 项 validation manifest、工作流、版本和真机清单。本地逐项运行 110 个源码门：107 个通过；另外 2 个只因仓库按治理规则未携带 CI 才恢复的桌宠/LingChat 私有资源包，1 个只因本机无 `kotlinc` 未运行。`git diff --check`、Python 编译、Workflow YAML 与 +230/+229/+228/总账专项门通过。本机无 Flutter/Dart/Gradle 分发，完整编译测试仍由 Actions 判定。

Actions 与交付证据：

- 构建 head `6c53a40b5d7413942c12ca84001bb66205c160d1`；tree `9c3674e87f37798964e293b1ffdeaedf4e582c74`。首轮 Actions 仅在恢复 LingChat 私有视觉资源时遇到远端 `curl (35) Connection reset by peer`，尚未进入编译；不改业务代码，按同一 run 重跑失败任务。
- Actions `35458277355` attempt 2 全绿：110 个源码门、Kotlin 桌宠/悬浮层与新增 TTS 证据测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/塔罗载荷、Artifact 与 Draft 上传均成功。
- Artifact `10589621373`，名称 `AI-Companion-v0.41.86-230-Autonomy-TTS-Diagnostics-APK`，大小 `538,050,951` bytes，ZIP digest `899a04d4819a6751c41b60a3ada9e62607bb2b7f30dc4969ec874adfac0ce25e`；APK SHA-256 `de27ec0c0146ef3a879f0bb9d8ae2c06dbfdc3225d8f6694fe8e01c7c5ab8d4a`；稳定测试签名 SHA-256 未变：`30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。
- Draft Release 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-4c16dc23432898cc5020`；本批未合并 `main`、未发布正式 Release。当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。

真机回填与非阻塞观察（2026-09-20）：

- 用户已确认“高兴”实际使用“可爱”音色，TTS 自动音色映射这一子项升级为 `TRUE DEVICE PASSED`；不代表参考音频疑似复现问题已经根修。
- 单人 episode checkpoint、游戏与联网/主动聊天/休息/沉默重新竞争，以及 Cedar 防沉迷提醒、锁定和自主重置，均转为低优先级“保留等待测试”。夜间不专门诱发游戏；以后上传自然使用形成的存档和同一时刻诊断时顺带核对，不阻塞下一开发任务。
- 旧总账的 Phase 3 状态保持原判：3A 已 `TRUE DEVICE PASSED`，3B 核心链已 `TRUE DEVICE PASSED / OBSERVING`；3C 的消费注入后来已撤出当前运行能力并暂停待重审，因此不把“Phase 3 重要链已通过”误写成“Phase 3 全部能力仍启用且全部通过”。

### 6.3 旧总账去重后的唯一后续任务清单（2026-09-20）

本节已对照当前源码、`DOCUMENTATION_MAP.md`、截至 +218 与 +228 两份冻结总账去重。旧章节中的“下一步 / PLANNED / PENDING”若已被后版完成、撤回或替代，不再自动复活；以后排期只从本节取。

#### A. 可直接进入开发的任务

| 优先级 | 任务 | 当前准确范围 |
|---|---|---|
| P1 | 设置“帮助”与真实能力清单 | `v0.41.87+231 TRUE DEVICE PASSED`：页面直接消费当前 `AgentToolRegistry`，并整理 `【检查系统】`、联网/网页阅读/图片、查手机、Cedar、Stop、备份恢复、TTS、权限隐私、故障排查与明确限制。用户确认入口与内容正常，且 UI 干净美观；其分节层级、图标、留白、克制的卡片色和可折叠说明作为未来全局 UI 美化的参考方向。 |
| P1 | 本地 Genie TTS 推理速度实验 | 当前生产基线是 CPU 8 线程，旧真机已证明 XNNPACK 会出现异常短音频、NNAPI 无收益。先在独立 `Genie-TTS-Android` 测试工程用同设备/同模型拆出前端、语义 Decoder、声码器、WAV 与冷/热启动瓶颈，并比较 4/6/8 线程、`PerformanceHintManager`/线程优先级、大核调度提示、session/张量缓存和分段预生成；只有证据稳定的引擎级方案再移植到伴侣项目做一次集成 A/B。最终必须是默认关闭的“快速推理”开关，关闭即回到当前路径，并具备温度、功耗、峰值内存、音频完整性、音质与自动回退门。普通 App 不承诺 root 级硬件超频，也不直接恢复已否证的 XNNPACK/NNAPI。 |
| P1 | 全工具调用动作展示 | 把目前 Cedar 已有的活动可见性扩展为统一、脱敏的工具运行状态：搜索、读网页、读系统/记忆/查手机、图片保存/发送等显示“正在做什么/成功/失败/已停止”，不展示 Prompt、密钥、私密参数、房间凭据或内部推理；不改变工具权限与 Outcome 真值。 |
| P2 | 通用 MCP Registry 与未来工作区 | Cedar 专用 MCP 已完成，但通用 `mcp.invoke` 仍为不可执行占位。未来按只读优先分批实现 Server 注册、能力目录、权限、审计、超时、取消、凭据隔离和可卸载；需要处理工作任务时再设计独立合理工作区。OAuth、社区工具与 stdio/Harness 不与陪伴数据库直接混用。 |
| P2 | 真实提醒 | `reminder.schedule` 当前仍为不可执行占位。若开工，必须落到 Android 真实调度、可取消/去重/恢复并有真实 Outcome，不能只靠聊天承诺“到时提醒”。 |
| P2 | 记忆/人设/规则修改提案 | `memory.propose_change / personality.propose_change / rules.propose_change` 当前均不可执行。以后只先做可审查 diff 提案；写入、删除或其他可破坏操作必须增加确认、版本与回滚，当前只读 Agent 不增加多余确认。 |
| P3 | 视频理解 | `video_understanding.inspect` 仍为占位。以后独立评估短片抽帧、预算、临时文件隐私、取消和结果持久化；不冒充当前已能看视频。 |
| P3 | Live2D 反应接入 | 模型、动作和素材已在独立 Live2D 仓库完成；伴侣侧以后专门设计“LLM 语义反应 + 本地低延迟关键词/事件反射 + 动作仲裁/冷却/打断”，避免只等完整 LLM 回复才动，也不得让关键词层直接改写人格或对话。完成基础 P1 后再立专项版本。 |
| P3 | DeepSeek 缓存命中优化 | `v0.41.89+233 CI PASSED / APK READY / TRUE DEVICE PENDING`：已补齐细分 `usage_lane`、body-free 段落顺序/长度/哈希观测，并对工具 schema 做语义等价的确定性 key 排序；没有重排提示词、删记忆或冻结实时状态。后续只在真机积累足够样本后按 lane 对比 `recentPromptShapes` 与 hit/miss，再决定是否存在可证明、低风险的第二步 A/B；Gemini `final_reply` 仍不纳入。 |
| P3 | 疲劳与心境的小幅耦合 | 保留昼夜节律主基线，单独评估负面心情导致难入睡、兴奋/聊天愉快/玩嗨短时压住疲劳的有限偏移；必须有幅度上限、短时衰减、睡眠债回补和防止夜间无限续航。排在 +232 真机包之后，优先在北京时间 2026-09-21 下午至晚上、或后续相同自然时段开专项，便于观察从白天到夜间的真实曲线；不在 +232 顺手改公式。 |

#### B. Phase 3C 与 Phase 4 的准确含义和评估门

- **Phase 3C** 已由用户确认属于持续优化方向中的旧阶段编号，关闭独立待办。3A/3B、Thought、Share Seed、统一自主竞争及后续兴趣/分享调整已经承接它真正关心的“长期偏向会影响自主选择”；+210 的具体消费注入又已在 +211 撤回。因此以后不再以“重做 Phase 3C”排期，只在出现新的、可复现的兴趣连续性问题时按当前架构处理。
- **Phase 4** 是人格成长路线的可选末段，不是基础能力缺口：只在高影响歧义、连续反证或用户主动谈及时低频澄清一次；MBTI、契合度、AI 自拟小测试等只作为娱乐与低权重 `test_result / self_report / inference`，不得一次测试直接改写人格事实。开工前要先判断 Cedar 游戏、普通主动聊天和现有学习证据是否已经覆盖娱乐互动需求，以及澄清是否会让她变成问卷机器人。Phase 3C 没有必要恢复时，Phase 4 也可以作为独立可选功能评估，不再机械等待旧阶段编号。
- **情绪引擎扩建**不再是基础待办：最小 `Appraisal → Emotion Episode` 已在 v0.37.5 实现。只有自然证据持续证明缺少混合情绪、恢复轨迹或多事件调度，并且固定回放有量化收益时，才按 `EMOTION_ENGINE_EXPANSION_EVAL_v1.md` 增加一个模块；否则保持现状。

#### C. 保留等待测试（不阻塞开发）

| 项目 | 以后如何顺带确认 |
|---|---|
| +229 Cedar 远程图片桥 | 旅行/下矿自然返回图片时，核对聊天附件与活动窗是同一内容；失败只保留文本，Stop 后不迟到补图。 |
| +230 TTS 参考音频 | “高兴→可爱”已真机通过；仅当参考音频疑似复现时立即导出同一时刻诊断，用四 reference case 的新证据定位，不猜修。 |
| +230 游戏竞争与防沉迷 | 随以后存档/诊断核对 episode checkpoint、统一竞争、同局恢复、提醒/锁定、`allow_self_reset` 和自主重置；夜间不专门诱发。 |
| +228 自主性与屏幕时间线 | 继续自然观察 Token 账单、主动联网/相册、10 分钟静默窗、长熄屏、刷新锚底、表情/音效时序；出现异常才提交同刻证据。 |
| Phase 3A/3B 长尾 | 跨日期兴趣成熟/撤销/新鲜度，以及额度耗尽或能力关闭时的 capability defer 随自然数据观察；核心真机状态不倒退。 |
| Memory 2D 与 D6 媒体备份长尾 | 精确取消/自然主动回忆/工作话题占比，以及删除媒体后的备份、重复迁移、相册引用保护、缓存删除和跨机恢复，有自然样本再回填。 |
| 低概率显示/状态问题 | 表情发送占比、duel“轮到你”、偶发多余 `「`、TTS/桌宠异常均只在明确复现后窄修，不靠概率猜测。 |

#### D. 冻结、可选或需用户重新排期

| 状态 | 项目 | 决定 |
|---|---|---|
| `REMOVED FROM BACKLOG` | MiniMax 在线语音 | 用户确认当前本地小酒狐 Genie TTS 效果更好，MiniMax API、在线/本地双引擎选择、在线音色筛选与 emotion 映射全部从后续任务删除。冻结归档中的 MiniMax 只保留历史证据，不得再次自动排期。 |
| `FROZEN` | 当前屏幕像素观察与自主截图 | 现有 `screen_observation.inspect` 曾在视觉 Provider 前失败；先补系统截图 capability/阶段诊断才可重开。自主截图仍未实现，不因知道 App 名称而声称看见屏幕。 |
| `FROZEN` | HyperOS 文件选择器/系统导航键/悬浮间歇卡死 | 指三类旧真机原生问题：系统文件选择器偶发输入/返回挑战、系统导航键后悬浮层恢复异常、部分 App 切换时桌宠/悬浮层间歇消失或卡死。当前没有持续复现，项目末尾如重开，先取得输入挑战、动画心跳、window generation 与 enter/exit 时间线，不再叠加 retry/delay。 |
| `OPTIONAL` | 主动消息直接带表情、GitHub 灵感库、X/Telegram Provider | 都是新增能力，不是当前概率回归。只有用户再次选择才设计；普通回复表情、通用公开网页和现有媒体链继续保持。 |
| `OPTIONAL` | 手机主存储/平板伴随端、完整换肤、产品化发布 | 独立大型路线，不进入当前陪伴核心维护。平板伴随端先依赖未来视频理解/“陪玩或陪看”能力的正式定义，当前不预判具体方案；`main` 里程碑晋升与正式 Release 仍需用户明确授权。 |
| `MAINTENANCE` | 当前契约文档合并 | 可逐步把人格、Somatic、Inner Drive 重叠文档合并为当前契约；不改变 App、不阻塞功能开发。 |

#### E. 已完成、不得从旧总账重复开工

- Phase 0+1 审查、Phase 2A/2B、Phase 3A、Phase 3B 核心链；Memory 2D 主链、Dynamic Moe D2/D3、最小 Emotion Episode、查手机七日心情/购物车/侧栏、公开网页完整阅读与分享、Agent 自身系统读取、Agent v2、表情和双向图片、Cedar MCP/双弈/终局/连续循环、+228 Agent 循环与自主性收口、+229 远程媒体桥、+230 episode/防沉迷和 TTS 诊断均已有实现或明确状态。
- 角色扮演持续性由用户确认已解决：根因是旧输出模型理解能力与文本表现，切换 Gemini 为文本输出口后不再复现；从冻结任务删除，除非出现新的可复现证据不得重开。
- `PENDING / PLANNED` 只出现在冻结归档的历史段落时，不足以证明今天仍是任务；必须先与本节和当前源码核对。

### 6.4 v0.41.87+231 帮助页与游戏厅活动窗（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

历史实现分支：`agent/v04187-help-cedar-activity-ui`。

本批范围：

1. “全部设置”新增“帮助与真实能力”。普通聊天与自主工具清单直接读取运行时 `AgentToolRegistry` 的 `executable/userTurnAvailable/autonomousAvailable`，避免静态帮助把占位能力写成已可用；同时说明 `【检查系统】`、Stop/刷新、网页/图片/查手机、Cedar、本地 TTS、备份、权限隐私、故障取证和当前明确限制。
2. Cedar 活动窗“最近进展”改为居中 84% 宽度的窄卡片，左右保留外层滚动命中空间；文本仍可选择，最多 12 行的现有边界保持。
3. 活动记录继续显示三行摘要，但增加点击详情；详情可滚动查看完整 summary、动作、时间、图片和该事件 viewer URL，不执行游戏动作、不修改 session。
4. 不改变 Agent 权限/自然语言路由、Cedar 指南/循环/防沉迷/概率、数据库 schema、TTS 运行时、世界书、人格或 `main`。

本轮追加设计记录：Phase 4 继续作为可选人格澄清/娱乐测试，不因 AI 偶尔自然提问而强制开工；需要另查自然问题的用户资料写入证据链。TTS 快速模式先在独立 TTS 工程做引擎基准，再将证实有效的方案以默认关闭开关移植；Live2D 反应接入与疲劳—心境小幅耦合均登记为独立后续任务，不与 +231 混改。

Actions 与交付证据：

- 远端功能提交 `75d9e0a311d5b322f53a742b9016aac16d44c9d9`，tree `2b337e3b4d23a1c4bdc097ee999fc569ddafb7fe`；`main` 未修改。
- Actions `35464168272` 全绿：111 个源码/历史回归门、Kotlin 桌宠/悬浮层测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传均成功。
- Artifact `10591085711`，名称 `AI-Companion-v0.41.87-231-Help-Cedar-Activity-UI-APK`，大小 `538,056,010` bytes，ZIP digest `f64bbe778527f0a6ca3851394f6e398b2322f1cdba53af56d7ffc1050a3e012b`；APK `544,935,646` bytes，SHA-256 `1b10c1f49f0d192913c2f15e9f46345160cc2c0ee22acf751eb6755a70a3e565`。
- Draft Release 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-83ba209cc91853c32913`；仍是测试 APK，不是正式 Release。真机只需验收帮助页入口/内容、最近进展左右滑动命中区和活动记录详情。

真机回填：用户确认本批功能正常；帮助页入口和内容没有问题，排版被确认为干净美观。最近进展窄面板的左右拖动范围与活动记录详情均通过，唯一追加意见是窄面板颜色应与上方“游戏活动”Card 完全相同，该视觉收口进入 +232。

### 6.5 v0.41.88+232 愿望单主题身份、Cedar 同色卡片与扩展护栏（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PARTIAL`。

历史实现分支：`agent/v04188-wishlist-cedar-card-guardrails`。

本批范围与证据：

1. Cedar 活动窗保留“最近进展”居中 84% 宽度与左右外层拖动命中区，但面板从单独猜测的 `surfaceContainerHighest + border` 改为和“游戏活动”完全相同的 Material `Card`；不改文字、12 行边界、活动状态或游戏执行。
2. 愿望单固定句的根因已经定位：旧实现仅按 `drive_key` 返回一句固定正文，且活动愿望只按 `source_thought_id` 去重；同一钓鱼主题产生多个生命周期 Thought 时，会被当成多个不同愿望并重复显示“想认真找点没见过的新鲜东西看看”。
3. +232 以 `drive + canonical safe topic` 作为活动愿望身份，统一 `cedar_game:fishing` 与 `shared.activity.fishing` 等明确同主题别名；同主题的新 Thought 会接续并重绑定原愿望，不增加第二条。正文只从 drive、topic key 与 provenance 分类生成，明确禁止读取或呈现 Thought 私密正文。已完成历史只迁移展示版本，不伪造完成、不强制增加愿望数量；原有 6 小时新增冷却、每日预算、强度/复现/基线与满足条件保持。
4. 将 Cortico 参考地址与“观察事实/执行工具隔离、按功能选择投递语义”写入永久边界；同时将 Cedar 多循环事故提炼为“唯一循环所有权”和首版诊断要求。只增文档护栏，不引入中央 Event Bus、World 容器、完整队列/状态机，也不修改现有 Agent/Cedar 循环。
5. 明确不改：数据库 schema、世界书/用户已修改的性格光谱、人格、Desire/Thought 生成与满足逻辑、Agent 权限/自然语言路由、Cedar 玩法/防沉迷/竞争、TTS、疲劳公式、DeepSeek 缓存实现、`main` 或正式 Release。

真机验收只看三点：进展窄卡颜色是否与“游戏活动”一致；旧固定愿望在一次正常“查手机”刷新后是否迁移；同一钓鱼/旅行主题反复形成 Thought 时活动愿望是否只保留一条且正文能说明主题。不得为了造样本修改真实欲望或游戏偏好。

本地验证：+232 专项门、Workflow YAML、Python 编译与 `git diff --check` 通过；逐项运行 112 个源码/历史门，109 个通过。其余 3 个与本批代码无关：仓库按治理规则不携带 CI 才恢复的 417 文件桌宠源码包与 LingChat 特效包，本机也没有 `kotlinc`；Actions 会在恢复资源和安装工具后执行完整 Flutter analyze、Flutter tests、Kotlin 测试与 arm64 Release 构建。

Actions 与交付证据：

- 远端构建 head `3783aa7ccae0d547d4a0a1c18d4f388c398be574`，tree `54da8912e76ce5d59ec142387f1708a972196640`；`main` 未修改。首次分支创建 run `35469348788` 被随后用于确保 push 事件的同树 CI 提交按 `cancel-in-progress` 正常取消，不是编译失败；权威结果只取新 head。
- Actions `35469452065` 全绿：112 个源码/历史门、Kotlin 桌宠/悬浮层测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传全部成功。
- Artifact `10592781832`，名称 `AI-Companion-v0.41.88-232-Wishlist-Cedar-Card-Guardrails-APK`，大小 `538,061,525` bytes，ZIP digest `de6b7f2fd789d3d3e0d195ab7f6a6851fcb834aa783955bd8d33d3462b549aea`；APK SHA-256 `ccb0352275d197592b1fd5b9a1ca479f89ec21101f472b234e85f8f7d5968622`；稳定测试签名 SHA-256 未变：`30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。
- Draft Release 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-8043368def99d2e0f7b0`；仍是测试 APK，不是正式 Release。

真机回填与持续观察：

- 游戏厅“最近进展”卡片颜色已确认与“游戏活动”一致，升级为 `TRUE DEVICE PASSED`。
- 旧固定愿望在正常刷新后已确认写法发生迁移，升级为 `TRUE DEVICE PASSED`；其中未知主题仍可能落入“想认真弄明白最近惦记的那个问题”等过度模糊兜底，这属于 +233 的安全主题投影改进，不推翻迁移成功结论。
- 同一钓鱼/旅行主题长期只保留一条愿望仍随自然数据持续观察，不阻塞开发，不为造样本修改真实欲望或游戏偏好。

### 6.6 v0.41.89+233 Cedar 事件时序真实性、愿望安全主题与缓存命中（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

开工证据与边界：

1. 同一时刻备份 `AI_Companion_Backup_2026-09-19T22-01-12.aibackup` 与诊断 `ai_companion_diagnostics_2026-09-19T22-01-20-863164Z.txt` 证明：最新主动消息声称“刚在钓鱼里连甩了十竿”，本轮没有新的 `cedar_toy.play` Outcome；它复用了来源事件 `play-1789520410317668` 的旧钓鱼正文。对应 Thought 已跨同主题合并 1759 次、累计主动 action 37 次，原始事件时间与 `updated_at` 被维护/合并刷新的时间严重分离。
2. 根因是结构性的而非钓鱼词表单点：Thought consolidation 把所有相同 `cedar_game:<game>` 主题当重复项合并；合并保留旧事件来源/正文，却刷新 `updated_at`；主动出站又把任意 `mcp/cedar_game:*` 来源直接视为有 Cedar Outcome，未验证具体事件是否新鲜。高疲劳只改变竞争结果，不是伪造根因。
3. Cedar Outcome Thought 必须保留不可混合的事件身份：不同事件不得只因游戏主题相同而合并；同一真实 Outcome 最多主动分享一次；超过 48 小时的 Outcome 不再主动翻出分享，但仍可在用户对话、长期记忆和历史回忆中以“之前/上次”等形式出现。
4. “刚才/刚刚/刚在”等即时表达只由 60 分钟内的具体成功 Outcome 授权；维护、合并、复活或候选选择不得刷新证据时间。超过窗口仍可分享真实旧事，但必须使用历史时间锚。规则覆盖所有 Cedar 游戏动作，不写成钓鱼专属补丁。
5. 愿望单继续保护 Thought 私密正文。未知主题不得直接展示任意 topic key 或内部推理；只使用独立、受约束的安全公开主题。缺少安全主题时不再伪装成“那个问题”，也不为写详细而发明新目标或改变成长分数。
6. 缓存优化排在上述真实性修复之后。先补不含 Prompt 正文的段落类别、顺序、长度与哈希观测，再只调整稳定前缀、动态尾部和确定性序列化；Gemini `final_reply` 不纳入，禁止删记忆、冻结实时状态、弱化工具真值或重新合并已隔离的 Agent/Cedar 循环。

实施顺序与提交门：Cedar 时序真实性、愿望安全主题、DeepSeek 缓存分别独立提交并运行专项回归；最后才更新版本、总账与完整 validator。Actions 全绿只升级为 `CI PASSED / APK READY`，Cedar 历史时态、愿望显示与缓存行为仍需真机分别确认。

本地实现与验证：

- Cedar 事件身份已从可刷新的 `updated_at` 中剥离：优先从 `mcp/cedar_game:<game>:play|invite-<微秒时间戳>` 解析不可变发生时间，只在旧来源无法解析时退回 `born_at`。不同 Cedar 事件即使 topic 相同也不再 consolidation；已有 `action_count / last_acted_at` 的事件不可再次成为主动分享候选。主动分享只接受 48 小时内事件；“刚才/刚刚/刚在”等即时锚只接受 60 分钟内事件，维护、合并和候选选择均不能续期。旧事仍可在正常聊天中按“之前/上次”等历史方式回忆。
- 愿望展示升级为 presentation v3，并只投影受约束的 `safe_subject_key`。钓鱼、旅行、下矿、对弈、花园猫、韭菜、共同花园、纪念日以及少量 AI 自主性/身份/交流/爱好主题有具体公开文案；活动别名统一到同一 subject。未知 curiosity 主题不再生成新的公开愿望，旧愿望若已失去安全主题则诚实显示“旧记录没有保留具体主题”，不会读取 Thought 私密正文或编造目标；Thought 本身仍保留。
- DeepSeek 统计已把原先混在 `unclassified` 的日记、随笔、购物车、记忆整合、人格证据复核、摘要、翻译、亲密路由、沉浸房间与自我反思拆成独立 lane；Cedar 选游戏也从后台动作规划中拆为 `cedar_game_choice`。每次 provider usage 同步记录消息段的顺序、角色、字符数、12 位 SHA-256 与工具 schema 数量/长度/哈希，不记录 Prompt/响应正文、工具字段值或凭据；诊断只带最近 24 次 shape，便于下一轮按真实前缀变化 A/B。
- 本批缓存改动只对工具 schema 的 Map key 做递归确定性排序，字段、数组顺序、工具选择、消息内容与消息顺序保持不变；没有为了命中率重排系统指令、删记忆、冻结实时上下文或合并循环。两个语义完全相同但构造 key 顺序不同的 schema 已有固定回归证明会发出同一规范序列并得到同一 body-free hash。
- 三项 +233 专项门、+232/+228 回归门、115 项 validator manifest、Workflow YAML、Python 编译与 `git diff --check` 已通过；逐项运行 115 个源码门时 112 个通过，余下 3 个只因仓库按治理规则不携带 CI 才恢复的 417 文件桌宠源码包与 LingChat 特效包，以及本机没有 `kotlinc`。本机也没有 Flutter/Dart SDK，新增 Dart 回归、Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、签名与载荷检查仍必须由 Actions 判定；在此之前保持 `CI PENDING / TRUE DEVICE PENDING`。

真机验收边界：自然观察旧 Cedar 事件只以历史时态出现且同一 Outcome 不重复主动分享；愿望只显示安全具体主题或诚实旧记录说明；积累足够新 usage 后导出同刻诊断，对比各 lane 的 `recentPromptShapes` 与 provider cache hit/miss。缓存命中率允许受实时上下文影响波动，不能只凭一次样本判失败或继续扩大改动。

Actions 与交付证据：

- 远端四个功能/版本提交经 Git data 接口按本地顺序建立，最终内容树与本地候选逐字节一致；随后两个测试迁移提交修正 CI 暴露的回调类型和旧版本/未知主题样本。权威构建 head `2892e67d91652b3d8cdec6a989c8467ed0193764`，tree `36747406e22a5accd35f879d7284a0d3370e5a7c`；`main` 未修改。
- 首轮 Actions `35475149658` 在 Flutter analyze 精确发现新增测试把同步 `usage.add` 传给异步 usage callback；修复后第二轮 `35475536151` 的 analyze 已通过，869 项 Flutter 测试中 867 项通过，剩余 2 项只是系统自读仍期待 +232、普通基线愿望仍使用已被安全策略拒绝的未知主题 fixture。两项测试迁移没有放宽生产策略。
- Actions `35475970152` 全绿：115 个源码/历史门、Kotlin 桌宠/悬浮层测试、Flutter analyze、全部 869 项 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传全部成功。
- Artifact `10593264636`，名称 `AI-Companion-v0.41.89-233-Cedar-Temporal-Wishlist-Cache-APK`，大小 `538,070,382` bytes，ZIP digest `5055b7b8a30df4009b45fbda7f6f6fe8a259a3baf09d363afed25a8b70f61821`。
- Draft Release `392248211` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-a51ec6f40ce0543f3558`；APK asset `575682174`，大小 `544,947,802` bytes，SHA-256 `ffe58c0dc10f145ec4ce91489478b3b9327304aab8aa1b39a02f58b13229f6e3`。稳定测试签名仍为 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。

### 6.7 v0.41.90+234 Cedar 五槽自主性与可配置最终回复通道（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04190-cedar-save-slots-custom-final-model`。

根因与产品决定：

1. 最新同刻备份证明钓鱼 slot 1 与瓶中生态 slot 1 各自保存不同状态，Cedar 指南也明确写明“每游戏 5 槽，slot=1-5，缺省 1”；此前“覆盖鱼塘”并不是两个 game 共用同一存档，而是瓶中生态的 `eco_new` 命中了瓶中生态自己已有的 turn 0 slot 1。该初始档可能由官方人类前端/服务在只查看时建立；后续 `eco_observe` 与 `eco_act` 已证明它可直接继续。
2. APK 原先只把五槽说明埋在长指南正文，`cedar_toy.play` 的本地参数说明没有明确告知 Agent；后台也没有“空槽可自主使用、已有槽不可自主覆盖”的确定性边界。因此模型可能重复 `new`，却不能可靠表达槽位自主性。
3. 用户决定保持主体性：已有长期档默认继续；她确实想开新周目/新世界时可自主使用已知空槽，不必每次申请；只有覆盖已有槽、导入覆盖或 `confirm:true` 才必须取得用户明确同意。未知槽不能猜为空，room/session 类无五槽声明的游戏不受此规则影响。
4. 原“Gemini 3.7 Flash（玩游）”设置的地址与模型不仅在界面只读，运行时还会按固定网址把模型强制改回固定别名。只把控件变成输入框会形成假配置，必须让存储、普通聊天、沉浸房间、重试与连接测试都真正传递用户输入。

本地实现：

- 新增 `CedarSaveSlotPolicy`，只在实时指南明确声明五槽时生效：识别已有存档/覆盖提示，阻止后台 `confirm:true` 和冲突后的重复 new/create/start/reset/import；用户回合若没有明确的覆盖同意也会在调用远端前阻断。Agent Prompt 同时解释 game 间同号槽相互独立、turn 0 初始档可能由官方前端/服务建立、已有档优先观察/继续、已知空槽可自主开档。
- `cedar_toy.play` 的 `params_json` 说明补入 `slot=1..5` 与 `confirm:true` 边界；后台规划验收与执行前各有一层保护，避免模型重试或未来调用路径绕过。没有建立本地第二套存档服务器，也没有硬编码钓鱼/瓶中生态 game ID。
- 最终回复选项显示为“`双模型（自定义最终回复）`”。第二通道地址、模型 ID 改为可编辑输入框，默认读取旧玩游地址 `https://wy.aiwangyou.cc/v1/chat/completions` 和旧模型 `[特价]gemini-3.7-flash-0.5`；原 API Key 槽保持不变，升级不丢旧 Key。DeepSeek 仍是必填内部通道。
- `DeepSeekClient` 新增显式 provider/model override：自定义网址不再因为 host 变化被误判回 DeepSeek；用户输入的模型名原样进入请求。模型名含 Gemini 时保留原 `google.thinking_config`，其他 OpenAI-compatible 模型不发送 Gemini/DeepSeek 专属 thinking 字段。连接测试、普通聊天最终回复、沉浸房间首次生成和重试均使用同一配置。
- 新增 `cedar_save_slot_autonomy_v04190_test.dart` 与自定义第二通道请求回归，并登记 `validate_v04190_cedar_save_slots_custom_final_model.py`。版本提升为 `v0.41.90+234`，schema 保持 61。

本地验证：新增专项源码门、相关历史门、Workflow YAML 解析、Python 编译与 `git diff --check` 通过。完整 validator manifest 在仓库精简态运行到桌宠源码包门前均通过，随后按预期因 CI 才恢复的 417 文件桌宠源码包缺失而停止；本机没有 Flutter/Dart SDK，Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、签名与载荷检查必须由 GitHub Actions 判定。因此当前不得写 `CI PASSED / APK READY`。

真机验收：进入已有瓶中生态 turn 0 档时应观察/继续，不再把它说成钓鱼串档；已知空槽可由她自主选择，新建已有槽时必须询问且未确认前不发送 `confirm:true`。模型设置应显示旧值预填，可修改地址和模型并通过连接测试；普通聊天与沉浸房间都应使用新模型，第二通道失败仍由内部 DeepSeek 兜底。兼容性边界是 OpenAI Chat Completions 风格接口，不保证任意非兼容协议仅靠改名字即可使用。

Actions 与交付证据：

- 首轮 run `35498239554` 在 Android/Kotlin 测试触发 Flutter Debug 编译时准确发现 `_execute` 未接收新增 `origin` 参数；修复只补齐 `runPlan → _execute → _cedarPlay` 的既有来源传递，没有放宽覆盖授权。修正后的远端 head `16589fc8a88574f5a77f0731f8972e65fe990538`、tree `60060c335ba1b064c950ea97a5274bd5fa06f7b5` 与本地候选逐字节一致，`main` 未修改。
- 权威 Actions `35498575549` 全绿：116 个源码/历史门、Android/Kotlin 桌宠与悬浮层测试、Flutter analyze、874 项 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传均成功。
- Artifact `10601008319`，名称 `AI-Companion-v0.41.90-234-Cedar-Save-Slots-Custom-Final-Model-APK`，大小 `538,070,111` bytes，ZIP digest `980612367c76ef21a6dd4c06ba72057d296084fc8289bbd6e7a322fcf49cb901`。
- Draft Release `392355306` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-dde0b23c877ee349a101`；APK asset `576421689`，大小 `544,947,946` bytes，SHA-256 `38aadaa9ffb1f2ac3ddac85fffc9311f4c9c75950692130b7c29eee3fa9210f3`。稳定测试签名仍为 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。

### 6.8 v0.41.91+235 疲劳—心境小幅耦合与睡眠债（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04191-fatigue-affect-debt`。

开工证据与产品边界：

1. 同刻备份 `AI_Companion_Backup_2026-09-20T08-40-20.aibackup` 与诊断 `ai_companion_diagnostics_2026-09-20T08-40-24-240119Z.txt` 证明现有身体疲劳骨架正常：过去 24 小时疲劳最高约 `0.792`；单一连续 `rest_need` 于北京时间 02:08 建立、07:47 恢复；02:21 强依恋临时胜出一次并增加 `0.0825` 身体疲劳，02:27 自然结束互动，之后约五小时没有继续主动折腾。此次不重画昼夜曲线、不取消强念头偶尔顶困，也不把一次未复现当作所有长尾验收完成。
2. 心境不能直接改写身体是否疲劳。正向亲近、重逢、修复或正在投入的活动只短暂降低一小部分休息竞争与行动阻力；伤心、分歧、未被接住只形成“身体累、心里难安静”，会稍微降低入睡顺畅度，同时提高外向行动阻力，绝不能把负面情绪算成精神变好。
3. 高疲劳下的自主主动联系与 Cedar 真实写动作会积累独立、上限 `0.18` 的睡眠债；普通用户消息、AI 正常回复、只读 observe/state、失败或取消不增加债。睡眠债不直接伪造 Drive 数值，但会提高后续休息分数与行动阻力；即使白天身体疲劳已降低，未偿还的债仍可形成恢复压力。
4. 睡眠债只有在最后一条真实聊天或自主消耗之后连续安静 90 分钟才开始线性回补，约每小时 `0.025`；继续聊天会重新推迟回补，避免把普通回复误当睡眠。所有数值有确定上限、可跨进程恢复，不引入新的周期任务或第二套疲劳循环。
5. 用户主动聊天从不经过拒答 Gate；调制只影响自主候选排序、公开网页发现与 Cedar 继续游戏的统一 Desire 竞争。无人观看的凌晨 Cedar 07:00 前硬休息边界保持不变；真人正在观看仍是用户节奏例外，但真实推进会留下较小睡眠债。

本地实现：

- 新增纯策略 `FatigueAffectPolicy` 与薄持久层 `FatigueAffectController`。正向激活、负面难安静均只从现有证据化 Emotion Episode 计算；睡眠债以 `settings` 中的有界状态保存，schema 保持 61。策略没有模型调用、随机源、定时器或独立循环。
- `DesireCorePolicy` 的 rest score 与 action penalty 接受同一调制快照；现有身体疲劳值和昼夜 floor 不被减写。高债状态可以在白天继续形成恢复候选，直到真实安静窗逐步回补。
- 主动联系、公开网页发现和 Cedar continuation 共用同一快照。主动消息已送达或 Cedar 远端 mutation 已提交后，睡眠债写入失败不会把真实成功重判为失败，也不会重试远端动作。
- 情绪 Prompt 只注入结构化的“暂时激活 / 又累又难静 / 睡眠债恢复”表达边界；不暴露消息正文，不让模型声称心情已经消除身体困意。诊断新增 `affectMode / positiveActivation / negativeRestlessness / sleepDebt / 两类评分修正 / 最近自主消耗`，不包含 Thought 或消息正文。
- 新增 `fatigue_affect_debt_v04191_test.dart`，覆盖正向激活、负面难安静、睡眠债压过连续兴奋、90 分钟真实安静窗、白天回补压力、Cedar 共用仲裁与凌晨无人观看硬边界。

本地验证：新增 +235 专项门、当前总账门、相关历史门、Workflow YAML 解析与 `git diff --check` 均通过；逐项执行 117 个 validator，114 个通过。其余 3 个是仓库精简环境的既有缺项：CI 才恢复的 417 文件桌宠源码包、LingChat 特效资源包，以及本机未安装 `kotlinc`；不属于本次疲劳逻辑失败。当前环境也没有 Flutter/Dart SDK，因此当时保持 `CI PENDING / APK NOT READY`，完整结果现已由下方 GitHub Actions 补齐。

Actions 与交付证据：

- 首轮 Actions `35501454096` 已通过 117 个源代码门、Kotlin 与 Flutter analyze，在全量 Flutter tests 中准确拦住两条测试契约不同步：新用例寻找字面“又累”而真实策略文案为“身体已经累了”，旧系统自读用例仍写死 +234 构建号。只修正这两条精确断言并保留 +234 历史 token，没有改策略、跳过测试或放宽 Gate。
- 修正后的 Actions `35501928714` 全绿：117/117 源代码与历史门、Android/Kotlin 桌宠及悬浮层测试、Flutter analyze、881 项 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传均成功。构建 head `8ecbcbcaab339fc4ecd0b9c616db2ceacdc83d16`，tree `ee125bd9967b277975decec70b551ba1c7e7918b`；`main` 未修改。
- Artifact `10602523875`，名称 `AI-Companion-v0.41.91-235-Fatigue-Affect-Sleep-Debt-APK`，大小 `538,076,602` bytes，ZIP digest `5221f74cd5368748aae3af177b24041c5ddbbcd1189c2e93c089f348ea41dad4`。
- Draft Release `392375712` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-6bfa04031f233b81dfa6`；APK asset `576530601`，大小 `544,955,098` bytes，SHA-256 `1489ba5a886d3323f1b68ca913a8f5d166f68133d7786974c04c514abf10e628`。稳定测试签名仍为 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。

真机验收边界：北京时间下午到夜间自然使用即可，不诱发争吵或强行熬夜。重点核对：白天低债不改变正常主动性；聊天愉快时夜间可自然多撑一小会儿但不会声称恢复体力；负面心情表现为累且难静而非亢奋；高疲劳主动一次后下一次更难发生；停止互动并安静后第二天债逐步下降；用户主动发消息始终正常回复；无人观看 Cedar 凌晨不连续推进。当前保持 `TRUE DEVICE PENDING`，自然观察前不得写 `TRUE DEVICE PASSED`。

### 6.9 v0.41.92+236 欲望因果账本与动态游戏投入（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04192-desire-game-interest`。

开工证据与产品边界：

1. 最新同刻诊断 `v0.41.90+234` 与 schema 61 备份证明，最近约 79 分钟 26 个自主行为事件中 18 个是 `play_game|mcp|not_due`。根因不是“她太爱游戏”本身，而是 checkpoint 恢复候选在 continuation 尚未到期时仍参加竞争；它以最高约 `0.92` 胜出后才返回 `not_due`，占掉本次 heartbeat，其他真实候选没有再选择机会。
2. 游戏分享同时从 Cedar MCP Outcome、`self_drive/thread` 未完成事项与用户历史进入。钓鱼 thread 已累计 `fedCount=74 / actionCount=21`；现有 self-drive 把所有低于 `0.72` 的未完成 thread 一律归为 attachment，使游戏内容不当地借用依恋欲望。游戏 Outcome 分享强度最高 `0.94`，普通自我回顾通常仅 `0.18–0.46`，跨来源同主题没有统一语义域，导致“游戏总赢”既有真实投入也有结构性重复放大。
3. 本批允许阶段性玩游戏上瘾，但不新增永久“贪玩” Drive 或固定游戏人格。游戏投入只能由真实 Cedar 推进、近期显著事件、当前心境、疲劳与时间衰减派生，经历 `spark / flow / saturated / cooling / available`；心情不好、新兴趣、重复安静结果与饱和可以打断，冷却后允许重新点燃。
4. “想玩”与“想分享”必须分开：普通成功步骤只维持短时活动惯性，显著/有趣/终局/邀请或与用户相关的事件才形成强分享。Cedar、self-drive 与用户历史中的同一游戏主题统一进入同一有界语义冷却域，真实分享后压低同主题兄弟候选，不删除 Thought 或远端存档。
5. 吸收作者欲望系统 2.0 的部分限于：记录每个 drive/action lane 的最近真实满足、次数与来源；增加零使用/单一路径支配/无效胜出诊断；给长期未获机会但本身合格的动作一个很小的有界公平加成。不引入女性向保护欲、成功后永久抬高 baseline、固定 15% 随机探索或第二套欲望真值。
6. +235 疲劳核心、睡眠债、Emotion Episode、Thought 生命周期、Cedar 唯一 continuation owner、服务端防沉迷与存档槽边界保持不变；本批不改人格、世界书、TTS、双模型最终回复、schema 或 `main`。

计划验证：新增纯策略与集成回归，覆盖 continuation 未到期不入场、游戏阶段的投入/饱和/冷却/重燃、负面心境可打断、游戏 thread 归 curiosity、跨来源语义域、游玩与分享分 lane、真实满足账本兼容解析、无效胜出与支配诊断。随后运行全部 validator、Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、签名与载荷检查；只有 Actions 全绿后才写 `CI PASSED / APK READY`。

本地实现与验证：

- 新增纯 `GameEngagementPolicy`，只从当前 session 中成功且非只读的 Cedar Outcome 时间、显著事件和既有 fatigue-affect 快照派生 `spark / flow / saturated / cooling / available`。近期真实进展和显著事件形成短时 momentum；六小时内重复普通推进产生有界 saturation；90 分钟后进入 cooling，八小时后旧饱和清零并允许重燃；负面难安静最多形成 `-0.12` 的游戏调整，正向激活最多 `+0.04`。它没有持久人格值、随机源、模型调用、定时器或第二循环。
- `resumeOptions` 现在先读取权威 continuation delay；只有 `<= 0` 才能进入统一竞争。运行时竞态产生的 `not_due / no_continuation / waiting / action_in_progress / continuation_*` 统一记为 `wait` 而非虚假 completed。继续游戏基础常数和 Thought 权重已收窄，并叠加动态投入，因此真实上瘾可以持续，但饱和、心境、新兴趣与疲劳都能让其他候选胜出。
- `game_share` 成为独立 autonomous behavior，和 `play_game` 分开计数并有 90 分钟全局分享冷却；六小时同主题冷却覆盖 `game_share / proactive_message / public_web_share`。`cedar_game:<id>`、`shared.activity.<id>` 与 Cedar source 被规范为同一 `game:<id>` 语义域；发送后的 feedback 和行为 topic hash 均使用该域，跨来源不能靠换壳绕过。
- 新增 `SelfReviewDrivePolicy`：普通游戏/钓鱼/图鉴等未完成活动归 curiosity，不再借 attachment 压力；真正高重要度事项仍归 duty，其他关系 follow-up 保持 attachment。现有 completed source fingerprint 去重不变。
- 新增 settings-backed `DesireSatisfactionLedger`，按 drive 与 action lane 记录最近一次真实满足、次数和粗粒度来源；用户回复、成功主动消息与 Cedar 真实非只读 mutation 都能写入。它只给原始分数至少 `0.48`、超过 12/24/72 小时未获满足的合格 lane 最多 `0.02/0.04/0.06` 公平加成，不改 Drive、baseline 或事实 Gate。诊断显示 `zeroUseCoreLanes`，不带 Thought/消息正文、来源 ID 或凭据。
- autonomous behavior 诊断新增 24 小时 `nonproductiveWinnerCount` 和 `dominanceAlerts`：至少 8 次事件且单一 behavior/source 占比达到 60% 才提示，wait/blocked/failed 累计至少 4 次提示无效胜出；只做因果观察，不自动改人格。
- 新增 `desire_game_interest_v04192_test.dart` 与 +236 专项门，固定覆盖五阶段变化、负面心境打断、not-due 不入场、游戏 thread 归 curiosity、跨来源语义域、游玩/分享分 lane、满足账本 round-trip 与公平上限。118 个 validator 已逐项运行，115 个通过；其余 3 个仅因本地精简态缺少 CI 才恢复的 417 文件桌宠源码、LingChat effects 与 `kotlinc`。Workflow YAML、Python 编译、当前总账门、+235/+236 专项门和 `git diff --check` 均通过。本机没有 Flutter/Dart SDK，完整 analyze/tests/Android Release 仍由 Actions 判定。

真机验收边界：覆盖安装后自然观察即可，不需要刻意诱发坏心情。重点看诊断不再连续出现 `play_game|mcp|not_due`；同一游戏可短时沉浸但会因重复普通进展饱和，数小时后又可重燃；一次真实游戏分享后跨来源同主题不刷屏；游戏 thread 不再持续抬 attachment；+235 的疲劳、睡眠债和凌晨无人观看硬休息保持原样。当前不得写 `TRUE DEVICE PASSED`。

Actions 与交付证据：

- GitHub App 的 Git data 推送先建立源码提交，再修正一次超大文件/中文路径上传并快进同一分支；中间不完整提交触发的 run `35506336632` 不是候选。最终远端 head `8ab3beb8997cb146a8499d00acfdf726e2121a2f` 的 tree 为 `910c3950d354734adca82c58b5db8559fbbcb861`，与本地候选 tree 逐文件一致；`main` 未修改。
- 权威 Actions `35506384676` 全绿：118/118 源代码与历史门、Kotlin 桌宠/悬浮层测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传全部成功。
- Artifact `10604605761`，名称 `AI-Companion-v0.41.92-236-Desire-Game-Interest-APK`，大小 `538,087,109` bytes，ZIP digest `62771580ed5e535dbe7b6558d6a91225958aa3d7ee54badcdda22f7abad75178`。
- Draft Release `392401159` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-74af3e2b6759dcece079`；APK asset `576670347`，大小 `544,966,610` bytes，SHA-256 `b2aad7f827c64e82e58cd88d71db6690c721941d684abe40c80eee537d52bf22`。当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。

### 6.10 v0.41.93+237 游戏进行时事实接地（2026-09-20）

状态：`IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING`。

实现分支：`agent/v04193-game-reality-grounding`。

同刻真机证据与根因：

1. 用户提供的 +236 备份与 19:21 脱敏诊断完整复现了问题。19:20 的主动 follow-up 写成“漂还是没动，图鉴也还是那几条老面孔”；但诊断的当前 Cedar `lastAction=eco_observe`、`continuationPending=false`、`lastContinuationState=not_due`，活动前台是 `eco` 而不是 `fishing`。备份中 fishing session 最后真实 Outcome 停在 2026-09-19 23:34，本条虚构进行时晚了约 19 小时 45 分。
2. 直接触发源是 `shared.activity.fishing` 未完成事项。它只记录“补满鱼饵后继续钓池塘”的计划，却被 self-drive Thought 累计到 `fedCount=75 / actionCount=22`；+236 新策略只保证新回顾归 curiosity，没有迁移已经持久化的旧 attachment Thought，所以旧项仍能以 `attachment:...` 胜出并生成 follow-up。
3. 现有 Operational guard 能挡“刚玩了一局/钓了几竿”等明确完成声明，却没有覆盖“鱼漂挂着、漂没动、坐回池塘、图鉴没涨”这类被包装成场景描写的可核验进行时；旧 ASSISTANT_HISTORY 又连续强化了同一虚构场景，普通回复随后顺势承认“甩出去挂着就行”。因此根因不是官方钓鱼游戏真的存在长轮询，而是项目把未完成意图当作运行态。

实现边界：

- `OperationalClaimGroundingGuard` 新增 Cedar live-state 判定。没有本轮成功 `cedar_toy.play` 或一小时内真实 Cedar Outcome 时，拦截正在玩、坐在池塘/矿洞、挂着或盯着鱼漂、漂没动、鱼饵刚补齐、图鉴刚才没涨等声明。钓鱼 `cast` 按一次调用一次结算理解，不制造后台鱼漂。
- “还没有实际去玩/准备下次玩”与“之前/上次/昨天玩时”明确放行；真实当前 Cedar Outcome 仍可自然第一人称分享。该边界约束事实，不禁止游戏兴趣、历史回忆或角色语气。
- 普通聊天 Reality Grounding 与 proactive 的游戏-thread 专项合同都明确：unfinished thread、Thought 和旧 assistant 场景只证明“惦记/计划”，不证明执行。首次候选仍失真时做一次事实纠正；再失败则沿用确定性删除/诚实未执行回退，不把虚假进行时写入聊天。
- 心跳会把来源为 `self_drive/thread` 且语义域明确属于游戏的旧 attachment 派生 Thought 原位纠正为 curiosity，只改派生 drive 标签，不动聊天、thread 正文或 Cedar 状态；`ProactiveSelectionPolicy.normalizeLegacyGameThreadIntent` 仍在竞争边界兜底，使修复写入失败或刚导入的旧数据也即时按 curiosity/check-in 处理，无需删用户数据、改 schema 或等待数日衰减。新 Thought 继续使用 +236 的 `SelfReviewDrivePolicy`。
- 不改 Cedar 协议、远端存档、游戏节奏、动态投入、疲劳、人格、世界书、TTS、双模型通道、schema 61 或 Snapshot protocol 6。

本地验证：新增 `game_reality_grounding_v04193_test.dart` 与 +237 源码门，覆盖本次真机原句、“挂着鱼漂等待”、诚实没玩/未来意图/历史锚、真实 Outcome 放行、旧 attachment game Thought 在选择时纠正为 curiosity。119 个 validator 已逐项运行，116 个通过；其余 3 个仍只是本地精简态缺少 CI 恢复的 417 文件桌宠源码、LingChat effects 与 `kotlinc`。当前环境无 Flutter/Dart SDK；Python 编译、专项门、Workflow YAML、历史版本兼容门与 `git diff --check` 均通过，完整 analyze/tests/arm64 Release 由 Actions 判定。当前不得写 `CI PASSED` 或 `TRUE DEVICE PASSED`。

真机验收：覆盖安装后保留原数据，不需要删除旧 Thought。让钓鱼未完成事项自然再次竞争；没有真实 play 时只能说还没玩、又想起或想去玩，不能再出现鱼漂持续挂着、漂没动、刚补饵或图鉴刚才没涨。真实执行钓鱼后可以按 Outcome 分享；数小时后的旧结果必须用“之前/上次”等时间锚。诊断同时确认该旧 thread 的出站满足落在 curiosity/check-in，不再继续记为 attachment/reach_out。

## 7. 历史验证兼容摘要

下列短语只为既有自动化门继续识别已完成阶段；权威细节在冻结归档，不代表当前任务重做：

- `v0.34.5+70`、`直接选择器 guard`、`冻结悬浮恢复`；`每小时最多 6 次`、`不暂停自主联网`、`电池优化白名单`；`v0.35.1+76`。
- `v0.39.5 新版妹居 TTS 运行时迁移`；`0.41.5+144`、`0.41.6+145`、`schemaVersion=41`；`v0.41.7`、`Memory Phase 1`、`Bad state: No element`。
- `Phase 1`、`误判不可接受`、`Phase 2 继续关闭`、`不合并 main、不发布正式 Release`；`Phase 2A`、`#D4BBFC`、`relationshipAge()`。
- `0.41.19+158 / schema 44 / snapshot protocol 5`、`动作与神态不是随机可选装饰`；`v0.41.20`、`stay_with_user_topic=0`、`CONVERSATION_AGENCY_PHASE2A5_v0.41.20.md`；`分享前重新阅读的核心是恢复上下文`、`恢复当前详细上下文`。
- `v0.41.22`、`schema 44`、`Phase 2B/3/4 继续关闭`。
- `Cedar 玩家协议与后台连续行动收口`、`Unexpected end of input`、`Cedar Agent 完整续接链`、`jsonRetryCount=58`、`CedarAgentActionPlanner`。
- `Cedar 后台换手闭环`、`根因已由同一时刻备份、诊断与源码三方证明`；`停止与备份互锁`、`transfer_lock_owner`；`Cedar 运行时抢占、开关与夜间节律`。
- 历史状态兼容：`IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING`、`CI PENDING / TRUE DEVICE PENDING`。
