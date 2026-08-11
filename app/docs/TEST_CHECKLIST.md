# v0.29.0 真机检查

## A2 TTS

- [ ] 黄金资源 37/37 通过。
- [ ] 分阶段 TTS 诊断通过。
- [ ] 长文本第一句允许有模型预热，但第二句以后不再出现“上一句播完才开始生成下一句”的长空白。
- [ ] 只按 `。！？；.!?;` 分句；逗号、顿号、换行、省略号不人为切开。
- [ ] `Yuki` 仍读“有希”。
- [ ] 播放中 Stop 立即停止，旧生成结果不会稍后复活。
- [ ] 停止后重新播放能正常建立新队列。

## GitHub Clean Baseline

- [ ] promotion workflow 成功把完整源码提交到 `app/`。
- [ ] clean build workflow 只从 `app/` 构建成功。
- [ ] 上述两项成功后才删除/归档旧 5 个分包与 v0.28.x patch。

---

# v0.28.5 真机检查

1. 启动进入主界面，不再卡 Chat loading spinner。
2. “更多 → AI 与陪伴设置 → 测试 API 连接”：先确认当前 API 地址/Key/模型可用。
3. 深度 TTS 自检：37 项黄金资源应通过，`libbertvits2.so` 不再 fingerprint mismatch。
4. TTS 测试发声：确认本地 Meju 音色与 `Yuki → 有希`。
5. 以上两项通过后再继续 UI 优化与后续后台/双设备测试。

---

# v0.28.2 SQLite Open 真机检查

1. 启动必须立即看到 `AI Companion · v0.28.2 · SQLite Recovery`。
2. “打开本地数据库”应通过，不再出现 `PRAGMA journal_mode = WAL` 的 execute/rawQuery 错误。
3. 如果数据库通过，记录“检查本机身份”和“进入主界面”是否继续通过。
4. 首次进入主界面后再继续原 Checkpoint；当前轮先不要同时排查 TTS/Nearby。

---

# v0.28.1 Startup Recovery 真机检查

1. 启动后必须立即看到 `AI Companion · v0.28.1 · Startup Recovery`，不得继续纯黑。
2. 记录四步中停在哪一步：Flutter 首帧 / 打开本地数据库 / 检查本机身份 / 进入主界面。
3. 如果超时或异常，截图完整错误卡片，不需要先授权任何权限。
4. 如果进入主界面，再回到 v0.28 Checkpoint 顺序继续快速自检、深度 TTS、发声、权限/感知、悬浮/后台、双设备。

---

# v0.28 First real-device checkpoint

Recommended order on the first phone APK:

1. `第一次综合真机验收` → 快速自检。
2. 深度自检：37 项 TTS 黄金资源 + JNI/MNN 初始化。
3. 播放固定测试语音：确认音色、首句等待、断句、`Yuki -> 有希`。
4. 授权并刷新感知：UsageStats / Notification listener / Accessibility / Overlay / notifications。
5. 切前后台、锁屏/解锁、测试悬浮聊天和通知。
6. 失败时保存脱敏诊断报告。
7. 单机通过后才在平板安装同一 APK，测试 Nearby 发现/传输/顶号和中断恢复。

---

# 累积测试清单 · through v0.14

## v0.28.5 新增 TTS 检查

1. 黄金资源校验应为 37/37。
2. 先运行“分阶段桥接诊断”：真实初始化、生成 WAV、校验 RIFF/WAVE，但不播放。
3. 若失败，记录最后通过阶段和错误原文；若通过，再运行实际发声。
4. 实际发声确认音色、断句、`Yuki → 有希`，再测停止与连续播放。
5. 本版不混入 UI 改动。


## A. Schema / 迁移

- [ ] 全新安装创建 schema v5。
- [ ] v0.5 / schema v4 升级后补齐 tts_streaming_enabled / proactive_tts_policy / last_proactive_spoken_message_id。
- [ ] v0.1–v0.5 状态包导入 v5 后存在安全默认 TTS 策略。
- [ ] relationship_events / interaction_sessions / memory v4 字段仍可导出导入。
- [ ] 目标设备导入后仍保留自己的 device_id。

## B. Streaming Sentence Splitter

- [ ] 中文 `。！？；` 和英文 `!?;` 可形成可播放句子。
- [ ] DeepSeek delta 跨多次返回时不丢字、不重复字。
- [ ] fenced code block 不进入流式朗读。
- [ ] code fence 恰好被拆成两个 delta 时仍能正确识别。
- [ ] 超长无句号文本会在 soft/hard limit 附近切分，不会无限等待。
- [ ] flush 会把最后没有句号的尾句送入队列。
- [ ] reasoning_content 永远不会进入 segmenter。

## C. Speech Queue / Cancel

- [ ] 队列同一时间只调用一条本地 TTS。
- [ ] DeepSeek 继续流式生成时，后续句子只排队不并发调用 JNI。
- [ ] 新用户消息会 stop 当前播放并清待播队列。
- [ ] 手动 Stop 会清掉 Dart 未开始的句子。
- [ ] Stop 发生在 MNN 推理途中时，旧 WAV 返回后不允许启动 AudioTrack。
- [ ] Main / Overlay / Background 三个 FlutterEngine 共享 native runtime 时，NativeTtsEngine 内部仍串行访问 MNN。

## D. Chat / Overlay Controls

- [ ] 完整聊天播放时顶部出现停止按钮。
- [ ] 悬浮聊天播放时同样可停止。
- [ ] 每条 AI 历史消息可手动重读。
- [ ] TTS 队列状态变化时，如果用户正在翻阅旧消息，不会被强制滚到底部。

## E. Proactive Voice Policy

- [ ] silent：只写入消息、通知、未读数字，不发声。
- [ ] when_overlay_opened：通知阶段保持安静；用户打开悬浮聊天后只读最新一条尚未读过的主动消息。
- [ ] when_overlay_opened 同一 message_id 不重复自动朗读。
- [ ] immediate：只有 tts_enabled=1 时才允许后台朗读。
- [ ] immediate 后记录 last_proactive_spoken_message_id。
- [ ] 默认设置不会因升级而突然后台发声。

## F. v0.5 回归

- [ ] Memory Fact Replacement / pinned / superseded 保持。
- [ ] Relationship Event / Temporary Session 保持。
- [ ] DeepSeek reasoning/content 仍独立。
- [ ] Desire/Thought/Proactive 逻辑不因语音队列改变。
- [ ] Perception 流不受影响。
- [ ] Nearby / Active Brain 不受影响。
- [ ] Meju `.so` / `.mnn` / tokenizer / dictionary 内容 hash 不变。

## G. 未来需要用户真机/人工测试

- [ ] 本地 TTS 实际发声。
- [ ] 分句后句间停顿是否自然。
- [ ] Stop 在“正在推理”和“正在播放”两种阶段的真实体感。
- [ ] Overlay 在 QQ/游戏中的触摸、键盘、语音干扰程度。
- [ ] Android 权限流程。
- [ ] Nearby 手机↔平板真实传输。

这些不要求每个源码版本都由用户执行；到对应里程碑再集中提供 APK。

## G. v0.7 Relationship Memory Dynamics

- [ ] schema v5 -> v6：memory retention 两列存在且旧记忆 retention=1.0。
- [ ] schema v1 -> v6：旧 memory/thought 数据仍可读。
- [ ] 升级已有 v0.6 数据库时，旧 relationship_events 自动标记为已内化，不在升级后重新脉冲 Desire。
- [ ] 新 relationship_event 创建后 internalized_at 为 null，RelationshipAssimilator 成功后写入时间。
- [ ] pinned memory 不进入自动淡化候选。
- [ ] 低保留度记忆只进入 archived，不删除 messages。
- [ ] 从 archived 手动恢复后 retention 得到强化。
- [ ] Reference Library 与 memory_items 分表。
- [ ] index-like JSON 中 messages/history/reasoning/save/log 不被参考解析器导入。
- [ ] Reference 只有相关片段进入 Prompt，且系统文本明确其不能覆盖 AI 本体身份。
- [ ] reference_items / retention / internalized_at 可随 Nearby 状态包转移。
- [ ] v0.6 TTS 37 个 native/model/runtime 文件 hash 不变。

## H. v0.10 主动回应与 Thought 长期卫生

- [ ] v8 -> v9：Thought topic/merge/snooze 字段存在，旧数据默认值正确。
- [ ] v8 -> v9：旧 proactive feedback 按回应状态回填 pending / response_received / no_response。
- [ ] 主动消息绑定 thought_id + topic_key + thread_id。
- [ ] 用户只是回复消息时，只解除 acted 等待，不自动判定话题 resolved。
- [ ] proactive outcome=deferred 时，同一未完成话题不能被 contradictory thread proposal 关闭。
- [ ] proactive outcome=dismissed 时，同一 thread 进入 dismissed，不被误写成 resolved。
- [ ] proactive outcome=resolved 时，同 topic 的相关 Thought 一并得到满足/沉降。
- [ ] 普通后续聊天若 resolve 同一 unfinished topic，同 topic Thought 也得到满足，避免以后再问已经完成的事。
- [ ] 用户自己重新提起 snoozed topic 时，conversation evidence 可以重新激活；self-drive/perception 不能偷偷解除 dismissal snooze。
- [ ] 同 drive + 同 topic_key 的重复 Thought 可合并；无 topic_key 仅允许高相似文本合并；不同 drive 不自动合并。
- [ ] 合并后 proactive_feedback / thought_lifecycle_events 仍指向存活 Thought。
- [ ] 普通用户每一句话不再直接创建 durable Thought。
- [ ] 忙碌状态仍为 soft gate，不存在 userBusy => hard return/mute。
- [ ] v0.9 -> v0.10 TTS native/model/runtime 37 个文件 hash 完全一致。

## I. v0.11 长期运行卫生 / 并发 / 转移审计

- [ ] schema v9 -> v10：unfinished thread 六个 follow-up/retirement 字段默认正确。
- [ ] fresh v10：post_turn_jobs / maintenance_runs / idx_thread_followup 正常创建。
- [ ] deferred outcome 可设置 6–72h followup_due_at；followup_seeded_at 防止每次 heartbeat 重复强化。
- [ ] 默认 max_deferred_followups=1；真正发送后 followup_count+1 并清 schedule。
- [ ] resolved/dismissed/真实 conversation update 会清旧 deferred schedule。
- [ ] stale low/medium/high thread 按不同时间退休；importance >= 0.92 不自动退休。
- [ ] 退休 topic 的相关 active/fixation/acted/residual Thought 转 dormant，但原始消息和 thread 历史不删除。
- [ ] lifecycle/proactive/perception/device-event 清理有 age/cap 边界，不触碰 messages / relationship / AI Self / reference / rule layers。
- [ ] post_turn_jobs 成功、失败、stale-running 恢复和设备迁移 running->pending 路径正确。
- [ ] background heartbeat 在没有新聊天时也能重试 pending/failed post-turn memory job。
- [ ] transfer_lock=1 或 active_brain=0 时 post-turn queue 不运行。
- [ ] owner-token lease：旧 worker 超时后不能 release 新 worker 的 lease。
- [ ] RelationshipAssimilator / MemoryMaintenance / ThoughtConsolidation / AI Self 异常时 lease 必须 finally 释放。
- [ ] Desire 多引擎 read-modify-write 使用单 SQLite transaction，避免 pulse lost update。
- [ ] full app 与 overlay 同时发送时只有一个能取得 chat_turn_lease。
- [ ] active_brain=0 的设备拒绝普通 sendText，不只是停止 proactive。
- [ ] 发送状态包前等待 chat/post-turn/proactive writer 结束；超时则取消快照而不是强行导出。
- [ ] snapshot export 多表在同一 SQLite transaction 读取。
- [ ] snapshot import 后保留目标 device_id；active_brain=0；runtime lease/感知瞬态状态清零。
- [ ] Nearby takeover：receiver request -> source offline -> source ACK -> receiver Active。
- [ ] takeover ACK 失败/断连/12s 超时时 receiver 保持 standby；手动接管必须明确提示先确认旧设备下线。
- [ ] 连接失败/传输失败/断连后旧 snapshot 不可继续用于自动接管。
- [ ] snapshot ZIP 只允许 state.json + manifest.json，校验大小/版本/SHA-256，并清理临时目录。
- [ ] Thought merge：旧 acted duplicate 不能压过新 active/fixation topic。
- [ ] fresh install `tts_streaming_enabled=0` 与升级默认一致。
- [x] v0.10 -> v0.11 Bert-VITS2/MNN native/model/runtime 32 个文件 hash 不变；Dart 队列有 1 个有意安全修改。

### v0.11 audit additions

- [x] source export waits active writers; receiver import also waits old local writers after transfer lock.
- [x] receiver Active Brain/transfer lock/device id/runtime lease overrides are transactionally applied with imported data.
- [x] proactive final eligibility + assistant INSERT is atomic against chat lease/new user activity.
- [x] chat/proactive streaming leases periodically renew by owner token; stale token cannot renew.
- [x] DeepSeek stream/header/JSON waits have bounded 120s timeout paths.
- [x] post-turn memory job is durable before chat lease release; safe drain used from UI initialization.
- [x] Active Brain generic settings-save race removed; manual reactivation requires explicit confirmation.
- [x] ZIP duplicate/allowlist/size/hash/schema and cache/plaintext cleanup paths reviewed.
- [x] v9 -> v10 migration simulation and one-shot deferred follow-up query pass.
- [x] Bert-VITS2/MNN native/model/runtime 32-file SHA-256 comparison against v0.10: 0 changed / 0 missing; Dart TTS queue has one intentional stop-safety change.
- [ ] Flutter analyzer / Dart tests / Gradle / Android real-device tests: intentionally not claimed in this environment.


## J. v0.12 Android 生命周期专项审计

- [x] Manifest XML 可解析；Android 12L/API 32 仍有 ACCESS_FINE_LOCATION/Wi-Fi compatibility，API 33+ 切到 NEARBY_WIFI_DEVICES。
- [x] RECEIVE_BOOT_COMPLETED + BootReceiver 存在，只有 user-enabled + overlay permission 时尝试恢复。
- [x] overlay permission watchdog 存在；权限撤销会停止 service。
- [x] unread/badge command 不覆盖最近 service start reason。
- [x] screen on/off、unlock、power connect/disconnect 进入本地 device_events。
- [x] NotificationListener onListenerDisconnected 有 requestRebind 路径。
- [x] Accessibility permission state 与实际 connected state 分开。
- [x] Background FlutterEngine destroy 前 dispose bridge；low-memory 通知 framework + Dart VM；DB init/diagnostic failure 不终止 background isolate。
- [x] NativeEventStore 在 transfer_lock=1 或 active_brain=0 时不写 perception/device event。
- [x] 横竖屏/显示尺寸变化时悬浮球坐标重新夹回屏幕边界；用户拖动后的吸边位置持久化。
- [x] Nearby process singleton 支持多个 engine listener；一个 UI engine dispose 不会清空其他 engine listener。
- [x] Nearby incoming FILE transport-level 512 MiB cap + cancelPayload 路径。
- [x] Activity 重建后 TransferPage 从 SQLite active_brain 恢复 standby/manual-takeover UI。
- [x] background/perception/memory async diagnostic 路径均受 brainWorkAllowed guard。
- [x] v0.11 重复 Payload.Type.BYTES 分支已移除。
- [x] notification disabled 时不丢 SQLite 主动消息。
- [x] Transitional OverlayChatActivity 根 route 的关闭键使用 SystemNavigator.pop()，不再依赖无 route 可退的 maybePop。
- [x] ChatController late notify 有 dispose guard；ChatPage async 初始化/post-frame 滚动有 mounted guard。
- [x] schema 仍为 v10，无数据库迁移。
- [x] v0.11 -> v0.12 TTS 41 个关键文件：39 个 hash 不变，2 个有意修改（NativeTtsBridge lifecycle cleanup + NativeTtsEngine native-runtime serialization），0 缺失。
- [ ] Flutter analyzer / Gradle build：当前环境无 Flutter/Android SDK，不声称通过。
- [ ] 真机：系统杀进程后 START_STICKY 恢复。
- [ ] 真机：开机 / app update 后 user-enabled companion 恢复。
- [ ] 真机：悬浮权限运行中撤销后 service 退出，再授权回 App 后 reconcile。
- [ ] 真机：通知访问被系统断开后 rebind。
- [ ] 真机：Accessibility 开关/interrupt/reconnect。
- [ ] 真机：锁屏/解锁感知事件。
- [ ] 真机：OEM aggressive background killer。
- [ ] 已知缺口：expanded chat 当前仍为 translucent Activity，不作为 true overlay 通过项。
- [ ] 已知缺口：当前 chat Activity 自己拥有 FlutterEngine；若 host 在流式生成中被真正 destroy，本轮 Dart 生成可被中断。v0.13 先通过 service-owned overlay engine 解决悬浮聊天侧。
- [ ] 长期容量：数百 MiB 级 state.json 仍是整块内存解析，后续需 streaming/table-split 或 SQLite backup。


## K. v0.13 True Overlay Chat

- [x] `OverlayChatActivity.kt` 已删除，Manifest 不再声明过渡 Activity。
- [x] 展开聊天使用 `TYPE_APPLICATION_OVERLAY` WindowManager window。
- [x] 服务代码不直接 host/import FlutterView；AI 逻辑复用 persistent background FlutterEngine。
- [x] read mode 为 non-focusable，输入时临时 focusable，Back/outside touch 恢复 read mode。
- [x] notification tap 走 OverlayBubbleService，不走 `PendingIntent.getActivity`。
- [x] 收起 panel 不销毁 background FlutterEngine。
- [x] native overlay 可读取近期消息并分页加载更早消息。
- [x] native overlay 发送仍调用 Dart ChatController 主链路。
- [x] native overlay 支持 reasoning 查看、TTS replay/stop。
- [x] full App resumed 时收起 expanded overlay。
- [x] full ChatPage 在 resumed + 非本地 sending 时同步 background-engine SQLite 新消息。
- [x] v0.12 `insertMemory` 重复局部变量已修。
- [x] 旧 `/overlay-chat` / overlayMode / SystemNavigator 过渡 Dart 代码已移除。
- [x] schema 仍为 v10，无迁移。
- [x] v0.12 TTS 41 个关键 baseline 文件：0 changed / 0 missing。
- [ ] 真机：QQ/游戏在 overlay read mode 下是否保持前台且不 pause。
- [ ] 真机：点击输入框后 IME 是否稳定弹出；Back/外部点击是否顺滑归还焦点。
- [ ] 真机：手机/平板不同尺寸的 overlay 大小与拖动手感。
- [ ] 真机：OEM 对 TYPE_APPLICATION_OVERLAY/前台服务的额外限制。


## L. v0.14 Durable Chat Recovery

- [x] 用户 message + generation job SQLite transaction 原子性模拟。
- [x] assistant + generation completed + post-turn job transaction 原子性模拟。
- [x] stale run token 无法 checkpoint/fail/commit 新 attempt。
- [x] stream 无 terminal signal 不提交 partial assistant。
- [x] 缺少目标设备 API Key 时 defer 且不消耗 attempt。
- [x] API 设置保存后 retryable generation 可立即唤醒。
- [x] recoverable 网络错误长期 retry，退避上限小时级。
- [x] transfer imported running job -> pending，来源 run token 清空。
- [x] 41 个 TTS critical files 对 v0.13 hash 回归。
- [ ] 真机：流式回复期间强杀进程，重启后自动恢复并最终只出现一条 assistant。
- [ ] 真机：旧 Engine/进程冻结恢复的 OEM 极端场景。
- [ ] 真机：手机未完成 turn 转到平板，在新设备配置 API Key 后恢复。

## v0.15 Async Worker Ownership
- [ ] stale post-turn job is reclaimed with a different run token
- [ ] old run token cannot checkpoint/fail/complete the reclaimed job
- [ ] cached post-turn proposal survives retry_wait
- [ ] post-turn Desire pulse is not replayed after reclaim
- [ ] relationship event internalizes once
- [ ] deferred follow-up stale claim cannot seed after reclaim
- [ ] conversation summary range cannot duplicate
- [ ] transfer waits for all writer leases including conversation summary

## v0.18 Companion Home / Relationship Presence

- [x] 日常底栏只保留 `她 / 聊天 / 更多`，Inner/System/Transfer 不再和聊天同级。
- [x] Home 读取真实 SQLite Active Brain / transfer lock，不建立独立 UI 状态源。
- [x] Active Brain、standby、transfer 三种存在状态文案互斥且 transfer 优先。
- [x] standby 明确说明本机可能只是上次同步状态，不冒充实时第二个 AI。
- [x] Home 打开/刷新不执行 Desire tick、self-drive、perception capture 或 proactive evaluate。
- [x] Home Thought 取最近 active/fixation，排除 residual 与 snoozed，不按强度 HUD 排序。
- [x] Home 不显示 Drive、baseline、strength、busyScore 等工程数值。
- [x] 最近主动消息直接读取持久 message metadata，点击回到同一个完整 Chat。
- [x] 未完成话题只作为继续聊天入口，不在主页自动改写/退休 thread。
- [x] Home 只显示 perception 更新时间，不显示 package/notification/accessibility 原始文字。
- [x] Chat 顶栏移除模型下拉；模型与 reasoning effort 仍由 Settings 持久配置。
- [x] `reasoning_content` 的存储/显示链保留，`ReasoningPanel` 未删除。
- [x] `更多` 保留 Relationship / Memory / Reference / Transfer / System / Settings。
- [x] Inner 数值调试入口保留在 `高级与诊断`。
- [x] schema 仍为 v13，无迁移。
- [x] v0.17 baseline 外 199 个冻结文件逐字节一致。
- [x] v0.17 TTS 41 个关键文件 SHA-256：0 changed / 0 missing。
- [x] proactive / durable generation / async ownership / recovery SQLite 回归脚本通过。
- [ ] Flutter analyzer / widget tests / Gradle build：当前环境无 Flutter/Android SDK，不声称通过。
- [ ] 真机：Home 在后台主动消息后恢复前台时刷新正确。
- [ ] 真机：手机→平板接管后旧设备 Home 立即显示 standby，新设备显示 Active Brain。
- [ ] 真机：不同屏幕尺寸下 Home/More/Chat 底栏与系统手势区布局。

## v0.19 Reference Library / Companion Surface Consistency

- [x] Reference 列表支持按名称/别名本地搜索。
- [x] 新增资料保存完整原文，并生成 deterministic 检索片段。
- [x] 详情页可查看完整原文与派生检索片段。
- [x] 编辑完整资料后重新分块；Document id 保持不变。
- [x] 编辑现有 Document 使用 UPDATE，不通过 SQLite REPLACE 重置 created_at。
- [x] 单独“重新分块”不会修改 raw_content。
- [x] disabled Document 重新分块后新 chunks 仍为 disabled。
- [x] enable/disable 同步 Document 与所有 chunks。
- [x] 删除前二次确认；确认后 document + chunks 一起删除。
- [x] PromptBuilder 继续只取 `referenceLibrary.retrieve(latestUserText, limit: 6)`，没有全量常驻 Reference。
- [x] Home 日常文案不再解释 `Active Brain / 大脑写入`。
- [x] More 的 Reference/设备接管说明改成普通关系语言。
- [x] full Chat / true overlay 的“她正在想…”与恢复提示统一。
- [x] full Chat / overlay proactive label 统一；overlay 补齐 gentle_ping。
- [x] true overlay avatar/title 改为 `她`，`App` 按钮改为 `打开`。
- [x] schema 仍为 v13，无迁移。
- [x] Reference SQLite 一致性专项模拟通过。
- [x] proactive / durable generation / async ownership / recovery / Companion Home 回归脚本通过。
- [x] v0.18 baseline 外冻结文件逐字节一致。
- [x] v0.18 TTS 41 个关键文件 SHA-256：0 changed / 0 missing。
- [ ] Flutter analyzer / widget tests / Gradle build：当前环境无 Flutter/Android SDK，不声称通过。
- [ ] 真机：超长 Reference 原文编辑时 IME、滚动、返回键体验。
- [ ] 真机：true overlay 中文按钮在不同 DPI/字体缩放下不拥挤。

## v0.20 Perception Context / Daily Awareness

- [x] schema v13 -> v14 新增 `awareness_observations`，旧核心数据表不做破坏性重写。
- [x] observation 保存 kind/summary/confidence/window/expiry/dedupe/source fingerprint。
- [x] 相同 dedupe key 更新同一行并保留 id/created_at，不重复堆积当前状态。
- [x] managed signal 消失后旧 observation 立即过期。
- [x] expired / confidence < 0.45 observation 不进入 active awareness 查询。
- [x] PromptBuilder 最多读取 6 条 active awareness。
- [x] 普通 Prompt 不再读取 raw `device_events`。
- [x] 普通 Prompt 不再直接读取 `perception_snapshots`。
- [x] 新 perception snapshot 不再持久化 foreground package (`current_package=null`)。
- [x] Accessibility 原文不再生成 durable Thought。
- [x] Notification/Accessibility raw text 不进入 awareness summary；只允许使用粗粒度计数。
- [x] Android full/background bridge 均提供 `getPerceptionState()`。
- [x] usage event 提供本地粗粒度 app category；relationship-facing summary 不含 package name。
- [x] screen-off / current activity / recent activity / app switching / notification pressure / availability 均有 expiry 语义。
- [x] perception transaction 内再次检查 `active_brain/transfer_lock`。
- [x] Thought/Desire integration 前再次检查 Active Brain，接管窗口旧设备不继续成长。
- [x] imported source-device current awareness 最长 12 分钟 grace。
- [x] proactive busy 继续为 soft gate，并可复用最近 15 分钟 perception busy score。
- [x] awareness 长期卫生：14 天 age cap + 600 rows cap。
- [x] awareness SQLite migration/dedupe/expiry/Active-Brain 专项模拟通过。
- [x] proactive / durable generation / async ownership / recovery / Reference / Companion Home SQL 回归通过。
- [x] v0.19 baseline 外冻结旧文件逐字节一致。
- [x] v0.19 TTS 41 个关键文件 SHA-256：0 changed / 0 missing。
- [ ] Flutter analyzer / Dart tests / Gradle build：当前环境无 Flutter/Android SDK，不声称通过。
- [ ] 真机：UsageStats/系统 app category 在目标手机与平板上分类合理。
- [ ] 真机：screen-off / unlock / app-switching awareness 的实际时间感自然。
- [ ] 真机：通知/Accessibility 权限开启关闭后 connection state 与 awareness 过期行为正确。
- [ ] 真机：感知信息不会让聊天出现“监控报告”口吻。
- [ ] 真机：手机→平板接管后旧手机 awareness 不继续写入，新平板快速形成自己的当前状态。

## v0.21 Relationship / Inner-state Companion Presentation

- [x] `RelationshipPresentation` 只投影现有 Relationship/Thought 真值源，不新增 love meter/关系等级。
- [x] companion-facing Thought SQL 在 LIMIT 前排除 residual / acted / dormant / snoozed。
- [x] perception/awareness Thought 明确排除在日常关系 care 之外。
- [x] self-reflection maintenance Thought 不进入日常关系 care。
- [x] snoozed / dormant / non-driving Thought 不进入日常关系 care。
- [x] topic_key 相同的 care 只展示一次。
- [x] 内部 Thought 机械前缀只在展示层清理，不改 SQLite 原文。
- [x] 日常 `你们之间` 页面分离 current cares / 临时 Session / unfinished threads / shared moments。
- [x] RelationshipEvent 日常展示不含 intensity / valence 数值。
- [x] raw RelationshipEvent intensity/valence 保留在 Advanced/Diagnostics。
- [x] standby / transfer 设备明确说明当前 Thought/Session 可能只是上次同步状态。
- [x] Companion Home 使用过滤后的 current care，不再直接展示任意 latest Thought。
- [x] Home 增加最近 shared RelationshipEvent 摘要入口。
- [x] Home current care 与 unfinished thread 同 topic 时不重复显示同一件事。
- [x] Home recent RelationshipMoment 与 current care 同文时跳过，避免连续重复展示。
- [x] More 的日常入口改名 `你们之间`。
- [x] schema 仍为 v14，无迁移。
- [x] proactive / durable generation / async ownership / recovery / Reference / Companion Home / awareness SQL 回归通过。
- [x] v0.20 baseline 外未授权旧文件逐字节一致。
- [x] v0.20 TTS 41 个关键文件 SHA-256：0 changed / 0 missing。
- [ ] Flutter analyzer / Dart tests / Gradle build：当前环境无 Flutter/Android SDK，不声称通过。
- [ ] 真机：小屏/大字体下 current care / timeline 不溢出。
- [ ] 真机：手机被平板接管后 `你们之间` 立即表现为上次同步状态，新设备表现为实时状态。
- [ ] 长期真实使用：关系主题筛选是否自然，是否出现“重要但不展示”或“重复念叨”的主观问题。

## v0.22 Long-term Memory Consolidation / Conflict Semantics

- [x] schema v14 -> v15 additive migration；旧 `memory_items`、聊天、Relationship、Thought 等不做破坏性重写。
- [x] `memory_items` 新增 semantic_type / evidence_count / first_observed_at / last_evidence_at / fact_version。
- [x] 新增 `memory_evidence`，并以 `(memory_id, source, evidence_text)` 唯一约束阻止 durable retry 重复强化。
- [x] 旧 shared_experience 迁移为 shared_experience semantic；其他旧记忆安全默认 current_fact。
- [x] current_fact 同 subject 明确变化时旧版本变为 superseded，新版本 `fact_version + 1`。
- [x] superseded 当前事实仍留在 SQLite，并通过 `superseded_by` 指向新版本。
- [x] confidence < 0.68 的自动 current proposal 降为 inference，不得覆盖 current fact。
- [x] inference 与 current fact 分层；后来明确确认可结束旧 inference 并建立 current fact。
- [x] shared_experience 不参与 current profile replacement。
- [x] 同 subject pinned 条目阻止自动 replacement。
- [x] extractor 只读取 bounded related-memory candidates，不全量读取记忆库。
- [x] extractor 支持 append / reinforce / replace + target_id。
- [x] reinforce 保留 canonical memory，并把新说法写入 memory_evidence。
- [x] 错误 reinforce target 需要 kind + subject/本地文本相似度兼容，避免任意 UUID 误强化。
- [x] AI Self reflection 使用相同 append/reinforce/replace 与 pinned 语义。
- [x] stable user / preference / AI Self 普通检索只取 current_fact。
- [x] relevant inference 最多 3 条，并明确标注“可能不准确”。
- [x] relevant historical current fact 最多 3 条，并明确标注“不能当成当前事实”。
- [x] shared experience 明确标注为发生过的事件，不等同当前偏好。
- [x] self-drive 排除 inference，不把猜测转成确定口吻的长期 Thought。
- [x] repeated evidence 提升 retention；inference 使用更快 fading / 更短自动归档门槛。
- [x] 本地记忆库显示 current/inference/history/shared semantic、版本、证据次数及最近证据。
- [x] 手动恢复归档 current fact 时，同 kind + subject 已有 active current fact 会被阻止，避免人为制造双当前版本。
- [x] 手动修改 active current fact 的 subject_key 时同样执行唯一 current guard。
- [x] v14 迁移来的旧记忆若尚无 evidence 行，首次手动改正文前先把旧正文落入 `manual_edit_previous` 证据链。
- [x] `memory_evidence` 纳入 export/import；v14 状态包导入 v15 自动补默认字段。
- [x] repeated full-state import 对 memory + evidence 保持 idempotent。
- [x] v0.22 Memory SQLite 专项模拟通过。
- [x] proactive / durable generation / async ownership / recovery / Reference / Companion Home / awareness / relationship SQL 回归通过。
- [x] v0.21 baseline 外未授权旧文件逐字节一致。
- [x] v0.21 TTS 41 个关键文件 SHA-256：0 changed / 0 missing。
- [ ] Flutter analyzer / Dart tests / Gradle build：当前环境无 Flutter/Android SDK，不声称通过。
- [ ] 长期真实使用：数月后 subject_key/action 分类是否仍自然，需要真实聊天数据观察。
- [ ] 真机：本地记忆证据展开在小屏/大字体下的滚动与 IME 体验。


## v0.23 Proactive Rhythm Learning / Local Feedback

- [x] schema v15 -> v16 additive migration；旧主动反馈与其他核心数据不破坏。
- [x] proactive feedback 保存 coarse hour bucket / activity context / busy score。
- [x] raw package / notification / Accessibility text 不进入 rhythm-learning row。
- [x] timing_fit 与 topic_fit 分离。
- [x] no_response = 弱 timing evidence，不是 topic rejection。
- [x] deferred 主要影响 timing；dismissed/redirected 主要影响 topic。
- [x] neutral prior + bounded samples 防止少量反馈过拟合。
- [x] 45 天 half-life 让旧习惯逐渐失效。
- [x] hour/activity/topic/intent adjustment 分别 clamp，最终 threshold adjustment 再 clamp。
- [x] proactive adaptation 关闭后仍绑定用户回复并继续 Thought/thread outcome 语义。
- [x] busy 仍为 soft gate。
- [x] 长时间安静后有 bounded recovery relief，避免被历史 no-response 永久训练沉默。
- [x] 2 小时最多 2 次、24 小时最多 8 次主动发送的 hard spam ceiling。
- [x] v16 feedback 随 full-state snapshot 手机/平板迁移。
- [x] v0.23 deterministic SQLite/simulation 专项通过。
- [ ] Flutter analyzer / Dart tests / Gradle build：当前环境无 Flutter/Android SDK，不声称通过。
- [ ] 真机：不同 Android/OEM 后台心跳实际频率下，hard ceiling 与 quiet delivery 行为自然。
- [ ] 长期真实使用：数周反馈后 daypart/activity 学习是否符合主观感受，且没有“越来越不主动”。

- [x] v0.22 baseline 外 229 个未授权旧文件逐字节一致。
- [x] v0.22 TTS 41 个关键文件 SHA-256：0 changed / 0 missing。
- [x] anti-silence threshold recovery 与 2h/24h hard spam ceilings 确定性模拟通过。

## v0.24 Companion Continuity / Daily Reflection

- [x] schema v16 -> v17 additive migration；新增 `daily_continuity`，旧核心表不重写。
- [x] 一个 local day 只有一个 UNIQUE continuity row，重复运行保持 exactly-once。
- [x] 当天记录允许真实状态变化后更新；昨天固化后晚到 retry 不再改写。
- [x] continuity 最终写事务内再次检查 Active Brain / transfer lock。
- [x] 来源只使用 RelationshipEvent / unfinished thread / companion-facing Thought / coarse Awareness / actual message activity。
- [x] 不调用模型生成 daily diary；AI Self reflection 与 shared continuity 保持独立。
- [x] unresolved thread 前两天已展示且无新更新时不会连续每天重复。
- [x] thread 当天真的更新后允许重新进入 continuity。
- [x] quiet day 明确不表示 relationship regression；普通聊天不硬凑 milestone。
- [x] Prompt 最多读取最近 2 条 continuity；明确“不是新事实来源 / 不是 AI 日记 / 不逐条复述”。
- [x] post-turn extractor 防止仅因 AI 复述旧 continuity 而递归生成 memory / relationship_event / thread。
- [x] post-turn + heartbeat 刷新复用现有 durable scheduling，不新增 Android scheduler。
- [x] continuity 刷新失败不会阻断 proactive heartbeat / Memory Maintenance / AI Self reflection。
- [x] `daily_continuity` 纳入 full-state phone/tablet export/import；v16 包导入 v17 兼容。
- [x] long-running maintenance 将 continuity 限制在约 180 天 / 最多 220 条。
- [x] Home 显示轻量 recent continuity；standby 不冒充 live 状态。
- [x] `你们之间`显示“最近几天”，不暴露工程数值，也不做每日强制日记。
- [x] v0.24 Daily Continuity SQLite 专项模拟通过。
- [x] v0.23 proactive rhythm / v0.22 memory / Awareness / Relationship / Reference / Home / durable generation / async ownership / Recovery 全部回归通过。
- [x] v0.23 baseline 外 231 个未授权旧文件逐字节一致。
- [x] v0.23 TTS 41 个关键文件 SHA-256：0 changed / 0 missing。
- [ ] Flutter analyzer / Dart tests / Gradle build：当前环境无 Flutter/Android SDK，不声称通过。
- [ ] 真机：Home / `最近几天` 在手机和平板不同字号下的实际布局体验。


## v0.25 Native TTS Core Integration

- [x] 黄金 APK SHA-256 固定为 `63a8c10f...c58c5e7`。
- [x] 22 个 tts_models 文件与黄金 APK byte-identical。
- [x] 6 个核心 arm64 `.so` 与黄金 APK byte-identical。
- [x] runtime JAR 的 9 个 classes.dex 与黄金 APK 9/9 一致。
- [x] runtime_01 pinyin/NLP classpath 资源与黄金 APK 一致。
- [x] AI Companion 不包含 HTML/JS 文件，TTS 无 WebView bridge 依赖。
- [x] 初始化前 37 项黄金 SHA-256/size 校验 fail-closed。
- [x] 私有 runtime cache 旧/坏副本会按指纹替换并只读加载。
- [x] Dart queue 测试源覆盖 FIFO / stop 取消未开始句 / 单句失败不中毒后续。
- [x] reasoning_content 不进入 TTS delta。
- [x] `Yuki -> 有希` 仍只修改朗读文本。
- [x] TTS diagnostic SQLite 写失败不能上抛破坏 durable chat/proactive。
- [x] 核心 Kotlin TTS 文件通过 stub `kotlinc` 编译。
- [ ] 真机 JNI/MNN 初始化与实际发声（首次必要 APK checkpoint）。
- [ ] 音色/读音与黄金 APK 主观一致（用户真机听感）。
- [ ] 首句延迟、长文本、后台/耳机/来电 AudioTrack 行为（用户真机）。

## v0.26 Phone↔Tablet Sync Integrity / Transfer Hardening

- [x] schema v17 -> v18 additive migration；新增 local-only `transfer_receipts`。
- [x] state lineage + monotonic ownership generation + snapshot_id identity。
- [x] snapshot manifest/state/settings 三层身份一致性校验。
- [x] state SHA-256 / declared byte length 校验；损坏或截断拒绝。
- [x] same-lineage stale generation 拒绝覆盖新状态。
- [x] exact duplicate delivery 根据 local receipt no-op；snapshot-id collision 拒绝。
- [x] imported DB + transfer receipt 同 SQLite transaction；故意异常模拟整体 rollback。
- [x] Nearby takeover request/ACK 使用 bound v3 metadata，不再接受固定 V2 token。
- [x] source 原生 transaction 核对 exact snapshot generation 后先 fence，再 ACK。
- [x] target 收到 exact ACK 后才 active；activation generation+1 使已消费包立即 stale。
- [x] ACK 丢失/迟到/错会话保持 fail-safe，不产生双 Active Brain。
- [x] standby 源设备保留全部本地数据。
- [x] 手动 `.aicomp` 使用 PBKDF2-HMAC-SHA256 + AES-256-GCM；wrong-pass / truncation 检测通过。
- [x] 手动导出后源 standby；目标导入后仍 standby，需明确接管。
- [x] standby 停 overlay 不擦除 user preference；overlay/background-brain restoration 受 Active Brain gate。
- [x] transfer/manual/native Kotlin 关键源通过 API stub `kotlinc` 编译。
- [x] v0.25 TTS 37 项 golden model/runtime/native payload byte-identical。
- [ ] Flutter analyzer / Gradle build：当前环境无 Flutter/Android SDK，不声称通过。
- [ ] 双真机 Nearby discovery / verification code / payload transfer / bound takeover。
- [ ] 双真机断网、进程被杀、ACK 延迟/丢失时实际恢复体验。
- [ ] Android SAF 手动加密包在不同厂商文件管理器上的保存/打开。
- [ ] 手机↔平板反复顶号后 overlay preference、通知、后台行为符合预期。


## v0.27 · Real-device Readiness / Preflight Diagnostics

- [x] Quick preflight reads build/runtime/schema/ownership/permission/Nearby/audio/TTS state without model calls.
- [x] Deep preflight verifies 37 TTS golden payloads and initializes JNI/MNN without calling speak/preview.
- [x] Diagnostic report contains no chat/reasoning/Memory/Relationship/Thought/Reference/Daily Continuity plaintext or secure key.
- [x] Full ownership/session identifiers are replaced with short SHA-256 fingerprints.
- [x] Native diagnostic ring is bounded to 160 rows / 30 days and excludes endpoint discovery churn.
- [x] Nearby discovery/connection/transfer/takeover phase outcomes persist only redacted metadata.
- [x] TTS verify/init/inference-failure phases persist without spoken text.
- [x] Android SAF exports a local redacted `.txt`; no cloud telemetry dependency added.
- [x] transfer_lock/pending import/pending outbound/standby states appear in preflight but are not auto-mutated.
- [x] Native redaction JVM test and NativePreflightProbe Kotlin stub compile pass.
- [x] v0.14-v0.26 SQLite/Kotlin/TTS regression chains rerun.