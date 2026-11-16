# 全仓维护资料分析与整理清单

日期：2026-11-17（北京时间）。状态：分析完成；整理方案尚未实施，App 运行代码未改，无新 APK。

## 1. 结论与证据边界

建议继续保留现有 App 架构，先修正文档入口、建立按模块的维护卡和验证导航，再处理历史校验器。完整插件化、DSH 互通、Agent 自改不作为本轮整理前置条件。维护资料可以降低后续 AI 寻找入口和误解历史决定的成本，不能保证模型不会修改错误。

基线：v0.42.195+439 / schema67，开发分支 `agent/v042107-review-recovery`。核对时远端 HEAD `130c583166fca9eca81499f61b871889895b6a58`；构建源码 `efbe55d7fa58fd86abb408504bb2dbe70d26667e`。本地工作基线 `a06b0ed`，已核对本地与远端基线 tree 同为 `9fc82ee04bfcf9a448b5e1db9c50d053023ec44f`；提交编号不同，不能把本地 SHA 当成 APK 源码。远端签名构建 [43941615828](https://github.com/catkiss62/ai-companion-build/actions/runs/43941615828) 核实为 completed/success。真机沿用户反馈继续，不新增“整版真机通过”结论。

本轮覆盖仓库 2703 个已跟踪文件的路径与体积、278 份 Markdown 的标题/引用与分类；建立源码导入图和测试关联候选。主要文本范围：578 个 app/lib 文件（161458 行）、410 个 app/test 文件（66525 行）、349 个 Android 文本文件（含第三方，70601 行）、339 个工具文本文件（38265 行），另含 QQ bridge、8 个工作流、资产说明及五份总账/归档。统计按文件路径，不等于测试用例数量。

**这是全仓结构扫描、历史关键章节提取及主要链路定点核对，不是逐行读完全部源码、四十余万行文本或全面漏洞审计。** 用户允许扩大读取范围，本次未因旧“最小化读取”要求排除其他模块；同时，不把自动读入文本和搜索匹配冒充语义审查。二进制模型、纹理、音频及第三方 SDK 未做逐项行为分析；未连接真实模型/QQ、未做 Android 真机验证。逐文件覆盖级别见附件。

本轮未发现并复现新的数据损坏或崩溃缺陷；确认了能力描述错误、校验盲点、文档入口错误及维护流程问题。不能据此宣称整个项目没有其他 bug。

附件：

- [278 份文档清单](document_inventory.csv)：每份的处理建议、引用候选、核对程度；候选分类不是删除许可。
- [2703 个文件覆盖表](file_coverage.csv)：区分文本结构扫描与仅文件盘点。
- [模块及测试关联](module_inventory.csv)：静态导入关联，不是运行时调用图或测试覆盖率。
- [失效链接](link_findings.csv)：只检查 Markdown 简单本地链接，不检查网络可达性和所有锚点。

## 2. 确认发现与处理优先级

| ID | 类型/优先级 | 证据与影响 | 建议处理及验证 |
|---|---|---|---|
| M01 | 接班错误 / 高 | 根 README、app/README、AI_START_HERE、BUILDING 仍称 v3 为当前总账；v4 已承接 +439。接手 AI 可能读到 +383/+420 历史状态 | 统一指向 v4 或永久跳转入口；版本/交付状态仅由当前快照维护；检查所有入口链接 |
| M02 | 导航歧义 / 高 | DOCUMENTATION_MAP 顶部保留 +419 当前候选、+418 当前交付及更多旧“当前”段落；AI_START_HERE 带旧任务/暂停决定 | 导航仅列领域和适用状态；旧状态标明版本时点，移到对应历史记录，不以旧“待办”直接立项 |
| M03 | 运行能力描述错误 / 高 | `agent_self_reader.dart:118` 写“自主创作尚未接入”；`proactive_engine.dart:505` 调用 `CreativeInspirationEngine.maybeThink()`，有设置/状态/创建/分享链及通过的自主创作测试 | 后续修自查文本，准确区分深度思考委托、独立自主创作开关和分享；补具体语义断言。此轮未修 |
| M04 | 运行能力标签过时 / 中 | 自查 Cedar 状态仍为 `implemented_user_turn_only`，而 `cedar_toy_autonomy_engine.dart` 及自主调度链存在。状态与能力范围不符 | 同步自查状态/说明，核对具体入口条件，避免把自主能力描述成无条件可用；不能只改工具 registry |
| M05 | 文档架构过时 / 高 | VOICE_PIPELINE/TTS_PORTING 标 current(v0.39.5)，仍写 Meju/MNN/LegacyTtsRuntime；实际 NativeTtsEngine 使用 IsolatedGenieTtsClient，服务在 :genie_tts 进程 | 原文留作移植历史，新增当前 Genie 链说明；不要照旧文档恢复已退役引擎。Legacy 类仍在仓库，是否删除须另查引用/构建，不能随文档一起删 |
| M06 | 校验盲点 / 高 | `validate_current_ledger_handoff.py` 仍以 v2 和 schema62 判断“current”；实际 schema67。正则匹配的是 app_database.dart 第203行历史兼容注释，校验仍通过 | 分离冻结历史完整性与当前版本校验；当前 schema 读真实声明/运行常量，不能靠注释。补失败样本证明错误当前值会被拒绝 |
| M07 | 维护成本 / 中 | 旧 validator 的版本枚举和兼容注释分散；+438 总账记录版本门禁连续失败。14 个 Dart 文件有约110条 Historical validator/contract 文本匹配 | 新增统一版本来源后逐组迁移有效检查，保留真正行为回归；不一键删除旧门禁或兼容注释 |
| M08 | 文档操作触发构建 / 中 | build-apk.yml 文档范围仅含根总账、两个 README、app/docs/*，未含 AI_START_HERE.md；修改接手页会进入完整构建分类，新增 AGENTS.md 也同理 | 如后续整理接手页，先决定是否补轻量范围并加分类用例；此轮报告位于 app/docs，不改工作流 |
| M09 | 本地链接错误 / 低 | THIRD_CHANNEL_PUBLIC_GATEWAY_v042152.md 第25行 `../THIRD_CHANNEL_PUBLIC_GATEWAY_v042152.md` 指到不存在位置 | 修正相对路径并运行链接检查；不影响 App 运行 |
| M10 | 帮助不完整 / 中 | 帮助页工具列表来自 registry，静态段落未系统介绍第三通道、逐批识图、QQ、作品自主创作、本地语义召回、模型对谈 | 后续按第6节补用户说明；保留 registry 生成列表，不能把说明“完善”成未接通能力 |

M03 及 M04 属于运行时自我认知内容问题，有可能影响模型回答自己的能力；不是新功能实现。M06 是单个静态门的假通过，不表示所有测试失效，也不表示实际数据库版本错误。

M08 的 pull_request paths-ignore 与 push change-scope 是不同层；现有文档称“纯文档 PR 跑轻量检查”也需与实际触发方式对齐。不能因报告是 Markdown 就假定任何位置都免构建。

## 3. 五份总账的真实布局与整理办法

用户所说“四个总账”在当前树实际对应五个总账/归档文件：

| 文件 | 规模（核对时） | 定位及处理 |
|---|---:|---|
| 根 AI_Companion_当前总账.md | 805896 字节 / 3882 行 | v2 历史和永久跳转；旧正文仍被门禁读取，暂不压缩删除 |
| ledger/AI_Companion_总账_v3.md | 498633 字节 / 2070 行 | 历史阶段；顶部已有 v4 跳转，仍存在旧“当前”段落 |
| ledger/AI_Companion_总账_v4.md | 本轮开工记录后 84509 字节 / 339 行 | 唯一当前任务与交付状态；后续仅此处追加任务结果 |
| archive/…截至_v0.41.74+218.md | 1587679 字节 / 6491 行 | 冻结历史；校验固定字节数和 SHA-256，不改正文 |
| archive/…截至_v0.41.84+228.md | 98372 字节 / 483 行 | 冻结阶段历史；同样受哈希保护 |

不把重复构建等待和状态汇报复制进新维护卡。每个反复修复的问题提取：触发条件→尝试过的路线→失败原因/证据→最终有效行为→当前源码/测试→未证实边界。旧报告提到的故障先核对是否已修，不能全部搬成未完成清单。

优先可提取的历史主题：

- 存档：媒体所有权、删除表情包后的原图引用、目录交换/事务/崩溃恢复、导出与 Live2D 生命周期。入口为 snapshot、portable、shared_media、sticker 系列测试及 +303/+304 记录。
- 游戏厅：状态核对与有序写入、等待玩家/平台、未知发送、重试与恢复、三次/30分钟及被撤回方案。入口为 +348～+351、+373～+378、Cedar 回归，保留“不为继续游戏给每轮普通聊天增加规划”的约束。
- TTS：旧引擎与 Genie 迁移、隔离子进程、语言预热、Stop 迟到音频、参考音频泄漏；速度试验与正式生产配置分开。
- Live2D：直接合成恢复与背景残留、输入法固定画布、触摸/绘制区域、两模型独立参数、播放期间口型优先级；视觉通过只归于具体版本和项目。
- 记忆/上下文：来源失效、纠错后继链、角色扮演隔离、摘要覆盖游标、Unicode/多图分页、语义查询缓存；+438/+439 失败和复现是维护卡可直接采用的样本。
- QQ：入站来源、本人识别、工作队列、发送回执、重连取消、共享记忆边界；旧“只接本人私聊”不得覆盖现在群聊实现。

先提炼仍影响当前代码的主题，不要求还原全部历史。无法定位来源的特殊处理标“原因待核实”；不编造失败路线，也不以“无文档”判它可删除。

## 4. 文档分类与具体去留

### 4.1 第一批直接改善的入口

README、app/README、AI_START_HERE、DOCUMENTATION_MAP、REPOSITORY_MAINTENANCE、BUILDING、ROADMAP。保持链接短、任务状态单一；AI_START_HERE 只负责找入口和说明读法，不再积累整段版本交付。

建议新增维护目录（此轮仅建议，尚未建立正式契约）：`app/docs/maintenance/`，包含 `INDEX.md`、`CHANGE_GUIDE.md`、`VERIFICATION.md` 及按领域的维护卡。每卡写：适用基线、用户入口、执行链、持久状态、允许小改的位置、必须保留的边界、回归故事、测试命令、历史来源。文件路径配类/函数名，行号仅作当时定位。

### 4.2 保留但调整定位

- INNER_DRIVE_DESIRE_SYSTEM_BACKUP_v2：欲望主干已实现，保留参考映射与唯一行为主干约束；“梦境未来/网页深读未来/天气未来”等条目是旧时点，应补后续实现链接。
- DUAL_CHANNEL_SENSE_v1：原始参考包含 touch/smell/taste/sound 的设计；当前检查确认双向触摸检测、提交后自我反馈和衰减。不能把整个参考当成全实现，也不能称整份方案无用。原参考与当前实现矩阵分开。
- PERSONALITY_LEARNING_GROWTH_PHASE1：旧“只观察”阶段与后续有界使用不能混淆；该文件有有效门禁引用，宜先新增状态标注。
- CREATIVE_AUTONOMY_DESIGN、各 QQ PLAN：文件名有 DESIGN/PLAN 并不代表全部未实施，逐条连接实际实现记录后分类。
- DSH_INTEROP_PLUGIN_ROADMAP：保留历史讨论与候选资料，标当前搁置；不能当作下一步已授权开发任务。
- ARCHITECTURE、VOICE_PIPELINE、TTS_PORTING、TEST_CHECKLIST：保留历史原文或历史标记，另写当前概览；不要将陈旧“current”呈现给默认接班者。
- local_semantic_memory：更新早期 candidate 定位，并链接当前索引、QQ 时间预算和 +438/+439 修复。

### 4.3 暂不删除的文件

本轮没有提出可以立即无条件删除的具体文件。版本专项说明、INTERNAL_VALIDATION 系列可以列为历史归档候选；仅凭未被代码引用不能证明无价值。

许可证、NOTICE、ATTRIBUTION、资源来源/哈希、QQ bridge 说明、第三方 SDK 许可必须保留。被 validator 读取的文档搬家要同步消费者。按文件名匹配发现54份 Markdown 被代码/脚本/工作流文本提及，这只是候选依赖；同名 NOTICE 等可能重名，不能直接当成54份运行时文档。

未发现 App 将 app/docs 整体作为运行时提示词加载的直接证据。文档主要影响开发维护，App 帮助、自查文本和提示词则在 Dart 中；整理 docs 不会自动更新手机能力说明。

### 4.4 为什么暂不大搬目录

旧门禁、文档链接、工作流甚至历史证据依赖原路径。先加状态标签、更新导航，通常已能减少误读；只有确认引用并补重定向后才搬迁。历史归档数目和仓库体积不是本轮主要问题，不删除分支、不重写 Git 历史、不迁移大资源。

## 5. 按模块建立维护卡的清单

路径除原生说明外均相对于 app/lib；测试命名仅为选择入口，正式修改仍核对工作流的实际检查要求。

| 领域 | 主要入口/依赖 | 维护卡必须说明 | 验证入口 |
|---|---|---|---|
| 导航/设置/聊天 UI | app.dart、features/chat、features/settings、widgets | 页面生命周期、输入法/滚动、保存时点，文案不能误改设置键 | chat_*、settings_*、导航相关测试 |
| 普通生成与恢复 | chat_controller、ai/durable_generation_runner/recovery | 用户轮身份、Stop、刷新、提交后提取、前后台接力 | generation/recovery、stop、durable 系列 |
| 模型路由/预算 | ai/first_channel_model、deepseek_client、final_reply_route、third_channel_client | 内部与正文通道、独立工作模型、重试条件、结束原因、字符与 token 差别 | model_routing、final_reply_failure_policy、vision_web_output_budget |
| Prompt/规则/世界书 | ai/prompt_builder、rules、reference | 注入顺序、默认升级是否覆盖用户修改、来源与房间隔离 | prompt、rule、world_book 系列 |
| Agent | agent_tool_registry/planner/runner、turn_execution_store | 注册≠全部自主流程；工具参数、回执、幂等和停止 | agent、tool、operational_claim 系列 |
| 自主/欲望/感知 | desire/proactive_engine、desire_core_policy、perception、presence | heartbeat 与任务重试分时钟、Gate、夜间额度、手机证据衰减、分享独立边界 | proactive_*、desire_core、presence/perception |
| 记忆/语义/原文 | memory、database、history；原生 memory/BgeTokenizer | 来源准入、纠错链、缓存生命周期、字符分页、模型 token 上限 | memory_*、local_semantic、history |
| 梦境/成长/深反思 | self/dream_*、memory/personality_learning_*、reflection | 低频、证据出处、可修订、不能把猜测写成事实、不中途串旧任务 | dream/nightly、personality_learning、reflection |
| 情绪/双形态/萌属性 | emotion、personality/playful_form_state、moe、integration、mood | JEV 概率与气焰、显示/语音/正文快照、Stop 回退、普通与沉浸作用域 | playful_*、moe_*、emotion_* |
| 关系/连续性/感官 | relationship、continuity、somatic | 真实事件与角色扮演、提交后反馈、双向触摸与衰减 | relationship、daily_continuity、somatic_policy |
| QQ | integrations/qq_private、qq_private_main、packages/qq_private_bridge | 与 App 共享哪些状态、本人/群友、来源游标、排队/重连、媒体与发送回执 | qq_*、bridge 子项目测试、原生 QQ 检查 |
| Cedar 游戏厅 | core/mcp、features/chat/cedar_toy_activity_window | 远端真实状态、写操作串行、等待/恢复、三次/30分钟，避免一游戏一补丁 | cedar_*、game_*、相关 native |
| 作品 | creative、features/creative；原生 CreativeBridge/WebSandbox | 委托/自主/分享三入口，版本哈希、文件检查点、试玩、停止/恢复、存档 | creative_*、Node bridge、原生 sandbox |
| 生图/图片/表情包 | illustration、media、stickers、storage | App/QQ 入口差别、真实附件与相册保存、共享文件所有权、预设范围 | illustration、sticker、media、album |
| 模拟手机/愿望/提醒 | phone、wishes、features/phone | 读取和生成边界、日记/随笔频率、愿望证据、提醒确认和送达 | simulated_*、wish_*、calendar_* |
| 沉浸房间 | immersive、features/immersive | 独立上下文、完整消息摘要游标、结束归档与失败重试 | immersive_*、room_history |
| 模型对谈 | model_dialogue、features/model_dialogue | 参与者身份/模型快照、无跨模型兜底、归档意见保留来源 | model_dialogue_* |
| TTS | core/tts；原生 NativeTtsEngine/IsolatedGenieTtsClient/GenieTtsRuntime/WavAudioPlayer | 独立进程、语言预热、顺序播放、Stop 丢弃迟到音频、音色与参考语音区别 | tts_*、Genie 原生测试、设备听感 |
| Live2D/背景/桌宠 | widgets；com/catkiss/senlive2dcompanion；原生 pet | 菜菜/DeepSeek 隔离、渲染生命周期、口型优先级、坐标/缩放、触摸边界 | caicai、Deepseek 原生测试、设备视觉 |
| 后台/悬浮/通知 | background_main、platform、maintenance；原生服务/OverlaySubmissionState | 三套入口生命周期、去重、租约、系统窗口权限、恢复顺序 | background/overlay/recovery、Kotlin 与 Android 检查 |
| 数据/备份/媒体 | database、sync、storage；原生 PortableBackupZipVerifier | 真实 schema、迁移、Active Brain、事务/目录交换/锁、快照容量 | snapshot/portable/shared_media、崩溃恢复 |
| 诊断/构建/资源 | diagnostics、tools、workflows、asset_packs | 脱敏例外、静态/运行/真机证据分层、签名、资源恢复与产物保留 | validation_suite、构建身份检查、native/Flutter CI |

数据库文件约21268行；DurableGenerationRunner、ProactiveEngine、Cedar 引擎和 UI 大文件同样需要函数级入口说明。大文件不自动等于应拆分，本轮不建议为整洁重构。AppDatabase 被大量生产/测试文件引用；静态导入次数用于发现共享基础，不代表修改必然影响全部调用方。

现有原生目录混有自有代码和 Cubism SDK。维护说明应明确上游来源及本地改动边界，不能让小修任务顺手格式化或改写整个第三方目录。

## 6. App 帮助与真实能力更新清单

帮助页 `features/settings/capability_help_page.dart` 已从 AgentToolRegistry 生成可执行工具列表，值得保留。但它只列 registry 的入口，不代表所有后台能力，也不反映当前设备已启用/凭据可用。建议补充如下用户说明，具体数值不要再散落多份硬编码文案：

| 主题 | 应说明内容 | 核对来源 |
|---|---|---|
| 模型通道 | 第一通道内部处理、第二/第三通道正文、失败提示和手动 DS 回复；模型对谈独立 | ai 路由、设置、model_dialogue_gateway |
| 图片识别 | 批量图片一次回复、DS/千问选择、QQ 引用图片/动图的可读范围 | chat_image_send_dialog、附件服务、qq_vision/frames/review |
| 深度思考与作品 | 新委托入口、独立工作模型、继续/暂停、后台创作开关、完成与分享区别 | creative_worker/store/inspiration、设置 |
| QQ | 本人绑定、群聊开关、历史只覆盖已接收内容、图片/语音/生图条件 | QQ 设置与 runtime，不照旧私聊版文档 |
| 记忆 | 关键词/日期/本地语义结合、原文追读、索引准备和降级不等于删除记忆 | memory、history、原生 embedding |
| 房间 | 普通/沉浸/模型对谈的状态和归档范围 | 两类 controller/repository/archive |
| 语音与 Live2D | 当前语言/音色/参考声音关系、预热、两模型配置、播放口型 | TTS/原生/Live2D 设置 |
| 备份与资料提供 | 备份含哪些内容、哪些需设备重配；诊断内容范围以实际导出为准 | snapshot/portable/secure_config/diagnostics |
| 未开放能力 | 通用 MCP、视频及自修改等以实际入口核对；不承诺插件化 | registry + 新候选实现核查 |

“Genie 四种音色”的帮助文字不能直接判错：当前 TtsVoiceMode 确有四个手动模式和一个自动模式。需要补的是它与后续参考声音候选的区别，不能简单把四改成候选数量。

帮助更新应同时检查 AgentSelfReader、registry 描述、设置说明。自查不是每轮常驻提示，改帮助也不会自动改变自查文本。建议为已确认的错误增加小范围真实输出断言，不用对整个页面逐字快照锁死文案。

## 7. 待核实问题，未列为确认缺陷

- 某些旧内部调用仍直接读取 `reasoning_effort`，例如 creative_inspiration；新的第一通道设置有独立 `deepseek_reasoning_effort` 和 FirstChannelModel.readEffort。是否有意采用独立工作/后台力度需按调用目的核对，不统一替换。
- 模型对谈载入配置也读取公共 effort；独立房间配置和旧字段迁移应结合实际入口确认，不能仅凭字段不同判错误。
- 帮助对“脱敏诊断”的理解需要核对：诊断源码注释明确有用户授权的 JEV 文本例外。后续应清楚说明导出范围，不把所有报告描述为绝无正文；本轮未发现公开泄露事件。
- 单条超长输入、不同服务商实际 context window、长房间分批归档累计耗时、QQ 450ms 与 TTS/Live2D 争抢资源仍需运行样本。沿用此前已登记风险，不重复包装成新漏洞。
- 历史文档标“待真机”不能批量改成通过，也不能认为用户没有报告问题就等于所有边界都验证了。

## 8. 实施顺序与验收

A. 文档入口和状态定位：修 M01/M02/M05，给历史方案加准确标签，建立当前维护导航。不改变 App 行为。验收为链接可解析、一个当前总账、旧状态不再当默认任务、受影响文档校验通过。

B. 维护卡与回归摘要：按第5节优先完成 UI/设置、创作、模型/上下文、QQ、备份和原生生命周期；其余领域补齐索引。每项给出源码/测试入口，未查明事项明确标注。禁止宣称文档覆盖等于代码无缺陷。

C. 当前校验与历史校验分离：处理 M06/M07/M08，作为维护工具改动单独测试。先新增当前事实检查和负例，再迁移旧断言；不能通过删门禁让构建变绿。维护工具和工作流修改可能需要完整 CI，不能承诺“文档整理全部免构建”。

D. App 帮助与自查：修 M03/M04/M10，专门做语义断言/界面检查；随下一次正常 APK 交付。不得同时扩展插件和 Agent 自修改。

E. 可选物理归档/删除：只在前面稳定、引用及回归证据明确后做。冻结总账保持原样；暂不删除任何具体文档或旧分支。

后续仓库协作规则建议写入 AI_START_HERE/REPOSITORY_MAINTENANCE，并在当前总账保留链接：新增功能、修复或行为变更时检查受影响的模块入口、边界、回归故事和测试导航；涉及用户可见行为时检查帮助/自查。未受影响资料不必机械改写，复杂失败过程留唯一总账/专项记录，维护卡只留结论和出处。

## 9. 本轮验证与未实施项

- 34 项通过：agent_self_reader_v0416_test、creative_autonomy_test、somatic_policy_test；串行执行，无真实模型 API。证明既有相关行为回归正常，不证明自查文本已准确。
- validation_suite --check-only 通过：167 项清单结构有效，未在本轮全跑167门或全量Flutter。
- validate_current_ledger_handoff.py 通过：冻结归档字节/SHA未变，同时确认其“当前 schema62”匹配历史注释的盲点。
- 全仓简单 Markdown 本地链接扫描发现1个失效目标；未验证外链和所有 anchor。
- 检查期间首次 GitHub branches URL 被接口拒绝，改用 git/ref/heads 查询成功；没有因此猜测远端基线。
- 文件清点初次 `git ls-files` 被非ASCII转义影响，随后改用 `git ls-files -z` 重建，最终五份总账/278 Markdown/2703文件为纠正后结果。
- 部分宽范围工具输出被截断，结论只采用后续定点确认的证据；附件的自动扫描不能视为人工阅读全文。
- 未修改业务源码、没有删除/搬迁文档、没有实现维护卡/插件/自修改、没有新版本/新 APK/真机通过结论。既有未跟踪 lingchat/effects 文件未纳入本轮提交。
