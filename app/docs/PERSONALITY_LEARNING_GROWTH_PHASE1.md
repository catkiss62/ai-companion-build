# 人格学习与成长 · Phase 0/1 当前合同

状态：Phase 0 规则分类已冻结；Phase 1 观察层在 `v0.41.10` 挡住上下文附和误绑，但真机仍发现自然同义复述被本地字面门禁漏判，`v0.41.11` 正在进行精确优先的隔离语义复核热修。本文不提前承诺 Phase 2/3 行为。

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

## 7. v0.41.10 本地证据归因补充合同

v0.41.9 真机备份证明“证据来自用户原话”仍不足以保证“证据属于这个候选”。模型可能借上一条 AI 的扩写，把用户对成长节奏的“慢慢来、不急”挂到某个旧偏好；也可能因漏填或漂移 `target_id / subject_key`，把当前原话中明确重述的同向支持丢掉。

因此手机本地裁决增加两条确定性边界：

1. 指向既有候选的 `explicit_preference / explicit_correction / boundary / revealed_choice`，当前用户原话必须与候选命题具有可核对的具体语义重合，并带明确偏好、确认、修正、许可或选择信号。纯节奏、情绪、陪伴或关系保证不能从 AI 上一轮借语义。
2. 没有复用 `target_id` 的 `support`，若当前原话与同一 scope/context 下一个且仅一个候选有充分具体重合，手机可归并到该候选；多个候选同时可能时拒绝，不由模型任意选择。`contradict` 仍必须显式指向现有候选。

另外，纯“慢慢来/不急/时间还长”式语境附和无论模型复用旧 target、复用旧 subject，还是改写成全新的“关系节奏” subject，都不得落证据；只有用户用“我喜欢/我希望/我不接受”等第一人称明确表达自己的节奏偏好，或明确评价上一条表达时，才重新进入普通校验链。

候选读取必须先在 SQLite 按当前 `context_key` 过滤，再按时间排序；手机裁决保留比 API 展示更多的同语境候选，API 只看到最近 16 条以控制 token。数据库不得把未带 `target_id` 的新提案仅因 subject key 碰撞而静默合并进旧候选；复用旧候选必须先经过解析器的逐条目标相关性校验。新支持使候选离开 `contradicted` 时清除旧反证状态时间，但历史反证证据继续保留。

`direct_feedback` 是唯一允许借上一条 AI 定位被评价表达的类型，但当前用户原话仍必须同时包含清楚指代和正/负评价；“你说得对”“慢慢来”之类泛化接话不足以落证据。拒绝原因只以固定枚举计数进入脱敏诊断，不输出候选、证据、用户消息或模型 proposal 正文。

本补充不改变成熟度权重、schema 42、Snapshot protocol 5、试穿隔离或 Phase 1 观察态；学习表仍不得进入普通、主动或沉浸回复，也不得写入 AI Self、Desire、Moe 或长期习惯。

## 8. v0.41.11 隔离语义复核补充合同

真机证明同一个偏好可以在自然聊天中从“越熟悉越不客气、可以说脏话”改写为“偶尔斗嘴、互相对骂、骨子里关心”。这类语义相同但中文字面二元片段不足的明确复述，不得继续被本地字符串算法直接否决；但提高召回率不能重新开放“慢慢来”借 AI 上下文误绑的路线。

裁决分工固定为：

1. 手机继续确定性检查 evidence quote 必须逐字来自当前用户原话、scope/context、target、试穿隔离、无目标反证、幂等和数据库安全。
2. 纯节奏回应、短附和、direct feedback 缺少明确指代、revealed choice 弱推断、无稳定立场和跨作用域提案不能进入语义复核；少量漏判可以接受，误判不可接受。
3. 已有充分本地特征重叠的提案继续直接裁决，不增加 API；只有明确表达偏好/边界、指向唯一同语境候选、但字面不足的项进入隔离复核。
4. 隔离复核只接收当前用户整句、逐字 quote、目标候选 proposition/scope/subject、提案 polarity/evidence kind；不得接收上一条或当前 AI 回复、长期记忆、其他候选、Desire/Moe 或聊天历史。
5. 复核只返回 `support / contradict / unrelated / ambiguous`；置信度低于 0.86 一律按 ambiguous，结果与提案 polarity 不一致、unrelated、ambiguous、超时或失败均拒绝。
6. 复核结果写回 durable post-turn proposal，后台重放必须复用同一个 target/relation/confidence，不能重复调用后得到不同裁决。
7. 脱敏诊断只公开 requested/support/contradict/unrelated/ambiguous/unavailable 计数、最近时间与固定 outcome；不得公开当前用户原话、quote、target id/subject/proposition、模型 JSON 或复核 Prompt。

本补充仍只写 `personality_learning_candidates/evidence`。`growth_seed` 是未来 Phase 3 对成熟、可回滚 AI habit 的来源分类，不是每轮 API 可以直接写入的永久人格库；Phase 2/3 继续关闭。
