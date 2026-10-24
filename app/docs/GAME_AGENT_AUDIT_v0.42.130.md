# 游戏厅 / Agent / 第二通道代码审查

日期：2026-10-24（Asia/Shanghai）。审查对象：v0.42.130+374 已构建源码，远端应用提交 `12415d4`（对应本地 c8c2268，最终交付记录已核对）。只审查，没有修改运行代码、推送或构建。

## 结论与验证边界

当前代码仍有可以从调用链确认的遗漏，主要集中在不同入口使用不同的执行、分类、恢复规则。不能把游戏厅问题全部归因于模型或中转站。下面的触发条件是代码路径，不代表用户已经遇到每一种情况。

检查了前台工具规划/执行/回包、按需 Agent、后台推进/轮询、远端操作回执、状态恢复、动作记账，以及第二通道思考字段传输。进行了源代码断言和独立边界模拟（参数截断、调用 ID 配对）；本机没有 Dart/Flutter，本轮没有运行 Flutter 测试，也没有请求真实游戏服务或模型 API。旧版本 CI 通过不能替代以下新增回归场景。

## 1. 本地拦截也进入整轮禁止重试集合（高）

位置：`core/ai/durable_generation_runner.dart` 的 `executeTaskPlan`；`core/agent/agent_tool_planner.dart` 的 `fromNativeToolCalls`。

`cedar_toy.play` 在 registry 中是 proposal。执行后只按工具风险分类把 fingerprint 加入 `executedToolFingerprints`，没有区分本地 blocked、尚未发送、远端已发送。仅排除 start_timed_play/manage_activity。

触发：先 play，因为缺指南/参与模式/动作锁被本地拒绝；补读指南或条件恢复后再次选择同一参数，被 planner 直接过滤。真实服务器可能一次也没收到；正常循环随后可能结束为 invalidPlan。

建议：由执行结果返回 dispatch 状态；未发送的可恢复阻塞在前置事实改变后允许再次规划；远端未知写入仍禁止重发。不要简单取消所有去重。

回归：play blocked → guide → 相同 play 允许一次真实发送；远端超时 → 相同 play 仍不能重发。

## 2. cmd 查询仍消耗“三步游玩”的检查点计数（高）

位置：`core/mcp/cedar_play_outcome_bookkeeper.dart` 的 `record`；`cedar_solo_episode_policy.dart` 的 `recordOutcome/isStateChangingAction`；后台 `_advanceSessionLocked` 的只读循环检查。

Bookkeeper 虽计算了带参数的 `successfulStateChange`，调用 `recordOutcome` 时仍只传 `succeeded: !outcome.isError` 和 action。后者只判断 action 名，`cmd` 被当成写动作；正常 envelope 的明确拒绝也可增加此计数。随后才用 successfulStateChange 拦住心情、定时 progressCount 等。因此并非所有计数都错，但 solo checkpoint 仍错。

后台防连续只读同样只检查 action 名，`cmd status`/`cmd guests` 可绕过。结果可能是连续查询也达到三步检查点，或者不断查询却没真正推进。

建议：统一基于 action、完整 params、已确认接受状态的动作分类；把“实际接受的状态变更”传给 checkpoint。查询不记进度，但仍计真实工具调用成本。

回归：三个 cmd 查询不触发三步检查点；三个真实推进触发；正常 envelope 拒绝不消耗成功步数。

## 3. 未知结果恢复不覆盖 cmd，且游戏恢复与原请求回执未闭环（高）

位置：`core/mcp/cedar_toy_activity.dart` 的 `markWriteOutcomeUncertain/resolveRemoteDispatch`；`core/agent/turn_execution_store.dart` 的 `reserveRemoteEffect`。

恢复构造/解除仅识别顶层 state/status/observe/look 等。对只能调用 `play(action: cmd, params: {command: status})` 的游戏，可能从指南单词拼出顶层 status；即便正确 cmd status 取得状态，resolveRemoteDispatch 也不认可。

另外，游戏级 unresolved 标记可以被安全快照解除，但原用户请求的 `agent_remote_effect_v2` journal 仍是 dispatching。原请求内重新生成/DS 接管后，即使安全查询完成，后续写入仍被旧 journal 阻塞；新用户请求和同一请求的恢复行为不一致。

建议：查询入口必须来自真实 action/params 协议，不从指南单词推断。建立 reconciled 状态：保留原动作结果未知，不伪造成功；绑定同一目标和新快照，允许新规划的必要后续动作，禁止原未知动作重放。

回归：cmd 写入超时 → cmd status 同目标 → 原请求 DS 接管可继续新动作；不同 slot 状态不能解锁；原未知动作不能重发。

## 4. 房间轮询夹带发言绕过远端写入保护（高）

位置：`core/mcp/cedar_toy_autonomy_engine.dart` 的 `_observeSession`。

此路径可调用 `withMessage` 把回复加入轮询参数，也接受服务端 continuation；随后直接 client.play，没有 admitRemoteDispatch。公共分类器明确规定携带 message 不是纯只读。若请求超时且 waitScope 非空，此处一律当作普通长轮询，1 秒后续查；pendingRoomMessage 只有成功 recordPlay 后清除。

影响：对方可能已收到消息，但本地仍认为没回复，再次生成/发送；不能保证此路径具备普通 play 的未知写入保护。若 continuation 自身是写操作，风险也不限于消息。

建议：按实际 payload 分类；真正无副作用的 poll 才走普通长轮询续期。带消息/写 continuation 必须走统一预登记、结果持久化和未知结果核对。

回归：服务端接收消息后丢回包，下一次唤醒不能再次发送；纯只读长轮询超时仍正常续期。

## 5. 工具结果按工具名反查，可能配给错误的 call_id（高）

位置：`core/ai/durable_generation_runner.dart` 的 `acceptedNativeCalls` 和 generateFinal 内按需循环；planner 的过滤流程。

planner 可以过滤第一个同名调用（例如 fingerprint 已排除），保留第二个不同参数的同名调用。但回包映射只按 name 从原请求取第一个，没保存被保留调用的 ID。按需路径使用 firstWhere，普通路径使用 remaining.indexWhere，均有此条件缺陷。

触发：返回 call_A=旧参数、call_B=修正参数；A 被过滤，实际执行 B，历史里却附上 A 的 arguments/id 与 B 的结果。独立算法模拟已确认这一错配。

影响：下一轮模型看到的操作与实际操作不一致。协议是否直接 400 取决于上游校验；可以确定的是回包身份错误，不能保证修复 reasoning_content 就消除所有 400。

建议：plan 保留源 call_id/源索引，执行结果与源调用一一绑定；对未执行调用明确返回 blocked/未执行结果，不能用另一个调用冒充。

回归：同名 A 过滤、B 执行；断言上游 history 的 ID、原参数、实际执行参数、结果全部属于 B，且无重复/缺失配对。

## 6. 合法工具参数被静默截断成无效 JSON（中）

位置：`core/agent/agent_tool_planner.dart` 的 fromNativeToolCalls。

所有参数值统一 `_bounded(..., 500)`；params_json 是完整嵌套 JSON 字符串，也被字符截断。超过 500 字符的有效参数到 executor 后可能无法 jsonDecode。独立边界模拟已确认。字段也只取前六项，未知字段排在前面时可挤掉必要字段。

建议：按 schema 白名单读取字段；结构化 JSON 完整校验并使用合理整体上限，超限明确报错让模型缩减，禁止截断后发送。

回归：含较长房间回复/嵌套内容的有效 params 保持完整；超限显式错误；未知字段不能挤掉必填字段。

## 7. 前台会接受未完整结束的工具计划（高）

位置：`core/ai/durable_generation_runner.dart` 的 generate/generateInternal/工具执行循环；对照 `core/mcp/cedar_toy_autonomy_engine.dart` 的 CedarAgentActionPlanner。

前台把任意 finishReason 都视为终止信号；没有在执行前排除 length/content_filter 等。若工具参数恰好可解析但生成是被截断的，仍可进入真实执行。最终回复的不完整检查要求 content 非空，不能保护纯 tool_calls；内部规划也不经过该正文检查。后台 planner 已显式拒绝非 stop/tool_calls，因此前后台规则不同。

建议：统一工具计划完整性检查；异常终止的工具计划不得执行，即使 JSON 刚好完整。重新规划只发生在确认未派发时。

回归：纯 tool_calls + length/content_filter + 合法 JSON 均零远端调用；完整 tool_calls 正常执行。

## 8. 动作失败事实没有贯通游戏状态记录（中高）

位置：前台 `_verifyCedarOutcome/_cedarPlay`、activity `recordPlay`、后台 `_verifyOutcome/_advanceSessionLocked`。

前台分类器可以明确返回 action_accepted=false，AgentToolResult 和 turn journal 标失败，但 recordPlay 收到的仍是原 outcome，主要按 outcome.isError 和少量固定拒绝文本判断。非固定句式拒绝可能仍记 outcome、completedPlayRounds、愿望动作证据。前台后续 Bookkeeper 被挡住，不代表之前 recordPlay 没记。

后台分类器不输出 accepted；即使固定文本拒绝被部分记账函数识别，结尾仍仅按 isError 返回 played_one_step；可让调度以为正常推进。两条路径对同一事实口径不一致。

建议：一次形成统一结果（通信结果、动作是否接受、是否状态变更、目标是否完成、下一行动方）；所有状态写入、计数、愿望证据、调度与回复读取同一结果。不能只扩充拒绝关键词，也不需要每次额外增加模型判断。

回归：HTTP/MCP 正常但动作拒绝，在 Agent、活动事件、三步计数、定时进度、愿望证据、调度结果中一致为未推进。

## 第二通道已确认与未确认

- 当前工具规划/结果核验走第一通道；第二通道负责最终表达并可通过按需入口请求 Agent。不是两个模型直接并发控制同一游戏。
- ThinkingToolHistory 已在 streamChat 发送前补齐 assistant reasoning_content，完整工具生成返回保留原始 reasoning；已有空字段/空白保留回归测试。未发现这次审查范围内原来的字段遗漏修复失效。
- 上述调用身份错配是独立于 reasoning_content 的问题；不应将所有 API 400 归因于上游，也不应断言它就是之前截图的成因。
- 当前未访问新存档/真实服务；不把任何新发现描述为已在用户手机复现。

## 建议修改与验证顺序

1. 固化当前版本为对照，给以上触发链补失败回归。
2. 先统一调用 ID、终止原因校验、参数完整性、本地拦截与远端发送状态。
3. 再统一前后台动作分类、记账/调度事实、轮询发言的写入保护。
4. 完成 cmd 协议恢复及同请求/跨请求恢复状态机。
5. 覆盖正常对话、第二通道表达、按需 Agent、后台定时、停止/重新生成/DS 接管的组合测试；不改三步/30 分钟和 Agent 总预算。

注释用于解释不变量；真正防止后续修坏的措施是共用执行契约和跨入口回归测试。

## 实施状态（2026-10-24）

用户已授权修复；v0.42.131+375 实施与回归验证进行中。当前文档前半部分保留审查时 +374 的发现，不能当作新版本现状。CI 未通过前不标记交付。

第二轮候选：远端242031b4434f3950bab75f270a90816c5c971dc8，tree ddad47c11171ba5b8a4261ffe5a455150c1d1a95；对应本地df54549。专项40086603993 / job120850722724：1060测试全部通过，分析0error、62warning、764info（非零告警）。完整构建40086603999仍在运行，暂不标记APK可用。

兼容边界：有明确顶层action声明时恢复使用该声明，cmd-only游戏使用完整cmd参数；后台分享元数据独立读取，不混入可执行params；已核对的未知动作仍不写入成功Outcome，也不能重放原动作。旧存档中缺少turn_id的未知标记保持保守，不凭相同参数跨历史对话解锁。
