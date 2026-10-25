# QQ / App 记忆第二轮复查补充

日期：2026-10-25（Asia/Shanghai）。基线：`v0.42.135+379`，运行源 `f2e67195bd128ce643a1f1c526c94db6b1b56c75`；前一轮文档远端 `4d63f82e028bbabc6612323c08df044e33881d5a`。状态：**只读复查与文档更新；没有修运行代码，没有运行新 Flutter/Android 测试或构建 APK。**

用户要求再查，发现新问题才补文档。本轮集中追踪现有实现的失效来源、QQ 运行身份、持久投递历史与存档恢复；不把上轮十项扩展适配重复计为新漏洞。

## 结果

新增两项应先修的具体遗漏。R1 是现有检索有效性缺口，App 和 QQ 都涉及；R2 是 QQ 任务缺少存档身份绑定而留下的竞态入口。源码可确认，R1 另做了本地 SQLite 候选查询复核；不声称真实用户已经遇到，也不声称修复完成。

## R1：来源已失效的记忆仍可能进入检索结果

证据：

- [derived_source_store.dart](../lib/core/database/derived_source_store.dart) `revoke`：证据失效后，若无剩余有效证据，将 `memory_items.source_valid` 设为 0，未强制把 `status` 改为非 active。
- [app_database.dart](../lib/core/database/app_database.dart) 原回复移除/重生成路径调用上述撤销。`relevantMemories` 的直接候选及主动候选查询缺少 `source_valid=1`；`memoryCandidatesForExtraction`、推断与历史检索也有同类遗漏。
- [memory_retrieval_policy.dart](../lib/core/memory/memory_retrieval_policy.dart) `evaluate` 只判断相关、冷却与分数，没有拒绝 `sourceValid=false`。
- [memory_brain.dart](../lib/core/memory/memory_brain.dart) 对直接结果的后置筛选不补来源有效性；原文证据通道即使拒绝，也不会自动撤掉已选中的记忆正文。
- [qq_readonly_context.dart](../lib/integrations/qq_private/qq_readonly_context.dart) `_memories` 同样只筛 active/semantic，再调用该纯判定，故 QQ 私聊也会读取这类条目。

触发链：原回复被修改/撤销 → 该回复支撑的记忆失去有效证据但状态仍 active → 后续话题匹配其文字 → 被作为相关记忆交给模型。结果可能是已失效的旧说法重新出现，或被继续提供给提取模型作为候选。

本地复核：在内存 SQLite 中放入一条 active/source_valid=0 和一条 active/source_valid=1 的同主题记录，按 App/QQ 当前候选条件均选出两条；补来源条件后只选出有效条目。另确认纯判定源码没有有效性 Gate。此项只是 SQL 与源码证据，不是完整 Flutter Prompt 执行或真机复现。

建议修补：

1. 在 SQL 候选 LIMIT 前筛 `source_valid=1`，覆盖普通、主动、显式回忆、提取候选、推断、历史及 QQ 路径，避免无效候选挤满上限。
2. 纯判定增加来源失效的防御检查，实际提示词消费前再确保资格有效；同轮并发撤销/修改须用语义版本或当前有效性复核。
3. 不全局用 `isActive` 代替有效性：合法的 superseded 历史版本仍应在历史回忆通道按旧版本语义可读。来源被撤销与事实后来变化是不同情况。
4. 保留用户原话独立证据、合法历史、既有相关性/冷却与角色扮演规则，不顺带删除聊天或重写旧记忆。

必要回归：真实种下源消息和派生记忆，执行回复修改/撤销后，App/QQ Prompt 均不得出现失效正文；提取候选、推断和主动路径亦拒绝；仍有独立用户证据的事实保留；来源有效的历史修订仍能正确回看；大量无效行不挤掉有效匹配。

## R2：QQ 生成/待发送内容没有固定原存档身份

证据：

- [qq_private_main.dart](../lib/qq_private_main.dart) `allowed()` 只检查停止、当前 enabled 和 `BrainWorkFence.workAllowed`，没有捕获/比较生成时的 lineage、generation 或 runtime epoch。
- [qq_readonly_context.dart](../lib/integrations/qq_private/qq_readonly_context.dart) `build` 开头/结尾只检查当前可运行；多次 SQL 查询没有包成同一只读事务快照。
- [qq_session.dart](../packages/qq_private_bridge/lib/src/qq_session.dart) 队列行及已生成回复没有存档身份/上下文版本。发送前仅重查布尔 allowed，恢复后保留的 generated 行仍可进入发送；最近十二轮也只按同绑定日志读取。
- [snapshot_restore_coordinator.dart](../lib/core/sync/snapshot_restore_coordinator.dart) 恢复提交会设置新的 `runtime_state_epoch_v1`；[PortableCompanionState.kt](../android/app/src/main/kotlin/com/aicompanion/localfirst/PortableCompanionState.kt) 的原生便携设置快照不负责 QQ 任务身份撤销。当前 QQ 日志不属于主存档分区。

竞态示例：QQ 在旧状态读取记忆并生成 → App 恢复另一份存档，冻结后重新允许工作 → 旧请求或尚未发送的旧回复再次看到 allowed=true → 可能继续向同一个绑定 QQ 发出旧状态内容。中途若布尔检查恰好看到冻结会停止一部分任务，但这不等于永久拒绝已跨代的任务。源码确认缺少固定身份，不把这个时序描述当作已完成真机复现。

建议修补：

1. 宿主在接纳任务及读取 Prompt 前，以一致只读事务固定存档 lineage/generation/runtime epoch、绑定 namespace/本人及适用的权限/上下文版本。
2. 异步模型回包、保存生成结果、每次分段发送及正式记忆提交前比较原身份。切档/换代/改绑后永久作废旧任务，不因 allowed 再次为真而复活。
3. 原文接收、待发送与近期历史记录带来源身份；跨存档的旧 QQ 历史不自动进入新档近场。合法导入的历史可查询，但不能恢复成待发任务或当前权限。
4. 同代际短暂冻结可以暂停后按合同恢复；恢复换代则必须拒绝旧任务。不要把普通备份暂停误做成删除所有 QQ 记录。
5. Prompt 读取使用一致快照，发送前核对被撤销的关键材料/权限；校验语义和权限版本，不让无关统计更新时间反复取消回复。
6. App 新上下文与 QQ 共享近场的同步属于新方案行为，按既有近场边界适配；不把 +379 原本独立 QQ 历史的设计本身单列为旧漏洞。

必要回归：延迟模型/发送过程中切换 epoch，再恢复 allowed=true，旧内容仍不得保存为可发或发出；generated 行重启跨档亦拒绝；分段发送跨代停止并记录实际已接收部分；同代际冻结/解冻保持正确队列；读取中切换存档不能拼接两份人设/记忆；绑定或公开权限变化也拒绝旧结果。

## 实施顺序调整

在 [总体方案](QQ_MEMORY_GROUP_PLAN_2026-10-25.md) 阶段 A 前增加 A0：先定向修 R1 有效来源 Gate 和 R2 QQ 任务身份/一致快照，再开始记忆写回、跨入口衔接和群聊。二者共享模块的已有调用者也须回归。

本轮不修改实现、测试文件、版本、工作流或已交付 APK。其余已登记的范围/用途、身份、图片、存档、睡眠与参与策略继续执行原方案，不额外扩大为全库重写或向量迁移。

后续第三轮补充见 [QQ_MEMORY_THIRD_REVIEW_2026-10-25.md](QQ_MEMORY_THIRD_REVIEW_2026-10-25.md)：新增 R3 旧行为/能力记忆准入差异及 O1 旧值到当前版本的召回优化。R1/R2 未修复，保留原编号，不重复计数。
