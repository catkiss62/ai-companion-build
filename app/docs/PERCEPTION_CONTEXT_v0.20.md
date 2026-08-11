# Perception Context / Daily Awareness · v0.20

## 1. 目的

手机感知的目标不是让模型看到一份“系统日志”，而是让同一个长期伴侣对用户当前生活状态拥有少量、自然、会过期的背景认识。

因此 v0.20 在原始 Android 采集层与模型 Prompt 之间增加独立的本地解释层。

核心原则：

1. 原始事件只作为本地输入/诊断数据；
2. 普通 Prompt 只读取人类可理解的短期 observation；
3. observation 有置信度、时间窗和过期时间；
4. 同类 observation 去重更新，不无限堆积；
5. 单次 Prompt 最多读取 6 条；
6. Active Brain / transfer lock 继续控制谁有权形成“她当前的感知”；
7. 不使用云端模型来解释原始手机事件。

## 2. 数据分层

### A. Raw device events

`device_events` 仍保留 Android 原始采集能力，例如：

- screen_on / screen_off / user_present；
- power_connected / power_disconnected；
- NotificationListener 事件；
- Accessibility 事件；
- 使用情况/前台应用事件。

这一层主要服务于短期本地归纳、调试与权限诊断。

### B. Awareness observations

schema v14 新增 `awareness_observations`。

每条 observation 保存：

- `kind`
- `summary`
- `confidence`
- `window_start` / `window_end`
- `expires_at`
- `dedupe_key`
- `source_fingerprint`
- 粗粒度 metadata
- `device_id`
- created/updated timestamps

`dedupe_key` 唯一，因此“当前活动”不会每 4 分钟新增一行，而是更新同一个语义槽位。

### C. Ordinary prompt

`PromptBuilder` 只调用：

`activeAwarenessObservations(limit: 6)`

不再读取最近 12 条 `device_events`，也不再把旧 `perception_snapshots` 的原始信息直接写入普通模型调用。

## 3. 本地解释类型

当前解释器可以形成：

- `current_activity`：现在大概在进行哪类活动；
- `recent_activity`：最近一段时间主要进行哪类活动；
- `app_switching`：近期切换应用较频繁；
- `screen_state`：屏幕已熄灭一段时间等设备可用性信号；
- `notification_pressure`：近期通知比较密集；
- `availability`：基于多项粗粒度信号得到的低压力忙闲提示。

应用只按粗分类表达，例如游戏、视频、社交/聊天、工作学习，不把 Android package 名带进 summary。

这些 observation 都不是事实宣判。Prompt 明确提醒模型：它们可能判断错误，只能自然参考，不能像监控报告一样向用户复述。

## 4. Accessibility / Notification 隐私边界

v0.19 以前的路径可能让 Accessibility 摘要直接形成 durable Thought，也可能把 raw event stream 直接放入 Prompt。

v0.20 后：

- Accessibility 原文不再形成 Thought；
- Notification/Accessibility 原文不进入 awareness summary；
- 普通 Prompt 不读取 raw `device_events`；
- 高密度事件最多转换为“数量/压力”信号；
- 新 perception snapshot 的 `current_package` 固定为 null。

注意：为了不破坏历史与调试能力，迁移不会自动删除旧版本已经存在的历史 raw 记录或历史 Thought。新链路只保证后续不再继续制造这类泄漏。

## 5. Activity category

Android bridge 为 usage event 增加 `appCategory`。

优先使用 Android `ApplicationInfo.category`，必要时仅在本机使用 package 名做粗分类 fallback。分类结果用于本地解释，包名本身不进入 relationship-facing observation。

当前类别包括：

- game
- video
- audio
- image
- social
- news
- maps
- productivity
- browser
- unknown

## 6. Busy 的定位

`busyScore` 仍是数值，但它属于本地 Gate/策略内部数据，不作为恋爱养成 HUD 展示。

它可以综合：

- 当前/近期活动；
- app switching；
- 通知数量；
- Accessibility 活动密度；
- screen state。

屏幕熄灭会显著降低“当前忙于手机操作”的判断。

主动联系读取最近 15 分钟的 busy score 作为 soft gate；busy 不等于静音，也不会让她完全停止想起或联系用户。

## 7. Active Brain 与跨设备

感知本身会影响 Thought/Desire，因此它也属于“脑状态写入”。

保护路径：

1. `PerceptionEngine.capture()` 开始前检查 `brainWorkAllowed()`；
2. `syncAwarenessObservations()` 在 SQLite transaction 内再次检查 `transfer_lock / active_brain`；
3. observation 同步完成后再次检查；
4. `_integrateIntoInnerState()` 写 Thought/Desire 前再次检查。

因此手机到平板的接管窗口中，旧设备即使已经读取到系统事件，也不能在失去 Active Brain 后继续形成新的内在成长。

导入状态包时，来源设备的 current-state awareness 最长只保留 12 分钟作为过渡提示，之后必须由目标设备自己的 Android 感知刷新。

## 8. 长期卫生

`LongRunningMaintenanceEngine` 会清理陈旧 awareness：

- age cap：14 天；
- row cap：600。

正常 active observation 本身通常会在分钟/小时级过期；14 天只是数据库长期卫生兜底，不表示模型会读取 14 天的“当前感知”。
