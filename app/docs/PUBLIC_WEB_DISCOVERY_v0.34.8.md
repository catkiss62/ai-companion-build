# v0.34.8 欲望驱动的公开网页发现

## 目标

把 v0.34.7 的自主行动公共底座接入第一个真实工具，同时不建立第二套人格、欲望或主动消息系统。唯一入口仍是现有 `Desire → Thought → Intent`，工具层只负责执行。

本阶段只发现公开知识候选，不让候选直接进入 Memory、Thought、系统规则或聊天，也不会因搜索成功而直接联系用户。未来若要分享，仍须经过已有的主动联系 Gate。

## Provider 与隐私边界

- Provider：中文 Wikimedia / Wikipedia 官方 REST 搜索接口，HTTPS、无需账号或 API Key。
- 只有好奇、沉思、社交三类合格 Desire Intent 可触发。
- 查询词来自应用内固定的公开主题白名单，并按欲望种类和 UTC 六小时窗口确定性选择。
- Thought 正文、用户消息、Intent reason、关系资料、屏幕内容、通知内容不会组成查询，也不会离开设备。
- 返回内容一律标记为 `untrusted_public`。只保存标题、短摘要、HTTPS URL、来源域、指纹和生命周期元数据。
- 脱敏报告只包含计数、状态、粗粒度时间/错误和来源元数据；不含标题、摘要、URL、查询词、interest key 或 Thought 正文。

## 调度与预算

- 调度点：既有本地 heartbeat 在 Desire tick 之后。
- 普通 Intent 阈值 `0.60`；`wildcard_share` 阈值 `0.58`。
- 每次最多保存 3 个候选；滚动 24 小时最多 4 次已放行尝试。
- 相同 Provider、兴趣键和 UTC 六小时窗口使用哈希去重。
- HTTP 超时 12 秒；Provider/网络/解析失败和无结果均不满足欲望。
- 候选 TTL 14 天，总量上限 240；过期及超量候选自动清理。
- 锁屏不阻止安静的公开网页发现，但 Active Brain、设备接管锁、用户生成占用、预算和重复 Gate 始终生效。

## 一致性与竞态

- 请求先持久化，再由一次性 run token 领取。
- 领取与完成均验证 Active Brain、state generation 和 device id。
- HTTP 在事务外执行；结果提交时再次检查用户生成任务，用户对话始终优先。
- 候选写入、Action Outcome 和小幅 Desire satisfy 在同一 SQLite 事务中提交。
- 只有至少一个新候选成功入库才记 `candidate_stored` 并满足欲望；重复、失败、无结果或失去所有权均不满足。
- 写入后重新加载 Desire snapshot，避免同一 heartbeat 用旧欲望状态立即触发主动消息。

## 本阶段明确不做

- 不自动浏览任意网页、不登录账号、不读取私人内容。
- 不把网页内容直接喂给模型或写入长期记忆。
- 不自动向用户发送搜索结果。
- 不接入屏幕识别或视频理解；它们继续排在后续独立任务中。
