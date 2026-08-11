# Reference Library daily UX · v0.19

## 1. 目的

Reference 不是 AI Self，也不是长期记忆，更不是强制角色卡。

它解决的是：用户有一些人物资料、世界设定、亲密参考或其他背景信息，希望她在相关话题出现时能够查到，但不希望这些大段资料在每轮聊天都占用 Prompt。

v0.19 只改善这套能力的日常管理体验，不改变 Reference 的架构定位。

## 2. 数据原则

每份 Reference Document 同时保留两层数据：

1. `reference_documents.raw_content`：用户粘贴/编辑的完整原文；
2. `reference_items`：从完整原文确定性生成的检索片段。

完整原文是事实来源，片段只是派生索引。

重新分块允许随时删除并重建派生片段，但不能改写完整原文。

## 3. 日常流程

### 新增

用户填写：

- 资料名称；
- 可选别名/检索词；
- 类型；
- 完整资料原文。

保存时：

- 完整原文写入本地 Document；
- `ReferenceDocumentChunker` 生成片段；
- 片段写入 `reference_items`。

### 查看

资料详情页直接显示：

- 当前启用/停用状态；
- 资料类型与别名；
- 完整原文；
- 当前检索片段数量；
- 可展开查看的片段正文。

### 编辑

编辑现有资料时使用数据库 `UPDATE` 语义，因此：

- Document id 不变；
- 原 `created_at` 不变；
- `updated_at` 更新；
- 完整原文/名称/别名/类型更新；
- 派生片段重新生成。

Document 更新与 chunks 替换在同一个 SQLite transaction 中提交；如果中途失败，整次保存回滚，不留下半更新状态。

### 重新分块

“重新分块”只读取当前 Document 的名称、别名、类型与完整原文，重新运行 deterministic chunker。

它不调用模型，不改变原文。

### 停用

Document 与它的所有派生 chunks 必须同步 disabled。

重新分块时，新的 chunks 必须继承 Document 当前 enabled 状态，不能因为重建索引而偷偷重新启用。

### 删除

删除前必须二次确认。

确认后在同一个数据库 transaction 中删除：

- `reference_items WHERE document_id = ?`
- `reference_documents WHERE id = ?`

## 4. 检索边界

Reference 仍通过：

`PromptBuilder → ReferenceLibrary.retrieve(latestUserText, limit: 6)`

进入 Prompt。

因此 v0.19 不会：

- 每轮加载所有 Reference；
- 把人物资料变成永久 system persona；
- 因为页面更方便就提高检索上限；
- 把 disabled 资料作为隐藏常驻规则。

## 5. 与其他长期层的区别

- AI Self：她对“自己是谁”的稳定认识。
- Memory：你们真实发生过、长期值得保留的事实/经历/偏好。
- Relationship：共同经历、关系事件、约定、阶段连续性。
- Thought / Desire：她当下及持续形成的内在驱动力。
- Reference：需要时可查阅的外部背景资料。

Reference 可以影响一次回答，但不能自动取代真实关系长期养成。
