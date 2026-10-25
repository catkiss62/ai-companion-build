# QQ / App 记忆第三轮复查

日期：2026-10-25（Asia/Shanghai）。基线：`v0.42.135+379`，运行源 `f2e67195bd128ce643a1f1c526c94db6b1b56c75`；本轮开始时开发分支文档 HEAD 为 `bcd40a81638c13836eebc25949d4632ba9c12c74`。状态：**只读源码复查、合成数据 SQL 复核与文档更新；未修改运行代码、测试、版本或工作流，未运行新 Flutter/Android 测试，未构建 APK。**

用户希望在实施前继续检查记忆，尽量减少交付后反复修补。本轮沿消息接纳、来源/证据、提取与修订、检索与提示词、发送日志、后台消费者及恢复路径复查。不读取用户私人存档、正文或凭据，不调用付费模型，不向 QQ 发送测试消息。

## 结果与去重

新增 **一项现有缺陷 R3、一项召回优化 O1**。第二轮 R1/R2 仍未修复，保留原编号；第一轮十项仍是新功能接入所需的兼容性适配，不重复计为十个旧漏洞。

| 项目 | 结论 | 安排 |
| --- | --- | --- |
| R3：QQ 绕过旧行为记忆隔离 | 当前源码存在入口口径差异；合成 SQL 可选入被 App 明确隔离的条目 | 与 R1/R2 一起进入 A0 |
| O1：命中旧名称时未沿修订链取新事实 | 修订记录没有丢失，但仅关键词检索可能取不到已保存的新值 | 在阶段 A 统一检索时补齐 |

复查不是运行验收；不能承诺静态检查已经找全问题。实施后仍需要对真实入口做定向回归、完整相关检查和手机试用。下一步不因本文自动开始实现。

## R3：QQ 没有复用 App 对旧行为记忆的准入边界

证据：

- [memory_brain.dart](../lib/core/memory/memory_brain.dart) 在普通事实、推断、历史条目进入 Prompt 前调用 `_allowedDuringPersonalityLearningObservation`。
- [personality_learning.dart](../lib/core/models/personality_learning.dart) 的 `PersonalityLearningBoundaryPolicy` 明确识别旧互动偏好主题、行为偏好措辞和“学习/成长能力已经实现”的说法。目的是避免旧 Memory 条目绕过人格学习的观察边界，直接成为实时表达依据。
- [qq_readonly_context.dart](../lib/integrations/qq_private/qq_readonly_context.dart) `_memories` 只按 active/current_fact 或 shared_experience 查询，再调用词法相关判定；没有上述过滤。`MemoryRetrievalPolicy.evaluate` 负责相关性与冷却，本身不包含该边界。
- [personality_learning_phase1_test.dart](../test/personality_learning_phase1_test.dart) 已有 `Phase 1 boundary identifies legacy prompt bypass records`，但当前 [QQ 测试](../test/qq_private_v042135_test.dart) 没有跨入口覆盖这类旧条目。

触发条件：已有存档中仍保留这类旧记忆，且 QQ 新话题命中文字。App 会在长期记忆通道排除它，QQ 却可能把它标为“相关的已有记忆”交给正文模型。这是材料准入不一致；不等于模型必然照做，也不证明用户当前存档里有这种条目。

合成复核：在内存 SQLite 写入 active/current_fact/source_valid=1 的“用户喜欢说话更幽默”，subject 为 `user.preference.communication.familiarity`。QQ 当前候选 SQL 在查询“幽默”时选中该行；该 subject 明确落在 App 的旧行为记忆拒绝规则内。另逐项核对三个过滤调用在 MemoryBrain 存在、QQ 适配器缺失。**这是实际 SQLite 候选查询加源码对比，不是 Dart 执行、完整 Prompt 测试或真机复现。**

建议修补：

1. 将现有长期记忆准入语义提成可共用的纯策略，让 App/QQ 使用同一判定；QQ 仍通过只读适配器取得文本，不调用会写统计的主库检索或整套后处理。
2. 在最终选满八条前排除不合格条目；必要时有界续取候选，防止这些旧行占掉全部名额。不得先记录“已注入”再过滤。
3. 该策略只处理长期记忆材料。用户明确配置的世界书/表达指南、核心性格与合法普通事实保持原合同，不借此关闭活人感设置或改变人格学习阶段。
4. 后续群适配同时执行来源有效性、共同准入、可见范围与用途检查；这几道检查不能互相替代。不能以群身份校验或 R1 的 source_valid 过滤代替 R3。

必要回归：通过真实 App/QQ 上下文构建器读取同一隔离条目，两个长期记忆通道均拒绝；普通活动偏好等合法事实仍可读；高重要性/固定/大量旧条目不能挤掉正常结果；QQ 读取前后数据库、回忆统计与欲望不变，App 统计沿原合同处理。应覆盖主题命中、行为措辞命中、能力已实现措辞命中，并保留显式世界书原行为。

## O1：只命中旧称呼/旧值时，没有把修订后的事实一起带出

证据：

- [app_database.dart](../lib/core/database/app_database.dart) 的 `relevantMemories`、`relevantHistoricalMemories`、`memoryCandidatesForExtraction` 分别依赖关键词候选；修订写入已有 `superseded_by/revision_of` 链。
- [memory_brain.dart](../lib/core/memory/memory_brain.dart) 会分开读取当前和历史候选，但没有由已命中的旧条目沿链读取有效后继；主题关联也以当前直接候选为种子，不能补救当前候选为空的情况。
- QQ 首版仅查 active 条目，也没有旧值到现行版本的关联查找。
- [memory_grounding_policy.dart](../lib/core/memory/memory_grounding_policy.dart) 会正确提示“旧说法已纠正/事实后来改变”，但不能凭一条旧记录推导未提供的新值。现有修订测试主要覆盖写入链与旧版本措辞，未覆盖仅旧关键词查询时的新版本取回。

合成复核：旧记录为 `Preferred project codename was Azurefin.`，status=superseded、reason=correction、superseded_by=new；新记录为 `Preferred project codename is Cedarwave.`，active/source_valid=1。二者 subject 同为 `user.project_codename`，tags 为空。查询 `Azurefin`：

| 当前候选查询 | 实际 SQLite 结果 |
| --- | --- |
| App 当前事实 | 空 |
| App 历史事实 | old |
| QQ 当前事实 | 空 |
| 按已有 superseded_by 取后继 | new 存在 |

因此，通过这一长期记忆链路，App 可能只拿到“旧值不正确”，QQ 可能完全拿不到，虽然正确值已经保存。其他近期对话或摘要恰好含新值时可以补救，所以这里登记为**召回完整性优化**，不声称发生了记忆丢失、错误覆盖或必然说错。该复核同样只执行候选 SQL，没有执行 Flutter/模型回复。

建议修补：

1. 在已获准、直接相关的旧版本命中后，沿明确修订关系有界读取有效后继，将“旧值为何失效”和当前值成组提供；不凭相似话题猜修订关系，不扩大为全库回忆。
2. 多次修订设置去重、循环检测及预算，优先保留有效当前版本；断链、来源失效或无权读取时明确未知，不自动把旧值恢复为当前事实。
3. 每一跳重新检查主体、来源、范围/用途及共同准入。未来群入口若无权看私人后继，不能通过版本关联得到私人新值，连“存在私人修订”的提示也按权限处理。
4. 区分 correction 与 change：记错的旧值不能描述成过去成立；真实后来变化可带历史限定。仅查历史、仅查当前的模式按各自合同展示。
5. 统一检索与提取候选可共用这段版本定位；目标写回仍需原有版本快照及事务核验，不因找到后继就自动改写、强化或创造证据。

必要回归：只有旧名称关键词、只有新名称关键词、连续两次修订、纠错/后来变化、空 subject 的合法纠错、断链/循环/失效后继、候选预算拥挤及未来私人后继越权。通过 App/QQ 实际上下文核对事实与措辞，不只测试手工 SQL 或格式化函数。

## 本轮核对后未另计为新增漏洞的部分

- 主提取来源字符串已带 assistant revision（`@r...`），不能仅因重生成复用消息 ID，就认定所有新版证据一定被旧 source 去重挡住。实际证据撤销后被检索的问题仍按 R1 修。
- `ConversationSummaryStore.commit` 已重核原始 work fence、批次状态和每条来源版本；不因“模型已返回”就无条件提交摘要。
- App 恢复界面会冻结并等待 `post_turn_memory_lease` 等写入者，超时则拒绝继续；主导入也会清运行令牌。不能把 QQ 缺少原档身份的 R2 直接推广成所有 App 提取都能跨档写入。仍应在实施回归中覆盖迟到结果和失效租约。
- 附件语义哈希、移动文件路径不改内容身份、媒体来源重新入扫描已有实现/测试合同；未来 QQ 图片“描述修订”和“仅清理原图”仍按第一轮适配区分，不能一律撤销合法文字记忆。
- 后台回忆、梦境背景等有部分现成有效来源过滤；新 QQ 数据的用途隔离仍须覆盖直接读表者，按第一轮方案落实，不以某一个过滤器替代整链检查。

这里是定点核对的结论，不等于上述模块所有时序均已通过运行测试。

## 累计实施安排

1. A0：R1 失效来源准入、R2 QQ 存档身份/一致快照、R3 共同旧记忆隔离，先做定向修补与真实入口回归。
2. A：原计划来源/范围/用途、存档、统一检索与受限本人写回；同时补 O1 修订链取回，验证旧 App 合法行为与新 QQ 连续性。
3. 其后仍按原 B–E 推进群安全、参与/图片、群记忆与分享，黑话可后移。G1–G7 大检查顺序不变，不借本轮开始重写或扩展娱乐玩法。

三轮审查入口：[第一轮兼容性审查](QQ_MEMORY_COMPATIBILITY_REVIEW_2026-10-25.md)、[第二轮 R1/R2](QQ_MEMORY_SECOND_REVIEW_2026-10-25.md)、[统一修改方案](QQ_MEMORY_GROUP_PLAN_2026-10-25.md)。实施完成时按同一基线合并验证，再决定打包点，旧 +379 CI 不能代替新修补的证据。
