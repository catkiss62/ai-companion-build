# QQ 记忆接入与现有 App 的兼容性审查

日期：2026-10-25（Asia/Shanghai）。状态：**只读源码审查完成，已据此修订方案；没有修改运行代码、运行新 Flutter/Android 测试或启动 CI/APK。**

审查基线：`v0.42.135+379` / `f2e67195bd128ce643a1f1c526c94db6b1b56c75`。本轮开始时开发分支 HEAD 为 `5094208165eef465aca1cfd4fb1d5cb70d3ba411`，此前追加仅为文档，运行源未变。用户要求先读记忆相关实现，再整理方案，本文按这个顺序完成。

## 结论与证据范围

现有 App 已有原文目录、可核验来源、精确纠错、摘要、分层检索、角色扮演隔离与快照保护，适合作为扩展基础。其现有合同主要面向单一本人与伴侣，不能把多群、多成员、多权限的数据直接塞入旧链路。以下是新增 QQ 能力时的兼容性冲突及应做的适配，不把尚未启用的群聊路径登记成已发生的旧版漏洞。

读取了提取/提交、来源及版本、检索与消费统计、维护、关系内化、近期连续性、梦境及自我反思、原文工具、模型对谈归档、附件与存档路径，并定点阅读相关回归测试。没有读取用户私人存档、聊天正文或凭据；不能据此判断用户实际记忆质量。相关代码可导航见各项路径，当前行为以源码为准。

## 1. “提取记忆”同时承担其他后处理

证据：[memory_extractor.dart](../lib/core/ai/memory_extractor.dart) `_extractTurnNow`、`_runPostTurnMaintenance`；[relationship_assimilator.dart](../lib/core/relationship/relationship_assimilator.dart)。

- 主提取会处理记忆、游戏约定、未完话题、Thought、关系、互动 Session、人格学习与主动后续；其后还会调用欲望脉冲、满足与互动反馈。
- 关闭 `auto_memory` 也不等于关闭所有欲望后处理；关系事件会由后续内化转为 Thought/Desire。
- 适配：QQ 用受限队列提交档案/摘要/记忆，复用纯判定和事务校验，不调用整套普通聊天后处理，不把 QQ 事件塞进通用关系/Thought 表来“顺便记一下”。尊重自动记忆开关。

## 2. 来源核验依赖普通用户—回复配对

证据：[conversation_source_store.dart](../lib/core/database/conversation_source_store.dart) `qualifyMessage` / `captureMaterial`；[app_database.dart](../lib/core/database/app_database.dart) `insertMemory` 的修订与证据链接。

- 来源从主 `messages` 读取，绑定 role、generation/post-turn 配对、角色扮演、附件状态和内容版本。
- 纠错要求真实原话、目标快照及配对；现有精确原文工具和自动原文补充也只识别主聊天来源。
- 适配：新增 QQ 本人轮次/群片段的来源类型与解析适配；保留 App 既有类型，不伪造 App 消息或放宽普通来源校验。QQ 身份由宿主验证，原文、识图观察、摘要分别定版本。

## 3. 当前人物分类与归属不等于成员身份或访问权限

证据：[memory_item.dart](../lib/core/models/memory_item.dart)、[memory_grounding_policy.dart](../lib/core/memory/memory_grounding_policy.dart)。

- actor/owner 目前仅允许 `user/ai/shared/external/unknown`，不承载某群某成员的稳定标识。
- `owner_key`、记忆生命周期中的 `recall_policy`、`pinned` 均非公开权限。当前模型没有群聊 ACL 与用途合同。
- 当前 QQ 只读适配还会加载常驻/日常规则及适用行为世界书：[qq_readonly_context.dart](../lib/integrations/qq_private/qq_readonly_context.dart)。世界书的 `all/chat` 和加载方式也是功能适用范围，不能直接当成允许向群公开的标记；群提示词需要同样的公开投影。
- 适配：独立保存主体实体、会话归属、可信来源、公开范围、允许用途及权限版本。旧主记忆默认私人并保留原本合法用途，不因迁移自动公开；群成员不能归为当前 user。

## 4. 当前归并/纠错缺少群与访问范围维度

证据：[app_database.dart](../lib/core/database/app_database.dart) `insertMemory` 的 `reinforce`、精确重复与修订检查；[memory_revision.dart](../lib/core/memory/memory_revision.dart)。

- 普通精确归并主要用 kind/content，事实修订主要用 subject/target；这在原单一用户合同内有既定行为，不能直接用于多个群和成员。
- 多来源证据、时间和修订链已存在，是可复用基础。模型对谈另有来源身份隔离：[model_dialogue_archive_worker.dart](../lib/core/model_dialogue/model_dialogue_archive_worker.dart)。这项隔离仍不等于群权限。
- 适配：QQ 归并先比主体、会话/事件、事实命题与范围，不只比文字。跨入口同事件通过稳定关联串起。公开群事实与私人看法分条保存；混合摘要按受限范围。私聊提群事不会自动变成群可见资料。
- 关键验收：本人 QQ 明确更正旧 App 事实，要有真实来源和版本核验后才能更新共同当前事实；不能两边各留矛盾当前值，也不能让普通群友的转述替换个人事实。

## 5. 读取会产生全局消费状态

证据：[app_database.dart](../lib/core/database/app_database.dart) `relevantMemories` / `markRecentlyInjectedMemoriesExpressed`；[memory_maintenance_engine.dart](../lib/core/memory/memory_maintenance_engine.dart)。

- 检索会更新 `last_recalled_at/recall_count` 等；表达匹配使用最近二十分钟全局记录；维护又读取回忆次数和时间。
- QQ 若直接复用写统计路径，可能使 App 的弱相关回忆进入冷却，或把另一入口的注入误作本轮表达基础。
- 适配：QQ 使用自己的消费/表达回执及入口范围，主动分享另做跨私人入口防重。App 旧统计语义保留；候选读取、最终入提示词、发送表达分别登记，不能先统计后过滤权限。

## 6. 有界检索需要在准入前控制范围和来源量

证据：[memory_brain.dart](../lib/core/memory/memory_brain.dart)、[memory_retrieval_policy.dart](../lib/core/memory/memory_retrieval_policy.dart)、[app_database.dart](../lib/core/database/app_database.dart) `_lexicalRecallRows` / `relevantMemories`。

- 现有规则是词法直接线索与主题关联，不是把全部记忆读给模型；高重要性不能替代相关性。候选/最终结果有上限。
- 摘要、推断、历史事实、主题关联、原文追读均有各自入口；只过滤最终主记忆列表仍可能从其他路径带出材料。
- 适配：统一检索入口先按身份、会话、公开范围和用途准入，再选候选/排序；授权过滤不能放在 LIMIT 后。QQ 群数据不能通过数量挤掉原私人相关事实。
- 共享“同一套逻辑检索与事件关联”不要求立刻把多人数据改造成旧 MemoryItem。优先 QQ 独立记录/多人记忆表和统一适配层，保留已验证旧行为。

## 7. 近期可读与后台摘要是两条链路

证据：[conversation_summary_store.dart](../lib/core/database/conversation_summary_store.dart)、[conversation_recall_policy.dart](../lib/core/memory/conversation_recall_policy.dart)、[daily_continuity_engine.dart](../lib/core/continuity/daily_continuity_engine.dart)。

- 主摘要跟踪普通聊天的来源序列及批次；当前默认最少十四条、批次最多三十六条。日连续性从关系/念头/未完事项派生，并非所有外部聊天的实时摘要。
- 近场续问依赖当前提供的最近消息；“那个、刚才那件事”不能仅靠长期关键词检索解决。
- 适配：QQ 分会话摘要游标/片段，App 与本人私聊读取相关最新已保存原文及摘要未覆盖尾部。新上下文、长期遗忘、群近场重置分别处理，避免 QQ 重新塞回用户已清空的私人近场。

## 8. 不主动调用梦境仍不足以隔离后续成长

证据：[dream_material.dart](../lib/core/self/dream_material.dart)、[background_recall_store.dart](../lib/core/memory/background_recall_store.dart)、[deep_reflection_engine.dart](../lib/core/reflection/deep_reflection_engine.dart)、[app_database.dart](../lib/core/database/app_database.dart) `memoryCandidatesForSelfDriveInTransaction`。

- 梦境除主原文外会读活跃记忆作为解释背景；自驱/反思也会选合适的记忆条目。部分消费者直接查表，不全部经过 MemoryBrain。
- 适配：把“能用于私人回答”“可在某群公开”“可成为本人的主动分享材料”“可进入梦境/人格/关系/欲望处理”分开授权。QQ 记忆默认不成为成长数值写入材料；自动回顾、深反思等也要检查，不能只挡一个函数调用。
- 对旧 App 合法来源与既有消费者保留原合同。本人在 App 新作的明确确认是新的 App 事件；单纯复述群旧事不能制造新证据。

## 9. QQ 图片描述与主附件保存合同不同

证据：[message_attachment.dart](../lib/core/models/message_attachment.dart)、[conversation_source_store.dart](../lib/core/database/conversation_source_store.dart)、[snapshot_service.dart](../lib/core/sync/snapshot_service.dart)。

- 主附件含原图/缩略图路径、blob 与描述状态；语义来源哈希涉及描述等字段，主快照按声明媒体复制和校验。
- 适配：QQ 使用独立观察记录，允许无永久图片文件。未看/跳过是明确状态，不能一直挂 pending 阻塞整段记忆；成功描述与后续修正要更新来源版本并使旧提取失效/重算。删除临时图片不等于删除已保存的文字观察。

## 10. 存档与恢复不能只加导出字段

证据：[app_database.dart](../lib/core/database/app_database.dart) `exportAll/importAll`、[snapshot_service.dart](../lib/core/sync/snapshot_service.dart)、[brain_work_fence.dart](../lib/core/database/brain_work_fence.dart)、[conversation_history_catalog.dart](../lib/core/database/conversation_history_catalog.dart)。

- 当前导出/导入有表清单；目录校验只对应主 messages。冻结、Active Brain、代际/epoch 和文件安装均有既有合同。+379 的 QQ 日志在这些清单之外。
- 适配：QQ 表、索引、权限/身份历史、证据、关联和任务进度完整进入有版本分区；导出接收队列协调截点；恢复校验后原子安装，旧回调作废。历史归属不自动恢复当前凭据或发信权限。
- 新增表/字段必须同时验证旧档缺省、迁移、导入回滚、容量及原生验证；保持既有冻结归档不变。关闭 QQ 后禁止后台新调用，已有档案仍可读取。

## 保留的基础与必要优化

保留：现有 Memory 2D 生命周期、直接相关准入、事实/推断/历史区分、精确来源/纠错、角色扮演隔离、渐进维护和快照保护。暂不启动全库重写、向量库迁移或通用知识图谱。

必要优化限定为：新来源类型、上下文/权限适配、多人实体及关联、受限写入、QQ 独立消费统计、分群摘要与近期读取、用途过滤、存档分区和取消恢复。已有主源仍走原路径；共享改动要有旧调用者回归。

重点验收样例：

| 情况 | 必须结果 |
| --- | --- |
| 群已收消息，长期提取尚未执行 | App/本人私聊仍可按需接话，标明群和说话者 |
| 私聊谈群事并表达私下看法 | 私聊原文/新增看法为私人，关联原群事件，群视图不能读到私人看法 |
| 本人 QQ 改正旧 App 事实 | 精确来源与旧目标版本核验后形成共同当前值，不伪造 App 对话 |
| 两个群中同名成员说相似的话 | 不合并人物、事实或权限；群管理员不等于本人 |
| 群里反复引用旧事实 | 不把重复模型转述当独立新证据，不虚增主回忆/表达/欲望 |
| 权限撤销/改绑发生在生成期间 | 旧材料/回包/缓存不能按旧权限继续提交或发送 |
| QQ 写入高重要性经历 | 不绕入原有梦境/深反思/关系内化，受允许用途约束 |
| 关闭自动记忆或开始新上下文 | QQ 不绕过开关提取；已清空的私人近场不从另一入口被悄悄恢复 |
| 图片被跳过或临时图清理 | 不阻塞其他文字片段，不丢已保存描述，不冒称仍有原图 |
| 备份/恢复期间收消息或旧模型回包 | 原文/证据截点一致，旧代际不提交，不补发旧任务 |

已阅读的回归入口包括 `memory_revision_continuity_test.dart`、`memory_retrieval_policy_test.dart`、`g3_source_pipeline_test.dart`、`dream_source_continuity_test.dart`、`conversation_history_v042126_test.dart`、`portable_snapshot_v04256_test.dart` 与 `qq_private_v042135_test.dart`。本轮只阅读测试合同，未运行上述测试，不用 +379 旧 CI 代替下一阶段实现的验证。

修订后的执行方案见 [QQ_MEMORY_GROUP_PLAN_2026-10-25.md](QQ_MEMORY_GROUP_PLAN_2026-10-25.md)。
