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
- **模型/API 双通道**：内部判断、维护、工具规划与 Outcome 核验走 DeepSeek；双模型模式只在收齐整轮上下文和真实工具结果后调用一次 Gemini 形成可见回复。MCP 网络请求不是模型调用。
- **真实工具事实**：只有成功的真实 Outcome 能支持“已进入、已落子、已发送、已保存、已完成”。失败、blocked、no_result、超时或零调用不能由对白补写。
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
| 当前功能分支 | `agent/v04186-autonomy-tts-diagnostics`，从 +229 总账 head `3245996` 分出；候选版本 `v0.41.86+230` |
| 当前任务状态 | `CI PASSED / APK READY / TRUE DEVICE PENDING`；+228/+229 的既有状态不因新分支自动升级 |
| +230 远端 | 构建 head `6c53a40b5d7413942c12ca84001bb66205c160d1`；tree `9c3674e87f37798964e293b1ffdeaedf4e582c74`；Actions `35458277355`（attempt 2 全绿）；Artifact `10589621373`；APK SHA-256 `de27ec0c0146ef3a879f0bb9d8ae2c06dbfdc3225d8f6694fe8e01c7c5ab8d4a` |
| +229 远端 | 构建 head `0f4ffc6c2b08a310a5f04919a045c98b2e8e63e3`；tree `9e0913202787feca13462c07fdd0941f10d0d4b9`；Actions `35450357850`；Artifact `10587305305`；APK SHA-256 `acbd5c81be69c5c27ae2822ea112fb2b0639a00636b61af7b0f642c02fbcddc6` |
| `main` | 仍为 v0.38.5 旧基线；不得作为 v0.41.x 起点，本批不合并 |

历史兼容索引：`v0.41.82+226` / `agent/v04182-cedar-state-machine-e2e`；`v0.41.83+227` / `agent/v04183-cedar-native-agent-loop`；`v0.41.81+225`；`模型自主发现`；`陪我下五子棋`；`全工具调用动作展示`仍是后续独立任务。

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

### 6.1 2026-09-20 MCP 真机结果后的已决定事项（均尚未进入源码）

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

| 优先级 | 条件 | 下一步 |
|---|---|---|
| P0 | +228 真机异常仍可复现 | 只凭同一时刻诊断/备份定位；先判断已有修复是否失效，不重复叠补丁 |
| P3 | +230 TTS 参考音频自然复现 | “高兴→可爱”已真机通过；若再次播放参考语音，立即导出同一时刻诊断，不凭感觉修改声学链 |
| P3 | +230 游戏竞争与防沉迷自然观察 | 随以后存档/诊断顺带核对 episode checkpoint、统一竞争、同局恢复、提醒/锁定、`allow_self_reset` 与自主重置；不专门诱发、不阻塞开发 |
| P1 | +229 真机测试 | 核对旅行/下矿活动窗图片、聊天附件、附件来源、失败降级与 Stop |
| P1 | 用户要“帮助”板块 | 先做功能清单与信息架构：`【检查系统】`、Agent/MCP 能力、权限与隐私、Stop、备份恢复、故障排查、当前限制；不把帮助页当新的执行器 |
| P2 | Agent 后续加入修改能力 | 再为语义不明或可破坏操作加入“是/否”确认；只读和明确执行继续自然语言直达 |
| P2 | 表情长期统计出现确证偏差 | 先看发送路径/候选/工具结果占用率；没有明确原因不调概率。主动表情是可选的新能力，不伪装成修复 |
| P2 | duel 仍显示“轮到你”但远端已变 | 检查导入/恢复后的权威 state 水合；映射 `next_actor=user → 轮到你` 本身正确 |
| P3 | TTS 或桌宠复现 | 独立任务、导入前后同时刻诊断；TTS 引擎在 APK assets/native runtime，备份只保存设置，不含引擎 |
| P3 | 继续旧路线 | 先查 +228 归档顶部任务段，再按 `app/docs/DOCUMENTATION_MAP.md` 定点查 +218 大归档；禁止全文重读两份归档 |

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
