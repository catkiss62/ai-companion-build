# +377 后复查：Agent、游戏厅、悬浮发送与沉浸布局

日期：2026-10-25（Asia/Shanghai）。运行基线：v0.42.133+377，e3a400c5be6d16419396a0c19c2d1e6ed99d0439，tree ff74bbb639ae2c16d2e7161c2cff6e8628f82b53。交付文档远端 e3da1a8e，本地6089cf36，同tree fefda212e9c0135240e5fc0012711118d6db5e0c。

用户要求再次检查并尽量找全问题。本轮审查现有生产调用链、上下游消费者、异步时序和已有回归覆盖，仅更新本报告及总账，不修改应用/测试/构建配置，不开启新APK。以下“确认”指代码可达条件及反例成立，不代表已经在用户手机或真实游戏服务复现。当前环境没有Flutter/Dart/Kotlin SDK；没有把反例推演伪装成新运行测试。

结论：确认9类代码/协议遗漏，另列2项补强/待验证边界。+377的已应用回执保护、主悬浮接受bool、同请求去重、原生命令回调栅栏及新事件read_only仍有效；遗漏集中在未贯通的下游、取消执行目标及无回包路径。

## 确认问题

### F1 · P1：嵌套数组或JSON字符串可以绕过返回存档身份核对

位置：lib/core/mcp/cedar_game_protocol.dart:17、43、51；lib/core/mcp/cedar_toy_activity.dart:1351。

最小反例：请求slot=1，structuredContent为`{"data":[{"slot":2,"inventory":[]}]}`，或structuredContent本身为JSON字符串`{"slot":2,"inventory":[]}`。_evidence会递归数组并解析字符串，承认其状态内容；identityMatches只递归Map中固定wrapper字段，遇到List/String直接true。因此返回明确slot=2仍可通过accepts，继而清除slot=1未知写保护并reconcile原回执。并不表示原未知操作会被直接重放，但解锁所依据的局面不属于要求的存档。

建议：证据识别和身份核对共用同一份解包/解析结果，覆盖Map/List/JSON字符串，保持递归边界；明确身份冲突优先拒绝。不要把数组中的其他实体ID当作目标存档ID，按状态包装的语义核对。回归须调用真实resolveRemoteDispatch，覆盖根字符串、wrapper字符串、wrapper数组和混合目标；合法空背包仍应通过。

### F2 · P1：业务错误与纯确认仍可被当作成功局面/推进

位置：lib/core/mcp/cedar_game_protocol.dart:9、25、141、644；lib/core/agent/agent_tool_runner.dart:992、1149；lib/core/mcp/cedar_toy_autonomy_engine.dart:1830、1872。

项目已有CedarGameResultPolicy.succeeded会把根`error`判失败，但normalizeOutcome只检查MCP isError、文本拒绝及顶层ok/success/action_accepted=false。例如isError=false且structuredContent为`{"error":"insufficient funds","next_actor":"companion"}`时，normalizeOutcome不判失败；结构化回合分支又跳过可选核验，可能保存outcome、计一次推进并把前台结果投影为成功。三套成功/失败口径不一致。

状态恢复也受影响：`{"data":{"ok":false,"message":"temporarily unavailable"}}`的拒绝在包装内，当前不会归一化；message被_evidence视为状态。`{"data":{"ok":true,"error":false}}`只有确认和“无错误”，error=false却因未知非null字段被当成状态证据。它们可以通过accepts并解除未知写保护。上述payload均无可靠游戏局面。

建议：统一业务拒绝归一化，处理真实协议中的error及包装内明确拒绝；传输确认/错误元数据不能充当局面。拒绝、无状态和已取得状态应分开，保留合法0值/空背包等状态，不把模糊包装默认认作成功。回归应贯通前台、后台恢复、步数/报告及最终目标判定，不能只测单个helper。

### F3 · P1：停止请求没有固定目标，存在“停止无效”和“误停下一轮”窗口

位置：lib/core/platform/background_chat_command_server.dart:94、104、134；lib/features/chat/chat_controller.dart:1184、1203、1222、1244、1866；lib/features/chat/chat_page.dart:2648。

时序A：sendMessage通过sendEpoch检查，进入sendText的音频/设置/Key等异步预检；此时sending尚未置true、取消token和job尚未创建。用户点停止，cancelGeneration增加epoch，但cancelCurrentGeneration找不到token/job，停止返回。原sendText预检恢复后仍可创建任务并请求模型，桥直到整轮结束才报告cancelled；增加epoch没有撤销已进入sendText的预检。

时序B：cancelCurrentGeneration先取消本地token，再await _stopTurnAudio，之后才读取_activeGenerationJobId或数据库“当前阻塞任务”。若旧任务在等待期间结束并释放通道，另一聊天入口开始新任务，旧停止操作可能选中并取消新任务。它没有使用点击时的job/request身份；原生对回调epoch的检查不能阻止Dart操作已经误取消任务。sendText的进入检查和主聊天发送按钮也未将cancellingGeneration单独作为互斥条件，旧send的finally还会清除此标记。

建议：从提交开始就建立请求取消身份，提交前检查同一取消状态；停止在第一个异步等待前捕获其拥有的request/job，数据库仅取消该目标。取消完成前保留相应操作的互斥与清理归属，不重新选取后来任务。回归用Completer分别卡住Key预检和音频停止，覆盖跨聊天入口的新任务；不能只测试Kotlin旧回调是否被忽略。

### F4 · P1：已就绪通道不回包时，悬浮“发送中/停止中”缺少自动恢复出口

位置：OverlayBubbleService.kt:1238、1258、1377、1470、1518、1605、2702；BackgroundChatCommandServer.sendMessage等待完整sendText后才返回。

overlaySubmitCommandPending在调用前置true，只靠成功/错误/同步异常、用户再发停止命令或未就绪Engine重建等路径清除。普通发送和停止没有超时核对；generationSnapshot本身不回包时，该轮询链也不会自行调度下一次。即使另一执行者已完成任务、后续快照sending=false，composerSending仍会与旧pending做OR，继续显示生成中。Engine的重建watchdog只处理尚未ready，不能处理ready后某个调用悬而不返。

这是有条件的协议缺口：需要发生不回调/异步调用挂起；不能据此断言用户两次进程退出的根因。

建议：分开“消息已持久接受”和“整轮回复完成”，使用稳定request_id核对是否入库及任务状态；给接受确认/状态轮询增加有界恢复。不要给正常长思考简单套一个很短的整轮超时，也不要在未确认时盲目重发写操作。已知入库后可以恢复跟踪原任务，未确认时保留草稿。增加真实Service/通道不响应、回包遗失、主页面接管完成等回归。

### F5 · P1：通知快捷回复仍可能假成功后丢弃文本

位置：background_chat_command_server.dart:139、149、155；OverlayBubbleService.kt:2753、2768；chat_controller.dart:1167、1184、639。

notificationReply仍忽略sendText的bool，仅用controller.error==null返回ok；原生ok后立即删除待投递项，缺少ok字段还默认true。controller.analyzingImage为true时sendText会清error并直接false，通知入口只检查sending，因此可把未入库文本当作成功并从队列移除。后台controller在普通发送结束后的_resumeUnfinishedVisionWhenIdle确实可能接续待识图任务，不能仅因它是后台对象排除此条件。

该入口还在稳定ID去重之前检查controller.sending；已接受请求的重投在原生成仍进行时可能被报忙并耗尽重试，而非直接确认已入库。

建议：通知、悬浮共用真实接受协议；稳定ID先确认，再判断是否能接收新请求。拒绝/未确认不能消费队列，接受后的生成失败另行呈现。补通知入口的识图忙、重复投递、原任务仍活跃及传输失败回归。

### F6 · P2：read_only未贯通报告、分享和前台收尾

位置：cedar_agent_loop_policy.dart:42；cedar_timed_play_task.dart:426、560、573；cedar_live_share_policy.dart:27；cedar_toy_autonomy_engine.dart:2058。

这些消费者仍用isReadOnly(event.action)/isReadOnly(action)，而不是完整参数或新事件isReadOnly。cmd外壳不会命中顶层只读集合。因此一条read_only=true的cmd status/help事件仍会进入定时任务结束报告的真实推进事件；即使progressCount=0，finishInTransaction的hasOutcome也可将no_progress改成budget_complete，并把报告progressCount抬到1。分享候选也会包含这些查询。

前台shouldFinalizeRound同样把成功cmd查询当成committedMutation，可能提前关闭仍需要查询的工具路径；有未完成写目标时外层有补救条件，不能声称每次查询都会提前结束。后台serverSessionStarted还以lastAction顶层名推断已开始，应一并改用真实接受/参与事实，避免查询或失败历史被用于推断开局。

建议：新事件消费者统一使用isReadOnly==false并保守处理未知；执行中的call使用isReadOnlyCall及完整params。报告、分享、参与事实、收尾各自保持语义，不能把所有“成功回包”当成推进。补只有查询的定时任务最终报告、分享候选、前台多查询，以及真实cmd写入对照。仅验证即时三步计数不足以覆盖这些下游。

### F7 · P2：截断的展示JSON仍决定记事本归属、履约与重复查询

位置：cedar_toy_activity.dart:1603、310；cedar_game_arrangements.dart:17、35、46、363、395。

反例：五槽游戏slot=2，合法提交参数包含2400字符command，事件inputJson被截为2000字符加省略号，整体不能再JSON解析。CedarArrangementScope.current把解析失败当成{}，slotFor又按官方默认补1，将真实2号槽事件归到1号槽；captureReview也沿用此归属。此处“字段确实省略”和“展示截断导致未知”被混为一谈。

completeReviewed仍从截断JSON提取cmd首个动词，而未用event.isReadOnly。长纯查询因此可能不再命中只读过滤，在其他履约条件和模型review匹配时被当作action类安排的完成证据。短的混合cmd也不应仅凭首个动词判断。repeatsUnchangedRead同样解析展示JSON比对参数，长查询失去相同参数识别；有工具预算保护，不能称无限循环，但会重复请求与浪费预算。

建议：事件另存有界的规范目标身份/槽位、完整参数指纹和明确读写事实，展示文本只负责显示。旧事件解析失败应保持未知，不能默认落到1号槽或证明写操作。补长slot=2输入、查询不能完成action安排、混合cmd和相同长查询去重；不需要无界保存全部长参数。

### F8 · P2：语义意图缺省时，只读play会被登记成必须完成的写目标

位置：durable_generation_runner.dart:1684、1691、1714、1748；turn_goal_verification.dart:7、35；turn_task_intent.dart:10。

taskIntent.available=false的降级路径会把任何cedar_toy.play映射到cedarForegroundWrite，未检查action/params。若本轮实际选择的是state或cmd status，查询已成功却无法满足这个新建写目标；外层又因missing goal保留规划通道，形成无谓补执行、错误“未完成”提示或耗到预算。实际写权限仍受执行器约束，不能由此直接断言必然发生未经授权写入。

建议：从用户要求和完整call类别登记目标；读取目标不应自动升级成推进目标。只有查状态的降级路径可以用查询证据收尾，真实推进请求仍要求写/明确接管证据。补taskIntent不可用且仅查询的生产runner用例，不能只测独立TurnGoalVerification拒绝查询满足写目标。

### F9 · P2：旧历史刷新仍可覆盖新提交的乐观消息

位置：OverlayBubbleService.kt:1094、1123、1129、1251；background_chat_command_server.dart:313。

同一窗口中，历史请求先读出发送前的列表；等待投影/回包时用户发送新消息，原生已追加乐观用户气泡。旧历史回包只验证窗口epoch及historyRefresh请求身份，仍可整表替换loadedMessages，抹掉刚追加的气泡并清理状态提示。它没有和提交/数据版本关联。后续数据库刷新通常能恢复消息，故这是显示回退，不等于删除已提交的数据库记录。

建议：历史刷新不能覆盖比它更新的本地提交事实；按稳定ID合并待确认消息，或使旧请求失效并按新状态重读。保留窗口和history请求栅栏，勿仅增加无界刷新。补历史请求延迟返回→发送→旧列表到达，以及停止/重开窗口的组合。

## 补强与待验证项（不混入9类确认问题）

1. **进程退出前的草稿/请求身份仍只在Service内存。** OverlaySubmissionState及pendingInlineReplies没有持久化；当前engineLost分支在同一Service内保留重试，进程/Service真正消失且Dart尚未提交时不能保留。应评估一个最小持久待确认提交记录，重启按稳定ID先核对、允许用户决定重试，不自动制造新轮次。它能缩小退出时丢字窗口，不能代替修复真实崩溃。
2. **聊天页AppBar的窄屏/大字号覆盖不足。** 新6组布局用例测的是大厅ImmersiveLobbyControls，未测房间聊天页标题。聊天页仍有固定3×32px语言按钮及间距、NSFW、48px菜单、返回与titleSpacing，标题固定14号并ellipsis；窄屏/大字号仍有被压缩风险，语言按钮本身也固定24px高。背景迁移方向合理，下一步应给真实房间AppBar补320/360/设备宽度及1/1.5/2字号渲染/几何验证，再决定合并语言菜单或改为自适应控制区；此轮未声称已看到手机上的最终渲染。

**真实闪退根因仍未确认。** 当前无本次手机Java/native堆栈、ANR或ApplicationExitInfo对应退出证据；本轮也未做HyperOS输入法/发送压力实测。F3/F4可解释部分停止/卡住时序，F5/F9解释部分假成功/消息消失，但都不能冒充已定位进程崩溃。发送诊断建议补脱敏稳定request关联及Service/进程代次，以便将阶段记录和持久job对应；不记录正文。不要用旧日期诊断替代这两次退出的证据。

## 既有验证与本轮验证边界

已交付+377的完整CI40116221363通过154源码门、Kotlin、2647全量Flutter、170归档恢复、54 Android15原生；专项40116221345通过1088项。这些是交付基线事实，本轮没有重跑或增加通过数。

已有新增用例覆盖顶层空/确认、顶层错误slot、正常空背包、收到未应用回执、长查询即时分类、主悬浮busy/稳定ID及独立Kotlin状态对象。尚未覆盖上述包装递归拒绝/身份、跨预检取消、旧取消目标、无回包的完整Service、通知接受协议、最终报告/记事本消费者及聊天页AppBar。通过旧用例不能代替新增边界的生产回归。

## 推荐处理顺序

先统一状态证据/错误归一化（F1/F2），以及发送接受、取消目标和无回包恢复协议（F3/F4/F5）。再使读写与目标身份贯通报告、分享、记事本、去重和目标登记（F6/F7/F8），补历史刷新归属（F9），最后完成待确认提交持久化评估和真实房间窄屏/大字号验证。逐项补反例对应的跨入口回归，保留原有权限、预算、未知写防重和游戏三步/30分钟，不需要重写Agent或另加通用工作记事本。

完成这些后仍应按可观察证据验收；静态检查不能保证所有设备时序与未来游戏服务返回均无缺陷。本报告不触发运行代码修改或新构建。
