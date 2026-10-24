# +376后只读复查：Agent、游戏厅、悬浮发送与沉浸布局

日期：2026-10-24（Asia/Shanghai）。基线：已交付0.42.132+376，运行源码118e010af1ebe0495f632bbda78bb6ab154a7d59，tree695f8b0d6e8b00ea203b29256b205001cfe263a8；交付文档远端1acfe986（本地f560a087同tree863930b2）。本轮只审查并登记，不修改运行代码、不新增构建或声称真机复现。

用户新反馈：沉浸顶部固定标题仍只能显示两字加省略；当天悬浮输入后点击发送发生两次低概率退出，之前的窗口修复有效但未彻底消除。退出类型、堆栈、确切发生阶段尚缺；不能把逻辑遗漏直接认定为进程崩溃根因。

## 1. 状态核对的空结构化回包仍可过早解除保护（优先）

位置：lib/core/mcp/cedar_toy_activity.dart:1307、1332；lib/core/mcp/mcp_protocol.dart的McpToolOutcome.text；现有回归test/execution_recovery_v042130_test.dart:159。

resolveRemoteDispatch判断同目标状态查询成功，只要求outcome.text非空且未显式报错。text会为任何非null structuredContent添加[MCP_STRUCTURED_CONTENT]包装，即使对象是{}、[]或空字符串，投影文本仍非空。空结构未标错误，因此同目标state/status可能清除未知写保护并把对应dispatching回执标为reconciled。现有“空回包”用例只覆盖content为空且structuredContent为null，未覆盖结构化空值。

影响：仅收到空包装/确认信息，也可能被视为已经取得真实状态，允许继续规划；后台尤其可能在缺少新局面证据时放开后续动作。不等于原未知动作已经成功，也不能笼统声称所有恢复必然重复操作。

建议：按实际内容判断是否取得状态证据，剥离包装/空值及纯确认字段；若返回明确房间或存档身份，也核对返回身份。保留不同游戏协议的自由文本有效状态，避免为通用状态查询硬写某个游戏字段。新增真实执行入口的空结构、仅确认、错误目标、真实状态回归。

## 2. 前台回包已知与核验/局面落盘未区分（优先）

位置：lib/core/agent/agent_tool_runner.dart:986–1023；lib/core/agent/turn_execution_store.dart:163；lib/core/ai/durable_generation_runner.dart:478；lib/core/agent/turn_goal_verification.dart:7。

前台先将远端回包写为known（默认next_actor=wait，goal_satisfied缺省），然后核验，再更新回执并recordPlay。保留收到的回包有必要，但当前known同时被恢复路径投影为成功工具结果；foregroundWrite又允许goalSatisfied为null时满足前台写目标。

触发窗口：拿到一个未直接包含明确成功/拒绝证据的回包后，在核验或recordPlay前进程退出。重开会读取known回执，无法从记录区分“只收到回包”和“已核验并保存”。后台未知写保护可能仍在，但任务目标可能已经被判满足，形成两套状态不一致。

建议：保留原始结果用于防重，另存核验及局面保存是否完成；原始结果不能直接满足任务目标。恢复优先补保存或只读核对，不重发原写入。存量缺少阶段标记的回执需兼容核对，不批量改成失败。补在收到回包后、核验后、保存前各阶段中断的生产runner回归。

## 3. 截短的展示参数仍参与查询/动作判定（次优先）

位置：lib/core/mcp/cedar_toy_activity.dart:1584；lib/core/mcp/cedar_game_protocol.dart:142；lib/core/mcp/cedar_play_outcome_bookkeeper.dart:82；后台engagement筛选也使用isReadOnlyEvent。

实际执行参数已保留较长输入，但事件inputJson仍将完整JSON硬截为2000字符。后续三步计数从此字段重新解析是否只读。若一个合法的长cmd查询（如较长help参数或查询组合）超过该长度，截短后JSON失效，isReadOnlyEvent回退到顶层动作cmd；cmd不在只读集合，故可能把查询计成状态推进。recordPlay即时总计使用完整参数，其他计数使用截短参数，会出现入口不一致。

建议：从完整提交参数确定并保存精简的动作类别、目标身份，计数使用这份结构化事实；展示文本可继续限长，不必把所有长原文无界存入事件。兼容旧事件解析失败时保持“未知”，不能反推已推进。补超过2000字符的只读和真实写入对照测试。

## 4. 悬浮发送忽略是否真正接受（优先）

位置：lib/core/platform/background_chat_command_server.dart:85、104；lib/features/chat/chat_controller.dart:1152；原生OverlayBubbleService.kt:1209。

sendText返回bool。generationActive/analyzingImage等情况下可以直接false，且不一定设置error。sendMessage桥忽略该bool，只用controller.error==null决定ok。原生又在调用前清空输入框、添加临时用户气泡；若被拒绝但被报ok，随后数据库历史刷新可移除临时气泡，使文字看起来发送成功后消失。

建议：明确使用接受结果，区分未接受、已接受但生成失败、已完成；保留乐观显示时的草稿并在拒绝时恢复，避免覆盖用户后来输入。普通悬浮发送也可复用已有requestedMessageId能力，将同一次提交的身份传到Dart以便核对，重试不重复创建用户轮次。此缺陷能解释丢消息/假成功，尚不能解释进程崩溃。

## 5. 旧发送/取消回调会清理后来任务的状态（优先）

位置：OverlayBubbleService.kt:1252、1290、1305及1336。

发送回调先清overlaySubmitCommandPending、停止轮询、设sending=false，之后才检查提交时的窗口代次。取消回调仅检查Service仍活着，未绑定对应发送/任务身份。旧窗口或旧任务回调迟到时，可能先清理新窗口/新任务的状态，即使后面判断出窗口不同也已发生修改。

建议：回调先核对具体提交/任务身份、Service/Engine身份，再修改其拥有的状态；窗口身份只控制渲染。不能仅把窗口检查移到最前并直接return，否则同一个仍在执行的任务在重开窗口后又可能留下旧pending。补发送→关闭重开→旧结果、停止→新发送→旧发送/取消结果、后台引擎替换等实际时序测试。

## 6. 小概率点击发送退出：当前能确认与不能确认的部分

IME隐藏和WindowManager更新已有窄范围异常处理，输入法延迟回调也已绑定原View及窗口代次，之前修复仍在。没有发现一个“每次发送必然抛异常”的直接空指针路径。上述4/5是可确认的逻辑遗漏，但没有手机堆栈不能认作今天两次退出的唯一原因。

当前Android15诊断通过ApplicationExitInfo能区分主进程Java/native崩溃、ANR、系统回收等，并已有部分ANR/native脱敏摘要；发送链路没有足够细分的阶段记录。建议结合今天的脱敏诊断先判断退出类型，再补不含正文的提交ID、窗口/引擎代次和发送阶段标记。发送、收键盘、窗口重开、桌宠思考状态切换需在原生窗口中做连续操作验证。现有54项Android原生测试通过不等于已经覆盖完整OverlayBubbleService输入法/发送压力场景。

## 7. 沉浸房间布局推荐

当前聊天页AppBar同时包含返回、四字标题、背景图、中文/日文/英文、NSFW及菜单，固定标题仍会被actions压缩。背景配置本来是共用的RoomBackgroundStorage，不依赖具体room实例，移到房间列表/创建入口适合现有存储语义。

推荐将背景图放在模型选择左边，顺序为背景图→模型→新建房间；聊天页去掉背景按钮，并核对窄屏/放大字号时四字标题可见空间。入口底栏目前_modelButton宽度按屏幕减170计算、列表底部留96，不能只插入按钮；需按实际剩余宽度分配，窄屏换行并同步增加底部留白，避免把创建页也挤坏。沿用原背景编辑器、资源及保存，不另建每房间背景状态。

## 验证边界与后续

本轮结论来自当前源码调用链和边界推演，没有修改运行代码、运行新的Flutter/Android用例、调用付费API或复现用户手机退出。正常工具循环与按需入口的调用ID绑定、思考字段保留、截断计划拒绝仍在；本轮未确认新的400直接成因。建议将1/2/4/5作为同轮小修，3一并修正元数据依赖，再完成窄范围跨入口/中断/原生发送时序回归；不扩大Agent权限、不加通用工作记事本、不改游戏三步/30分钟和主动策略。
