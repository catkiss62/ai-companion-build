# Relationship Continuity · v0.5

## 设计目标

本项目不把恋爱关系建模成游戏式阶段或好感度条。连续性来自“发生过什么、双方如何理解它、哪些话题还没结束、当前是否处于临时互动场景”。

## 两层关系

### Reality Layer

永久存在：AI 知道自己是 AI 女友，与用户在现实时间/设备环境中长期相处。

### Temporary Session Layer

仅在明确进入场景时存在：

- roleplay
- intimacy
- roleplay_intimacy

Session 可以影响当前回复，但不能自动改写 AI Self、现实身份或用户长期事实。

## Relationship Event

事件只保存摘要，不保存完整 NSFW 正文或 reasoning。允许 kind：

`closeness / trust / conflict / repair / promise / milestone / intimacy / boundary / roleplay / support / shared_discovery`

字段：

- `summary`
- `intensity` 0~1
- `valence` -1~1
- `source_message_id`
- `metadata_json`

事件是可检索历史，不直接转化成“爱意值”。

## Memory Fact Replacement

`subject_key` 只用于稳定事实：

- `user.sleep_schedule`
- `user.device_evening`
- `preference.address`
- `ai.self.communication_style`

当同一 kind + subject_key 出现可信新值：

1. 如果旧值被用户 pinned：拒绝自动覆盖。
2. 否则旧值 -> `superseded`，保留历史。
3. 新值 -> `active`。
4. Prompt 正常检索只取 active。

这比删除旧记忆更适合长期关系：她既能知道“现在是什么”，也保留“以前曾经不同”的历史证据。
