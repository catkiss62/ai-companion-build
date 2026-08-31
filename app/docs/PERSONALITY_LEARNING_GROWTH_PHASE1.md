# 人格学习与成长 · Phase 0/1 当前合同

状态：Phase 0 规则分类已冻结；Phase 1 观察层已实现并通过 CI/APK，真机待验。本文只描述 `v0.41.9` 第一真机卡点，不提前承诺 Phase 2/3 行为。

## 1. 固定核心与可成长区域

| 分类 | 当前来源 | Phase 1 处理 |
|---|---|---|
| `immutable_core` | `01_core`、`08_runtime_identity` 中的女性 AI / DeepSeek 身份、现实与工具真值、玩家控制权 | 不学习、不降权、不由用户偏好自动覆盖 |
| `hard_style_ban` | `01_relationship`、`02_daily`、`03_behavior`、`08_visible_inner_voice` 中反客服、反 AI 八股、反万能安慰/守候保证 | 固定禁止模板；不把“成长”解释为学回服务腔 |
| `relationship_fact` | `01_relationship`、长期 Memory、Relationship Event、真实聊天历史 | 仍由现有事实/版本/来源链维护；学习候选不能冒充关系事实 |
| `expression_protocol` | `02_daily`、动作/对白分段、可见思考、主动轮次与 Grounding 合同 | 继续常驻；Phase 1 不修改输出格式或当前轮任务 |
| `trial_script` | `07_base_*`、`07_posture_*`、`07_special_*` 及运行时 profile/special trial | AI 可在知情试穿时故意体验；证据必须带 trial 来源，不进入自然成长 |
| `growth_seed` | `03_personality_seed`、Desire/Thought/Moe 的有界当前状态、未来已成熟 AI habit | Phase 1 只登记用户偏好证据，不向这里写入或注入 |

`04_memory_rules` 是来源与写入边界合同，横跨 `relationship_fact` 和 `growth_seed`，不等于普通性格脚本。成人 `04/05/06` 与沉浸房间规则继续由独立 Session 路由负责，不参与普通人格学习。

## 2. Phase 1 数据边界

Phase 1 只有三种候选 scope：

- `user_preference`：用户明确喜欢/不喜欢怎样相处或表达。
- `relationship_permission`：用户明确说明某种表达在特定关系语境中可以或不可以。
- `trial_preference`：用户对正在试穿的底色、姿态或特殊风格给出的反馈；必须与普通证据隔离。

一条模型提案只有同时满足下列条件才允许落库：

1. 绑定当前真实 `role=user` 消息 ID；
2. `evidence_quote` 是当前用户消息中的逐字短片段；
3. scope、稳定 subject key、证据类型和 support/contradict 极性均在白名单；
4. 普通轮不得写 `trial_preference`，试穿轮不得写自然 scope；
5. contradiction 必须指向手机已经存在的同语境候选，不能凭空制造一个要反驳的命题；
6. 同一候选与同一用户消息只记一次，后台重试不得增加证据。

AI 回复只用于理解“用户正在评价哪一次表达”，不能成为证据。沉默、未反对、消息长度、单纯继续聊天、模型自述和 reasoning 都不能落库。

## 3. 本地成熟策略

模型只能返回结构化 proposal 与建议置信度；手机按证据类型给予上限和权重，并根据独立用户消息计算：

`candidate → forming → established / contradicted / retired`

- 一次明确偏好或纠正通常只进入 `forming`，不会立即改人格。
- 至少两条独立、足够强的支持证据才可能 `established`。
- 用户最新的明确纠正/边界可以立即把旧候选标为 `contradicted`，但历史证据仍保留。
- `retired` 只留给以后用户操作或维护流程；Phase 1 不自动删除。

状态变化只影响观察与诊断。Phase 1 不读取候选来生成普通、主动或沉浸聊天，不写 AI Self，不修改 Desire/Moe，不创建 AI habit。

## 4. 回放验收样本

| 用户证据 | 正确提案 | Phase 1 不得发生 |
|---|---|---|
| “任性一点其实挺好的，而且你不用真的客气。” | `user_preference`，偏好熟悉关系中少客气；第一次为 `forming` | 立刻把 AI 改成每轮任性/粗口 |
| “你刚才那句滚去睡觉挺有意思的。” | 对已发生表达的 `direct_feedback` | 从 AI 原台词本身推断用户喜欢 |
| “可以顶嘴，但认真讨论故障时别故意抬杠。” | 有作用域的偏好/许可与边界证据 | 推导成任何场景都必须顶嘴 |
| “我以前觉得这样好玩，现在不喜欢了。” | 指向已有候选的明确 contradiction | 删除旧证据或制造无来源新人格 |
| 用户只回复“嗯” | 无学习提案 | 因字数短判定冷淡/不喜欢 |
| 试穿中 AI 自己频繁说脏话，用户未评价 | 无学习提案 | 把试穿台词写成用户偏好或 AI Self |

## 5. 隐私、备份与诊断

- 完整证据属于用户本地关系资料，可进入现有完整状态包；旧 schema 41 包没有新表时恢复为空学习历史。
- 脱敏诊断仅输出开关、scope/status/evidence 类型计数、最近写入时间、普通/试穿来源布尔值与拒绝计数。
- 脱敏诊断不输出 subject、命题、证据短句、消息正文、trial 文本、模型 proposal 或候选 ID。
- Snapshot protocol 继续为 5；schema 42 包必须包含两张新表，schema 41 及更早包兼容补空。

## 6. 第一真机卡点

第一包只回答四个问题：是否抓对、是否能反证、是否能备份恢复、是否没有影响她当前说话。只有这四项用真实 DeepSeek 对话闭合后，Phase 2 才允许把 `established` 偏好作为小幅 bias 接入关联记忆召回。
