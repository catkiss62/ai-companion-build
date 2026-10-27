# v0.42.141+385 QQ 定向复查 · 2026-10-27

状态：仅检查与记录，未修改功能代码、未构建新 APK。源码基线 `8341040ab7711aab1a549c5530b41aa62c1923da`，文档基线 `ed86a52368884817f51567b575e1113dadfe6a89`。用户提供材料来自 +384；不能把 +385 新增路径的源码问题描述成已在这份旧材料上发生。

检查范围：QQ 接收/去重、排队与恢复、私聊和群资料边界、整理任务、群表达观察管理、分条/媒体/SVG、配置与重连取消。现有 +385 CI 通过是既有测试证据，本次发现不代表既有用例已覆盖这些额外路径。

## 结果

确认三处可修补边界，另记录一项速度优化。原文仍保留，未发现本次材料中的记忆来源悬空，不能把整理缺口写成原文丢失。个人材料及聊天正文不纳入公开复现。

### F1 · 高优先：记忆字段错误被当作成功空结果，任务不可自动恢复

[qq_runtime.dart:434](https://github.com/catkiss62/ai-companion-build/blob/8341040ab7711aab1a549c5530b41aa62c1923da/app/lib/integrations/qq_private/qq_runtime.dart#L434) 把不存在或不是字符串的 `memory` 转成空串。通用 JSON 客户端只保证返回对象，不验证业务字段，因此 `{}`、`{"memory":null}`、数字或数组都可落入这个分支。

[qq_store.dart:208](https://github.com/catkiss62/ai-companion-build/blob/8341040ab7711aab1a549c5530b41aa62c1923da/app/lib/integrations/qq_private/qq_store.dart#L208) 在内容为空时不写笔记，但仍推进 `summary_seq` 并把工作置 `complete`；`finally` 的失败登记因任务已完成而不生效。修复重整笔记时还可能删除已撤下的修复占位。新三次重试只覆盖抛异常，未覆盖这种业务格式错误。原文保留，但这批资料不会自动重新整理。

修补：先校验业务对象和字段类型；明确的 `memory:""` 才算成功空结果，格式不合法进入已有失败/退避任务。兼容可选 `share` 时也需明确契约，不把任意对象视为成功。

回归：正常非空、明确空串、缺字段/null/数字/数组分别走真实 `QqRuntime.summarize`；包含修复笔记分支，确认非法结果不推进完成游标、不删除占位，仍遵守最多三次。

### F2 · 高优先：队列前序失败后，会话标志可能永久不释放

[qq_runtime.dart:189](https://github.com/catkiss62/ai-companion-build/blob/8341040ab7711aab1a549c5530b41aa62c1923da/app/lib/integrations/qq_private/qq_runtime.dart#L189) 在任务开始前添加 `_enqueued`，释放却放在 `_workTail.then` 的成功回调内。维护任务 [372](https://github.com/catkiss62/ai-companion-build/blob/8341040ab7711aab1a549c5530b41aa62c1923da/app/lib/integrations/qq_private/qq_runtime.dart#L372) 的 `pending` 查询位于 try 外；[386](https://github.com/catkiss62/ai-companion-build/blob/8341040ab7711aab1a549c5530b41aa62c1923da/app/lib/integrations/qq_private/qq_runtime.dart#L386) 的 finally 维护调度也可能抛出。

注入一次此类数据库/状态读取错误，可使 `_workTail` 成为失败 Future。下一会话先入 `_enqueued`，随后 `then` 跳过整个回调，末尾 `catchError` 虽吞掉失败，却不会执行其中的 finally。该会话从此被 `_schedule` 和 `_enqueue` 的集合检查挡住；别的会话仍可能回复。连接和 Dart ping 仍可正常，所以现有健康重连未必发现。

修补：统一任务入口，在接续前消化前序失败，集合清理放在无论前序/本任务成功失败都执行的位置；维护前置查询和 finally 的错误也必须隔离。只恢复未领取的新输入，不重放已消费判断、未知投递或已发送消息。

回归：生产队列入口分别注入一次 pending 查询失败、维护调度失败；随后同会话和其他会话均可继续，`_enqueued` 不残留，无额外旧轮次模型/投递。

### F3 · 中优先：编辑旧表达观察，会取消并跳过无关的新学习批次

[qq_group_learning.dart:39](https://github.com/catkiss62/ai-companion-build/blob/8341040ab7711aab1a549c5530b41aa62c1923da/app/lib/integrations/qq_private/qq_group_learning.dart#L39) 对单条旧观察的编辑/停用/删除，都会改变同群 epoch，并取消本群全部 pending/running 的 style 工作。

但 [95](https://github.com/catkiss62/ai-companion-build/blob/8341040ab7711aab1a549c5530b41aa62c1923da/app/lib/integrations/qq_private/qq_group_learning.dart#L95) 在登记新学习任务时已推进 cursor。例：旧观察依赖消息 1，新批次依赖 2–13；编辑旧观察后，新批次被取消，cursor 仍为 13，后续查新来源不会再取 2–13。新真人发言仍存着，但其表达学习被静默跳过。

修补：分开“资料版本使旧回复失效”和“学习权限被撤回”；单条编辑不取消来源无关的新批次。整体关闭、恢复和删源仍保留现有撤权；删除旧观察仍不得自动重建同一旧观察。

回归：旧观察编辑/停用/删除与另一批学习在途、退避分别交错；无关新批次可继续，有关被删来源不能提交，不重新学习已消费旧观察。

### O1 · 速度优化：绘图和其他会话仍共用一个串行模型队列

`_workTail` 串行执行回复、整理和学习；[绘图 await](https://github.com/catkiss62/ai-companion-build/blob/8341040ab7711aab1a549c5530b41aa62c1923da/app/lib/integrations/qq_private/qq_runtime.dart#L315) 也在这条队列内，SVG 模型请求超时是 90 秒。群 A 绘图期间，群 B/本人 QQ 私聊的新输入能归档，但回复需等待。这属于已确认的调度耦合，不等于崩溃；App 本身的聊天不走这条 QQ 队列。

后续可评估独立绘图/后台整理队列与普通回复优先级，保留每会话投递顺序、身份/权限/来源校验和重复防护。不要仅改为无界并发，也不必把这项优化和前三项缺陷强行捆成大重构。

## 起床机制核对

共享起床计划仍为每日 480–540 分钟，即本地 8:00–9:00；醒神窗口 45 分钟。App 的零点至起床是独立夜间额度，最多 2 条，不是睡前到起床的完全禁言。互道晚安的场景保护是 90 分钟，也不是整夜锁。

起床前 `DailyWakeSchedule.promptSection` 为空；主动出站另有“尚未到自然起床时间”的契约，但没有充分限定起床前问候的叙事。因此模型可以在夜间额度内写出早安/清醒活动语气，造成看起来提前起床的体验。代码没有固定 7 点起床分支；近期 +384/+385 也没有修改共享起床抽样。

建议只补起床前主动表达的状态约束，保留用户已认可的 8–9 点计划和夜间额度；不擅自改成整夜零回复，也不改整条世界书。真机观感仍需对照后续消息验证。

## 证据与限制

[冻结探针](review_probes/qq_v042141_followup_probe.py)及[结果](review_probes/qq_v042141_followup_results.json)使用合成资料；源文件哈希改变即停止，避免修复后还拿旧模型断言现行行为。已执行 Python/SQLite 及 Node 异步控制流模型，未调用付费模型、真实 QQ 或修改用户备份。

这不是 Flutter/Android 端到端复现，不声称某台手机实际经历了 F1–F3。修补时应添加上文真实 Dart 路径的故障注入回归，而不是把这个冻结分析探针加入以后版本的通用通过门禁。
