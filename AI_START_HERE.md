# AI 开发接手入口 / AI handoff

核对日期：2026-10-25（Asia/Shanghai）。本页提供分支、中文功能与源码的对应关系；实际行为以当前源码和测试为准，任务状态以当前总账为准。

## 先确认分支

- 仓库：`catkiss62/ai-companion-build`。
- 本轮开发分支：[agent/v042107-review-recovery](https://github.com/catkiss62/ai-companion-build/tree/agent/v042107-review-recovery)。开始工作时先读取这个分支的实际 HEAD，并与用户授权范围核对。
- GitHub 默认分支是 `main`。2026-10-25 核查时，`main` 下的 `app/lib/core/self/dream_engine.dart` 返回 404，而上述开发分支存在该文件。默认分支与当前开发代码不能互相替代；尚不知道用户的 DSHA 当时读取了哪个分支。
- 最新已交付运行版本为 `v0.42.133+377`，运行源码 `e3a400c5be6d16419396a0c19c2d1e6ed99d0439`。其后审查和讨论文档不代表新功能已经交付。
- 本轮允许在指定开发分支提交代码、测试和文档；未授权合并 `main` 或正式发布。

## 建议阅读顺序

1. [当前总账 v3](app/docs/ledger/AI_Companion_总账_v3.md) 的顶部接班快照，确认最新交付与待办。
2. 根据下表进入相关源码，再追调用者、持久化与恢复路径。
3. 阅读该功能测试及 [文档地图](app/docs/DOCUMENTATION_MAP.md)，按需检索历史设计。
4. 修改后按 [构建说明](app/docs/BUILDING.md) 验证；清楚区分源码检查、自动测试、CI/APK 与真机证据。

根目录 [旧总账永久入口](AI_Companion_当前总账.md) 是 v2 只读历史及跳转入口；不要继续修改其历史，也不要一次把全部旧总账塞入上下文。完整 Flutter/Android 项目位于 `app/`。

## 中文功能到代码的地图

| 功能 / English | 主要入口（路径相对于仓库根目录） |
| --- | --- |
| 梦境、夜间整理、自我理解 / Dream | `app/lib/core/self/dream_engine.dart`、`dream_contract.dart`、`dream_material.dart`、`dream_store.dart`、`dream_review_diagnostic.dart`（后四个同目录） |
| 普通聊天、生成恢复 / Chat and recovery | `app/lib/features/chat/chat_controller.dart`；`app/lib/core/ai/durable_generation_runner.dart`、`durable_generation_recovery.dart` |
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
- 当前实现优先选用工作模型（`FirstChannelModel.work`），梦境请求固定 High。最新待办已确认：改为跟随第一聊天通道 DeepSeek 的模型与对应接口，不写死 Flash、不跟随工作模型或第二通道；本轮未要求另改梦境 High 力度，尚未实施。此前独立默认 Flash 的候选建议已被这项决定替代。
- 历史设计：[NIGHTLY_DREAM_v0.42.78.md](app/docs/NIGHTLY_DREAM_v0.42.78.md)。其中早期 Pro 描述需结合当前路由源码读取。
- 现有测试：[nightly_dream_test.dart](app/test/nightly_dream_test.dart)、[nightly_dream_pipeline_test.dart](app/test/nightly_dream_pipeline_test.dart)、[dream_source_continuity_test.dart](app/test/dream_source_continuity_test.dart)。

有本地仓库时可以先运行：

```sh
rg --files app/lib app/test | rg -i 'dream|reflection'
rg -n '梦境|DreamEngine|FirstChannelModel.work' app/lib app/test
```

仅能通过 GitHub 读取时，明确传入开发分支或具体提交的文件 URL。读取默认 README、默认分支或一个目录的结果，不能当作对当前完整开发树的搜索。

## 本轮未完成事项

- [+377 后九类审查](app/docs/POST_377_AGENT_GAME_OVERLAY_AUDIT_2026-10-25.md)：发现与待修记录，尚未实施新一轮修复；两次手机退出仍缺设备堆栈，不能将逻辑漏洞当作已确认崩溃根因。
- [模型配置与插件讨论](app/docs/MODEL_CONFIG_FOLLOWUPS_2026-10-25.md)：第一通道独立模型/力度、工作模型与凭据，以及梦境模型策略；插件化仅为未来方向。

接手时分别说明已定位、已理解、已修改、已验证到哪一步。没有相应 SDK、CI 或设备证据时，不声称已运行测试或解决真机问题。
