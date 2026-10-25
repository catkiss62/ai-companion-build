# AI 开发接手入口 / AI handoff

核对日期：2026-10-26（Asia/Shanghai）。本页提供分支、中文功能与源码的对应关系；实际行为以当前源码和测试为准，任务状态以当前总账为准。

## 先确认分支

- 仓库：`catkiss62/ai-companion-build`。
- 本轮开发分支：[agent/v042107-review-recovery](https://github.com/catkiss62/ai-companion-build/tree/agent/v042107-review-recovery)。开始工作时先读取这个分支的实际 HEAD，并与用户授权范围核对。
- GitHub 默认分支是 `main`。2026-10-25 核查时，`main` 下的 `app/lib/core/self/dream_engine.dart` 返回 404，而上述开发分支存在该文件。默认分支与当前开发代码不能互相替代；尚不知道用户的 DSHA 当时读取了哪个分支。
- 最新测试包为 `v0.42.135+379`，运行源码 `f2e67195bd128ce643a1f1c526c94db6b1b56c75`；完整CI40183369738通过154源码门、Kotlin、2707全量与170恢复测试，专项40183369812通过1148项，原APK/签名已校验，见[QQ私聊首版实施与交付](app/docs/QQ_PRIVATE_V1_2026-10-25.md)。本包继承+378收尾修补。后续传输/文档提交不改运行代码，不能用分支HEAD替代APK源码；用户已报告本人QQ私聊首轮成功，长期后台等仍待验。
- 本轮允许在指定开发分支提交代码、测试和文档；未授权合并 `main` 或正式发布。

## 建议阅读顺序

1. [当前总账 v3](app/docs/ledger/AI_Companion_总账_v3.md) 的顶部维护重点、收尾任务入口及接班快照，确认最新交付与待办。当前执行清单见[收尾修补与七类复查计划](app/docs/STABILITY_CLOSEOUT_PLAN_2026-10-25.md)。
2. 根据下表进入相关源码，再追调用者、持久化与恢复路径。
3. 阅读该功能测试及 [文档地图](app/docs/DOCUMENTATION_MAP.md)，按需检索历史设计。
4. 修改后按 [构建说明](app/docs/BUILDING.md) 验证；清楚区分源码检查、自动测试、CI/APK 与真机证据。

根目录 [旧总账永久入口](AI_Companion_当前总账.md) 是 v2 只读历史及跳转入口；不要继续修改其历史，也不要一次把全部旧总账塞入上下文。完整 Flutter/Android 项目位于 `app/`。

## 中文功能到代码的地图

| 功能 / English | 主要入口（路径相对于仓库根目录） |
| --- | --- |
| 梦境、夜间整理、自我理解 / Dream | `app/lib/core/self/dream_engine.dart`、`dream_contract.dart`、`dream_material.dart`、`dream_store.dart`、`dream_review_diagnostic.dart`（后四个同目录） |
| 普通聊天、生成恢复 / Chat and recovery | `app/lib/features/chat/chat_controller.dart`；`app/lib/core/ai/durable_generation_runner.dart`、`durable_generation_recovery.dart` |
| QQ本人私聊、独立接入 / QQ private | `app/packages/qq_private_bridge/`（独立Dart子项目）；`app/lib/integrations/qq_private/`（宿主只读适配）；`app/lib/qq_private_main.dart`；`app/android/app/src/main/kotlin/com/aicompanion/localfirst/qq/QqPrivateService.kt`；`app/lib/features/settings/qq_private_settings_page.dart` |
| 模型、思考力度、凭据 / Model configuration | `app/lib/features/settings/settings_category_pages.dart`；`app/lib/core/ai/first_channel_model.dart`；`app/lib/core/storage/secure_config.dart` |
| Agent 工具、执行记录、目标核验 | `app/lib/core/agent/agent_tool_runner.dart`、`turn_execution_store.dart`、`turn_goal_verification.dart` |
| 游戏厅、自主陪玩、定时游戏 / Cedar arcade | `app/lib/core/mcp/cedar_toy_activity.dart`、`cedar_toy_autonomy_engine.dart`、`cedar_timed_play_task.dart`；继续追同目录的协议与核验文件 |
| 作品制作、工作区、作品内互动、交付 / Creative work | `app/lib/core/creative/creative_worker.dart`、`creative_store.dart`、`creative_workspace.dart`、`creative_play.dart`、`creative_delivery.dart` |
| 悬浮窗发送、提交状态 / Overlay | `app/android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt`、`OverlaySubmissionState.kt` |
| 前后台命令衔接 / Background command | `app/lib/core/platform/background_chat_command_server.dart`；`app/lib/background_main.dart` |
| 沉浸房间及列表控件 / Immersive room | `app/lib/features/immersive/immersive_room_page.dart`；`app/lib/widgets/immersive_lobby_controls.dart` |

## 梦境的最小接手路径

梦境会根据真实经历形成可修订的自我理解；涉及来源证据、用户与 AI 自身的区分、反证及不确定性。找到提示词后，还需要理解材料选择和写回边界。

- [dream_engine.dart](app/lib/core/self/dream_engine.dart)：`DreamEngine.maybeDream` 调度、模型调用及运行栅栏。
- [dream_contract.dart](app/lib/core/self/dream_contract.dart)：中文指令、JSON 协议和变更约束；最多 10 条 insights、4 条 changes，允许无变更。
- [dream_material.dart](app/lib/core/self/dream_material.dart)：来源快照、材料序列及关联证据。
- [dream_store.dart](app/lib/core/self/dream_store.dart)：状态、来源核验、提交与诊断。
- 调用入口：`app/lib/core/desire/proactive_engine.dart`；兼容包装：`app/lib/core/self/ai_self_reflection_engine.dart`。
- +378候选已将梦境改为跟随第一聊天通道 DeepSeek 的模型及对应接口（`FirstChannelModel.read`），保留梦境专用 High，不继承工作模型/工作Key或第二通道，也不固定模型版本。模型路由与完整CI已通过，APK已构建校验，真机反馈待补。
- 历史设计：[NIGHTLY_DREAM_v0.42.78.md](app/docs/NIGHTLY_DREAM_v0.42.78.md)。其中早期 Pro 描述需结合当前路由源码读取。
- 现有测试：[nightly_dream_test.dart](app/test/nightly_dream_test.dart)、[nightly_dream_pipeline_test.dart](app/test/nightly_dream_pipeline_test.dart)、[dream_source_continuity_test.dart](app/test/dream_source_continuity_test.dart)。

有本地仓库时可以先运行：

```sh
rg --files app/lib app/test | rg -i 'dream|reflection'
rg -n '梦境|DreamEngine|FirstChannelModel.work' app/lib app/test
```

仅能通过 GitHub 读取时，明确传入开发分支或具体提交的文件 URL。读取默认 README、默认分支或一个目录的结果，不能当作对当前完整开发树的搜索。

## 后续检查与设备证据

- 2026-10-26用户已明确授权公开推送并实施，当前v0.42.136+380候选ae561faf的A0修补与QQ独立回复通道已通过专项1177项及Android15原生54项，完整40230361074已通过154源码门、正在执行后续全量测试及构建；尚无本轮最终APK。[实施记录](app/docs/QQ_MEMORY_IMPLEMENTATION_2026-10-26.md)持续登记CI、失败与交付。先R1–R5回归，通过后A私人记忆/跨入口/O1，再群聊；历史“只文档/未授权”状态不覆盖本次授权。未完成CI/APK不得称已交付。

- 最新第四轮只读复查见[R4/R5 时序补充](app/docs/QQ_MEMORY_FOURTH_REVIEW_2026-10-26.md)：自动记忆/摘要开关缺提交许可核验，旧来源重试新读目标后缺当前事实/生命周期顺序核验。累计R1–R5五项待修缺陷与O1召回优化，A0先修、A补统一检索与受限写回。合成SQLite仅核栅栏比较/队列错序，写回后果为源码分析，非完整Dart/真机复现。仅文档，运行仍+379，未修代码/启动CI/APK。

- 第三轮只读复查见[R3 与 O1 补充](app/docs/QQ_MEMORY_THIRD_REVIEW_2026-10-25.md)：QQ 缺 App 已有的旧行为/能力记忆准入，A0 与 R1/R2 一起修；旧关键词未沿修订链取回新事实为 O1，在 A 统一检索时补齐。合成 SQLite 候选查询和源码复核，不是完整 Prompt/真机测试；仅文档，未修代码/启动 CI/APK。该轮累计三项实现缺陷加一项召回优化，第一轮扩展适配不重复算旧漏洞。

- 第二轮只读复查新增[两项实现遗漏](app/docs/QQ_MEMORY_SECOND_REVIEW_2026-10-25.md)：R1部分App/QQ检索未排除source_valid=0，R2 QQ布尔allowed未固定生成时的存档epoch/绑定身份。R1有内存SQLite候选查询复核，R2为源码确认的竞态入口，均未真机复现/修复。总体方案新增A0先修，仍只更新文档，不改运行版本或启动CI/APK。

- 最新任务已先完成[App记忆兼容性只读审查](app/docs/QQ_MEMORY_COMPATIBILITY_REVIEW_2026-10-25.md)，再修订[QQ共享记忆、群聊与存档方案](app/docs/QQ_MEMORY_GROUP_PLAN_2026-10-25.md)。实际提取器联动欲望/关系，actor/owner非群权限，纠错/原文追读绑定主消息，回忆统计全局，后台梦境/反思存在直接读表；不能直接复用全流程或把群数据全塞旧表。方案采用统一逻辑检索、独立QQ来源/多人记录、范围/用途、受限纠错与独立消费回执，保留旧App行为。用户已报告[+379私聊](app/docs/QQ_PRIVATE_V1_2026-10-25.md)首轮成功；运行代码仍只读、不接群/媒体/主动QQ。主欲望单向、图片存描述、睡眠建议、能力内同级QQ总开关均保留。仅文档，未运行新Flutter/Android测试或启动CI/APK；G1–G7继续后移，未批准新代码实现。

- [收尾修补与七类复查计划](app/docs/STABILITY_CLOSEOUT_PLAN_2026-10-25.md)：统一整理九项漏洞、三项模型/API设置、两项先验证边界和G1–G7复查顺序；第一阶段+378修补与自动验证已完成，APK已取回；状态见[本轮实施记录](app/docs/STABILITY_REPAIRS_v0.42.134.md)。当前暂停等待真机反馈，G1–G7尚未开始。共享同一个“她”，通过明确接口控制各模块修改范围。
- [+377 后九类审查](app/docs/POST_377_AGENT_GAME_OVERLAY_AUDIT_2026-10-25.md)：这是+377审查时的原始发现；F1–F9已进入+378候选，不再作为另一份未实施清单。两次手机退出仍缺设备堆栈，不能将逻辑修补当作已确认崩溃根因。
- [模型配置与插件讨论](app/docs/MODEL_CONFIG_FOLLOWUPS_2026-10-25.md)：第一通道独立模型/力度、工作模型与凭据，以及梦境模型策略。用户最后取舍为稳定优先，保留 App 并改善内部模块；插件运行时/迁入 DSHA 均非当前推进目标，后文历史建议不得覆盖最新决定。

接手时分别说明已定位、已理解、已修改、已验证到哪一步。没有相应 SDK、CI 或设备证据时，不声称已运行测试或解决真机问题。
