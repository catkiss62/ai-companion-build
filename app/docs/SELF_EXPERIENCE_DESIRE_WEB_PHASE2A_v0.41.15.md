# Phase 2A：自我体验、欲望动力学与自主联网

## 目标

本批让无人聊天时的回想、沉思和联网成为真实、可审计、可放弃的经历，而不是角色即兴补写的操作历史。它仍不让学习候选改变普通回复；topic/subject 召回与小幅表达倾向留给 Phase 2B。

## 自我体验合同

1. `MemoryItem` 与 active `UnfinishedThread` 先登记为去重、带版本 hash 和 TTL 的 `self_review_candidate`。
2. 普通候选保留 55～99 分钟与 38% 低频门；重要度至少 0.72 的真实未完素材可越过随机门，但不能越过 Active Brain、租约和来源有效性检查。
3. 只有 `selected` 候选真实形成 Thought 后，才写 `self_experience=completed`；来源失效、未知类型、租约丢失和异常分别落为 discarded/failed，不冒充成功。
4. Thought 可以支持“我想起了某件事、我又琢磨过这件事”。自动上下文、Memory 和 Thought 不等于主动读取聊天档案，不能支持“翻了聊天记录、从头到尾看了一遍”或持续一下午的报告。
5. 自我体验记录只保存来源类型/hash、topic、Drive、状态、appraisal 和时间，不保存隐藏推理正文。完整备份包含候选、体验和欲望事件，旧备份恢复时新表为空。

## 欲望动力学合同

1. baseline 是真实无事件稳定点。自然回归和衰减只作用于 `current-baseline`，不能把处于 baseline 的 Drive 每个心跳继续压低。
2. Drive 耦合以来源轴相对自身 baseline 的 excess/deficit 为零点，不再统一使用 0.5。
3. `desire_events` 保留 14 天不含正文的来源遥测，诊断按轴输出 24 小时 rise/fall/min/max，并按固定 source key 汇总。
4. 熄屏不是“用户空闲”。同一次物理熄屏持续至少 90 分钟后，最多产生一次 social 小脉冲；22 点后随疲劳节律显著折减，深夜接近零。主动消息仍必须有具体 Thought/网页/互动载荷并通过疲劳、冷却、额度和普通 Gate。

## 自主联网合同

1. 只由 curiosity、reflection、social 的真实 Intent 发起，分别映射为 `curiosity_explore`、`reflection_understand`、`social_material`。
2. 离线兜底领域覆盖科学、技术、历史、文化、艺术、生活、娱乐、旅行、手工、运动等广泛主题；同一精确 interest key 会参考近期候选跳过，避免固定六词轮播。
3. 网页结果仍是不可信数据。评价状态固定为 discard、hold、verify、share_candidate；搜索成功不等于必须保存或分享。
4. curiosity 默认保留一条、待核验一条；reflection 默认内部保留/核验；social Intent、wildcard，或独立 social 超过自身 baseline 足够多时，才可提名最多一条分享候选。分享候选仍要经过独立 Thought、主动选择、时机 Gate 和模型 WAIT 决策。
5. 查询不拼接原始私聊、通知、屏幕文字、账号或 Thought 正文。成熟 AI interest 和人格学习的动态偏好输入留到后续阶段，不能从一次网页结果直接生成永久爱好。

## 验收

- 数据库从 schema 42 无损迁移至 43；Snapshot protocol 5 不变。
- baseline 稳定、相对 baseline 耦合、熄屏单次/夜间折减、联网三模式/四评价分支和聊天档案虚报守卫均有专项测试。
- 脱敏诊断包含 selfExperience、desireEvents、screenOffContactWindow 和联网 appraisal 计数，不包含 Memory/Thought/网页正文、查询、URL 或来源 ID。
- Phase 1 学习表继续 observation-only；Phase 2B、Phase 3、截图兼容修复、完整问卷游戏、MCP、查手机与联网存图均不在本批开放。
