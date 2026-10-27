# 文档地图

最新审查：[QQ转发来源与GIF方案](QQ_FORWARD_PROVENANCE_REVIEW_2026-10-27.md) — +386只读复查的两个待修根因、冻结合成探针及有界抽帧建议；不是新功能交付，不触发构建。

当前交付：[+386 QQ与夜间修补](QQ_NIGHT_RECOVERY_v042142.md)，完整CI40441351357和专项40441351370成功；运行源码1330046de74a790ae671443a4108a2ec1ede6f0f，状态与下载见总账v3。

当前交付：[QQ_ARCHIVE_AGENT_v042139.md](QQ_ARCHIVE_AGENT_v042139.md) — +383六组QQ/Agent读取链修复及沉浸布局；完整CI40327576862成功，2829全量Flutter/170存档恢复/54原生测试通过，原签名APK已上传GitHub，真机待验。

前一版交付：[QQ_JEV_CONVERSATION_v042138.md](QQ_JEV_CONVERSATION_v042138.md) — +382 JEV群聊判断/连续对话、App本机认主、群记录读取补漏和中文档案/群名；完整CI及原签名APK已成功，真机待验。

历史交付：[`QQ_GROUP_IMPLEMENTATION_2026-10-26.md`](QQ_GROUP_IMPLEMENTATION_2026-10-26.md) — v0.42.137+381群聊/共享档案、一次消费小卡、视觉与App图库媒体、认主/分享回执；完整CI及原签名APK均已验证取回，平台实网/长时后台待验。

> 目标：一个永久总账入口，少量按领域维护的当前契约；版本演化和退役材料由 Git 历史保存，不让多个旧状态同时参与 AI 检索。

## 1. 阅读顺序

1. 读取 [当前总账 v3](ledger/AI_Companion_总账_v3.md) 顶部维护重点、当前收尾任务入口及接班快照；根目录 `AI_Companion_当前总账.md` 为永久跳转与只读历史，已完成旧基线只按相关任务定点读取；
2. 本文档；
3. 与当前任务直接相关的专项设计；
4. 实际源代码、测试/validator、CI、最新脱敏诊断和实机结果；
5. 修改旧功能时，按总账导航定点检索冻结归档；只有系统审计、冲突或无法定位的回归才默认全文扫描。

冲突优先级：

```text
用户最新明确决定
> 实际源码与 CI/实机证据
> 最新脱敏诊断
> 当前总账
> 当前专项设计
> Git 历史
```

以下三段记录+380时点历史，当前实现/交付以上方+383和对应源码为准。

+380历史交付为[QQ记忆基础与独立回复通道+380](QQ_MEMORY_IMPLEMENTATION_2026-10-26.md)：运行源码ae561faf，完整40230361074通过154源码门、Kotlin、2736全量Flutter、170归档恢复和Android15原生54项，专项40230361080通过1177项；原签名APK已取回，版本/原包SHA/ZIP已核验。A0 R1–R5已修补并自动验证；当前QQ仍只读现有记忆、只接本人纯文字。后续文档/传输/CI范围修补不改变APK运行代码。用户的首轮实网成功反馈属于[+379首版](QQ_PRIVATE_V1_2026-10-25.md)，+380真机及长期后台仍待验。

[共享记忆、群聊与存档方案](QQ_MEMORY_GROUP_PLAN_2026-10-25.md)中，A私人记忆写回/跨入口/O1与B–D群聊/媒体/分享仍待后续。用户允许先出当前APK，再单独接QQ表情包，复用App图库和宽松选图语义；群聊上线前必须落实禁止群友暧昧/亲昵称呼，不改本人私聊人设。G1–G7继续后移。

原始审查证据保留：[兼容性审查](QQ_MEMORY_COMPATIBILITY_REVIEW_2026-10-25.md)列扩展适配；[第二轮](QQ_MEMORY_SECOND_REVIEW_2026-10-25.md)列R1/R2；[第三轮](QQ_MEMORY_THIRD_REVIEW_2026-10-25.md)列R3/O1；[第四轮](QQ_MEMORY_FOURTH_REVIEW_2026-10-26.md)列R4/R5。各报告的“仅文档/未实施”描述其审查时点，不能覆盖当前候选和CI。当前源码QQ仍为独立只读入口，不能把A0通过当作完整群聊/共享记忆已实现。

## 2. 唯一总账

- **自2026-10-16启用总账 v3**：当前可追加正文为 `ledger/AI_Companion_总账_v3.md`；根目录永久入口只负责转接，并冻结保留 v2 原文供历史源码门校验。新窗口只读 v3 顶部“当前接班快照”，日常不再写入约806KB的旧文件。以下旧卷规则仅适用于历史，后续更新按 v3 接班协议执行。

- 永久入口：`/AI_Companion_当前总账.md`
- 冻结归档：
  - `ledger/archive/AI_Companion_总账归档_截至_v0.41.74+218.md`：截至 +218 的完整历史；
  - `ledger/archive/AI_Companion_总账归档_截至_v0.41.84+228.md`：+219～+228 与 2026-09-19 仓库维护的阶段历史。
  两份均只读，不参与日常接班与追加更新；先按当前总账索引选择，禁止默认全文读取。
- 当前总账顶部以 `END QUICK HANDOFF INDEX` 划出快速索引；新窗口先读索引，再按索引定点读取后续正式记录。正式记录不设容量上限，可像旧总账一样持续追加。
- 归档只用于自然阶段边界、操作性能明显下降或不可变证据快照，不因当前总账总字节数强制滚动；已有归档继续只读。
- README、App README 与 Roadmap 只链接这个入口。
- v0.41.74+218 之前的完整过程从上述归档定点取证；更早被删除的版本副本仍从 Git 历史恢复。

## 3. 当前专项文档

- 当前收尾执行入口：[STABILITY_CLOSEOUT_PLAN_2026-10-25.md](STABILITY_CLOSEOUT_PLAN_2026-10-25.md)。统一九项确认漏洞、三项模型/API配置、两项先验证边界及原六类＋G7复查规划；实施与自动验证见[+378记录](STABILITY_REPAIRS_v0.42.134.md)；本阶段测试APK后暂停等待真机反馈，G1–G7尚未开展。
- 模型与插件讨论历史：[MODEL_CONFIG_FOLLOWUPS_2026-10-25.md](MODEL_CONFIG_FOLLOWUPS_2026-10-25.md)。以最新明确决定为准，已被覆盖的插件化候选不重新立项。

- `CREATIVE_CONTEXT_UI_v0.42.98.md`：+342作品会话/详情快照、输入法与轻量聊天、折叠和稳定交付引用。

- `CREATIVE_PLAY_DELIVERY_v0.42.97.md`：+341数字回合协议一致、独立持续制作、第二通道完成回报与作品集位置。
- `CREATIVE_AGENT_v0.42.96.md`：+340独立上下文的工作工具循环、文件检查点、试玩修复、存档恢复和诊断；取代+339整份JSON生成。
- `CREATIVE_WORKSPACE_v0.42.95.md`：+339作品集、互动桥、每日费用与梦境运行修复的初版背景；生成可靠性见+340。

- `GAME_INTENT_CONTINUITY_v0.42.94.md`：+338分享新意、念头修订、愿望机会与执行回执、游戏上下文和Android 8舞台隐藏；小作品/梦境保留讨论。

### 人格、驱动、情绪与关系

- `PERSISTENT_MOOD_v1.md`：+311持续心情，任务上下文、模块边界、真实事件、JEV复用、生命周期与验收。

- `INNER_DRIVE_DESIRE_SYSTEM_BACKUP_v2.md`：欲望/内在驱动唯一融合主干；已吸收旧审计中的 screen companion 与维护约束。
- `PERSONALITY_TRIAL_SYSTEM_v1.md`：性格试穿。
- `PERSONALITY_INNER_VOICE_v2.md`：长期人格内心声。
- `PROMPT_WORKBENCH_v1.md`：提示词工作台。
- `PERSONALITY_LEARNING_GROWTH_PHASE1.md`：人格学习/成长 Phase 0 分类、Phase 1 只观察证据合同与第一真机卡点。
- `NSFW_CONTEXT_ROUTER_v1.md`：独立上下文路由与安全边界。
- `EMOTION_ENGINE_EXPANSION_EVAL_v1.md`：情绪引擎扩建/停止判据。

### 普通聊天时间语义

- `MEMORY_2D_LIFECYCLE_V04137.md`：v49 事实/注意/召回分层、schema 48 旧存档证据回放，以及 Memory 2D 冻结验收样本。
- `ORDINARY_TIME_SCENE_BOUNDARY_v0.41.12.md`：普通聊天真实用户现场/最近互动双时钟、手机预计算 gap band、短寿命活动重判与沉浸 Session 隔离。
- `PHASE01_TIME_AUDIT_HARDENING_v0.41.13.md`：Phase 0+1 旧 Memory/Relationship 绕过审计、direct feedback/命题边界、半小时双时钟一次详细注入、主动消息不刷新用户现实与人称出站守卫。
- `AGENT_OPERATION_TRUTH_SCREEN_OBSERVATION_v0.41.14.md`：可核验操作必须有匹配 terminal Outcome、成长系统 observation-only 元数据只读，以及用户明确触发的一张当前屏幕截图、敏感页 Gate 与临时字节隐私合同。
- `SELF_EXPERIENCE_DESIRE_WEB_PHASE2A_v0.41.15.md`：Phase 2A 自我回顾候选/体验 Outcome、baseline-centered 欲望动力学、熄屏联系窗口、三类自主联网与四分支结果评价合同。
- `CONVERSATION_AGENCY_PHASE2A5_v0.41.20.md`：Phase 2A.5 普通聊天动作选择、想知道才追问、用户跳题/话题释放、受控造梗、脱敏持久化与验收合同；明确不改写可见思考链、不开放 Phase 2B bias。
- `PHONE_UI_INTEGRATION_v0.41.16.md`：Phase 2A 观察兼容的查手机/快捷侧栏/沉浸布局整合合同；明确购物车隐私、只读状态页及总设置第二步边界。
- `CHAT_UI_MOOD_HOTFIX_v0.41.17.md`：v0.41.16 真机呈现热修；固定聊天白字、三处对白颜色联动、THINKING 折叠头、心情图宽度、购物车 emoji 与侧栏关系天数单一数据源。
- `SETTINGS_INFORMATION_ARCHITECTURE_v0.41.18.md`：总设置六域、侧栏单一真源、分小节保存、高风险动作隔离、自检副作用分层，以及同包对白紫色/主动回想文案合同。

### 身体与感知

- `DUAL_CHANNEL_SENSE_v1.md`
- `SOMATIC_CONTRACT_TOUCH_v0.32.0.md`
- `SOMATIC_AI_TO_SELF_v0.32.1.md`
- `DESKTOP_PET_SOURCE_PARITY_v0.33.1.md`：已吸收桌宠架构、性能、隐私与素材许可边界。

### Agent 与联网

- `CEDAR_TOY_MCP_v0.41.67.md`：Cedar Toy 动态游戏列表、指南约束、真实游玩 Outcome、安全凭据与 DeepSeek/Gemini 单次最终回复合同。
- `SUBJECTIVITY_LIFELIKENESS_AUDIT_2026-09-08.md`：主体性/活人感约束归因、v0.41.49 主观搜索与造梗恢复实现、Agent v2 与 D6 媒体引用合同。
- `AGENT_V2_BOUNDED_LOOP_v0.41.50.md`：v0.41.50 三回合/六调用的 observe→act→verify 任务循环、重复调用防护、终态核验、权限与真机边界。
- `AUTONOMY_ARBITRATION_REWORK_v0.41.44.md`：Desire 动机、能力可用性与最终 Outcome 三层仲裁；记录 v0.41.43 真机踩雷、显式 wait/defer、成功冷却语义及未来 MCP 接入约束。
- `AI_INTEREST_CONSUMPTION_PHASE3C_v0.41.66.md`：只消费跨日期成立且仍新鲜的 AI 自身兴趣，以 exploit/adjacent/wildcard 独立预算影响自主联网与主动话题；记录撤销、失败 Outcome、自反馈隔离、schema 61 与诊断隐私合同。
- `STICKER_EXPRESSION_v0.41.45.md`：单聊表情包表达层、dsh 兼容私有包格式、抽样/语气/NSFW 边界、事务提交与真机验收。
- `STICKER_AGENT_CONTINUATION_IDENTITY_v0.41.46.md`：明确指令的 `sticker.send` 真实附件闭环、发送后自我认知、Rule 01 保守迁移与沉浸截断修复。
- `STICKER_SEMANTICS_GALLERY_INTEROP_v0.41.51.md`：七张运行时禁用、催睡表情语义修正、普通回复零匹配保护、长按完整语义和厂商相册应用入口；末节冻结旧数据整理与新图片自动归一化边界。
- `DIARY_FRESH_TOPIC_BALANCE_v0.41.52.md`：真机日记重复与主动消息旧事化根因、DailyContinuity 有界日记整理、近期相似度门、fresh lane 上下文隔离、滚动一半新鲜来源倾向、网页高价值候选放宽及无效厂商相册入口回退。
- `THIRD_PARTY_NOTICES.md`：表情包机制及其他外部研究来源的上游地址、许可证和素材边界。
- `AUTONOMOUS_ACTION_FOUNDATION_v0.34.7.md`
- `PUBLIC_WEB_DISCOVERY_v0.34.8.md`
- `PUBLIC_WEB_READING_KNOWLEDGE_V04139.md`：Search/Extract/Agnes/DeepSeek 四阶段真值、浏览/知识/分享生命周期、旧片段隔离、清理、预算与分享前复核；末尾含 v0.41.40 用户明确搜索入浏览历史补充合同。
- `WORLDBOOK_2D_PROVENANCE_ROLEPLAY_V04138.md`：世界书三分类、来源快照、角色扮演 Session 与普通成长隔离。

### UI 与仓库入口

- `LIVE2D_HOST_AND_PET_TOUCH_v0.42.34.md`：当前菜菜宿主、独立设置/确认删除、Jev 动作、PCM 口型、宽绘制与窄系统触摸的证据和真机验收。

- `UI_INFORMATION_ARCHITECTURE_v1.md`：五域迁移；已吸收性格底色 UI 的唯一数据源约束。
- `LIVE2D_CLEAN_ROLLBACK_v0.42.0.md`：当前 Sen/Cubism 接入的完整回退边界，以及只清理旧 App 私有模型目录的持久按钮合同。
- `REPOSITORY_MAINTENANCE.md`：分支、总账滚动、统一 validator 清单、CI/资源与旧 Actions 的低风险维护边界。
- `DOCUMENTATION_MAP.md`

### 本地 TTS

- `GENIE_DIRECT_PORT_LAZY_LANGUAGE_v0.41.55.md`：固定 Genie v0.6.4 源提交、排除后来真流式测试板块、独立 TTS 进程崩溃隔离，以及旧中文消息按需生成并缓存单一目标外语的当前合同。
- `GENIE_MULTILINGUAL_TTS_v0.41.53.md`：普通聊天三语同意图消息、中文权威投影、`中/日/EN` 文本语音联动、Genie 四音色、单前端按需加载、双层分段和旧妹居退出的当前实施合同。
- `GENIE_TTS_HOTFIX_SETTINGS_v0.41.54.md`：v0.6.4 前端优先初始化、AudioTrack 打断安全、三语生成/显示/语音解耦，以及规则、世界书和自定义模型设置的本轮候选合同。
- `TTS_RUNTIME_UPGRADE_v0.39.5.md`：当前妹居 TTS 资源、调用、分句与停止契约。
- `TTS_RUNTIME_MANIFEST_v0.39.5.json`：当前 32 项打包资源的大小与 SHA-256 清单。

## 4. 后续可逐步合并，但不阻塞开发

| 未来当前契约 | 可吸收来源 |
|---|---|
| `PERSONALITY_PROMPT_SYSTEM_CURRENT.md` | 性格试穿、内心声、提示词工作台中仍有效的重叠原则 |
| `SOMATIC_SYSTEM_CURRENT.md` | 触觉身体契约与 AI-to-self；双通道文档保留来源原则 |
| `INNER_DRIVE_DESIRE_SYSTEM_CURRENT.md` | 当前融合备份内容，文件名从 BACKUP 稳定迁移 |

只有当新契约完成、引用更新且内容核对后，才删除来源文件；不为追求文件数量而强行合并不同职责。

## 5. 本次已退役的工作树入口

以下路径已在确认并吸收独有内容后从工作树删除，仅从 Git 历史恢复：

- 版本号总账 `AI_Companion_接班总账_v36_2026-08-17.md`
- `app/docs/HANDOFF.md`
- `app/docs/PROJECT_TASK_LEDGER.md`
- `app/docs/DEV_STATUS.md`
- `app/docs/DESIRE_SYSTEM_AUDIT_v1.md`
- `app/docs/ANDROID_DESKTOP_PET_PLAN_v2.md`
- `app/docs/PERSONALITY_BASE_UI_v1.md`

更早的根目录 v29–v32 与 `HANDOFF_LEDGER` 版本文件也只留在 Git 历史。

## 6. 文档维护协议

1. 新任务、排期、实现、CI、实机证据统一更新永久总账；
2. 专项文档只保存稳定机制、接口、边界和验收标准；
3. 总账链接专项文档，但不整篇复制；
4. 每次删除前先扫描引用并吸收独有内容；
5. 旧验证器不能强制要求可变交接文档存在；
6. 纯文档提交不提升 APK 版本，不冒充运行实现；
7. Git 历史负责恢复，工作树负责表达当前真相。
8. validator 只约束快速索引边界与必要接班事实，并核对既有归档 SHA-256；索引后的正式记录没有容量上限。

- 菜菜 +286 夸张表演、Jev幅度/节奏/整模位移与IME验证合同：`CAICAI_PERFORMANCE_V04242.md`。

- `DAILY_WAKE_v0.42.75.md`：+319 每日起床时间、统一边界、醒神疲劳与验收清单。

- `NIGHTLY_DREAM_v0.42.78.md`：+322 用户多轮灵魂/梦境讨论的完整实施依据，午夜补做、反思和证据边界、修订、选择接入与验证状态。

- +329提醒小窗/来电音量/缓存审计：`REMINDER_COMPACT_CACHE_v0.42.85.md`（实施、恢复过程、高风险延期与验证）。

- `WEB_RELEVANCE_RECENCY_v0.42.93.md`：+337相关网页完整读取、近期题材、偏好形成/深度工作区审计（学习策略未修改）。
