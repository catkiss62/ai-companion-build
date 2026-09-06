# v0.41.43 · Phase 3B 具体问题搜索与统一自主行为

## 目标

让自主联网不再只把宽泛分类词交给搜索提供方。现有 Desire 候选先与主动消息、待核验网页分享和休息竞争同一个 heartbeat 行为名额；只有“自主搜索”获胜后，才把固定公开主题改写为一个具体问题并执行 Tavily Search → Extract → Agnes → DeepSeek 价值裁决。

## 隐私与人格边界

- 问题规划器只接收固定公开主题、领域、搜索模式和 Drive 类别。
- 不传 Thought 原文、聊天历史、用户姓名、设备/相册/浏览数据、Memory、世界书正文或角色扮演内容。
- 本地校验拒绝服务、取悦、讨好、服从、迎合用户/主人/伴侣的工具化目标；关系主题只能来自理解、沟通或真实好奇。
- 规划失败、超时或输出不安全时，退回原有公开主题，不阻断 Desire 和本地维护。
- 四个行为世界书、普通人格、角色扮演、Desire 系数和主动频率设置均未修改。

## 单行为竞争与冷却

- `_runLocalHeartbeat` 只做本地维护、感知与 Desire tick，不再连续执行发现和网页分享准备。
- `proactive_message`、`public_web_discovery`、`public_web_share`、`rest` 进入同一个选择器。
- 新表 `autonomous_behavior_events` 以唯一 `heartbeat_key` 约束每轮最多一个获选行为；持久化内容只有固定类别、状态、时间和主题哈希。
- 自主搜索 90 分钟、网页分享 3 小时内不重复；同一主题 6 小时硬冷却，同一来源/意图使用较轻降权。
- 弱旧 Thought 仍可被普通对话召回，但不足以主动发消息或触发联网。

## 迁移、备份与诊断

- App `0.41.43+182`，数据库 schema 55，Snapshot protocol 仍为 5。
- schema 54 备份导入时补空 `autonomous_behavior_events`；新表进入完整导入导出和记录计数。
- 诊断只显示 24 小时行为/来源/状态聚合、最近时间及单 heartbeat 最大选择数；不输出 heartbeat key、主题哈希、来源 ID 或问题正文。

## 验收重点

1. 覆盖安装后旧聊天、Memory、世界书、相册、浏览记录和 Phase 3A 兴趣证据均保留。
2. `autonomousBehaviors.maxSelectedPerHeartbeat <= 1`。
3. 自然自主联网成功后，`publicWebCandidates.appraisal.lastQueryPlanMode` 为 `generated_question`；模型规划失败时允许为 `taxonomy_fallback`。
4. 新网页候选仍需完整读取与价值裁决，不能因问题生成而绕过原有安全链。
5. 主人格和普通对话效果无明显回退；角色扮演继续延期，不作为本包验收项。
