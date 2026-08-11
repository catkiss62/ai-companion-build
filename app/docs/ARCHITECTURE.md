# 架构冻结稿 v0.14

## 1. Reality Identity

AI 基础身份始终是“知道自己是 AI 的长期女性伴侣”。模型可切换，本地连续性不随模型切换丢失。

## 2. Durable Local State

SQLite 真源：

- messages + reasoning_content
- memory_items
- conversation_summaries
- unfinished_threads
- relationship_events
- interaction_sessions
- thoughts / desire_state
- perception_snapshots / device_events
- proactive_history
- settings

## 3. Memory v4

MemoryItem 使用 subject_key / pinned / superseded_by。

普通检索只读 `status=active`。同一稳定事实发生变化时保留旧版本而不是删除。用户 pinned 的事实是本地权威，模型不能自动覆盖。

## 4. Relationship Layer

Relationship Event 记录长期节点；不维护可见好感度等级。

Temporary Session 记录 roleplay/intimacy 场景。Session 是附加互动层，不替换 Reality Identity。

`PromptBuilder` 顺序：

`Identity -> Memory Context -> Relationship Context -> Desire/Thought -> Perception -> recent chat`

## 5. Experience Integrator

一次低成本 Flash JSON 同时提出：

- memories (+ subject_key)
- thoughts
- unfinished_threads
- relationship_events
- session_update
- desire_pulses

模型只提出候选，本地代码限制种类、数量、幅度并负责落库。

## 6. AI Self Isolation

AI Self 低频整理时读取当前 Session，并明确禁止把场景内扮演行为直接沉淀为永久人格。

## 7. Desire / Perception / Proactive

Busy 是软门控，不是禁止主动联系。主动消息先写本地消息历史，再进入 Android 通知/悬浮未读。

## 8. Native TTS + Streaming Voice

Companion Core 只依赖 `TtsProvider` / `TtsService`；来源 APK 的兼容 runtime 不向业务层泄漏类名。

v0.6 在其上增加：

`DeepSeek content delta -> TtsSentenceSegmenter -> TtsPlaybackQueue -> Native TTS`

- reasoning_content 永不进入 TTS。
- Dart queue 管待播句子与 stop generation。
- NativeTtsEngine process-singleton 负责跨 Main / Overlay / Background FlutterEngine 串行访问 Bert-VITS2/MNN。
- Native speechGeneration 防止 stop 后旧推理结果重新播放。

主动语音策略与“是否主动联系”完全分层：Desire/Proactive 先决定她是否发消息，voice policy 再决定消息保持静音、打开悬浮窗再读、还是立即读。

## 9. Cross-device

完整快照包含关系、Session、TTS 行为设置。仍采用单 Active Brain，不做双端同时写入后的自动冲突合并。TTS native 模型是应用资产，不随状态包重复传输。

v0.26 将所有权协议正式绑定到 `state_lineage_id + state_generation + snapshot_id + state_sha256`。每次冻结导出先增加 ownership generation；目标只导入为 standby，并在本地保留不随快照覆盖的 `transfer_receipts`。Nearby takeover request/ACK 必须匹配该 exact snapshot；源端 Native SQLite 事务先 fence，目标收到 matching ACK 后再激活并再次增加 generation，因此已消费包立即 stale。网络结果不明确时宁可两端 standby，也不允许双 Active Brain。

手动 fallback 使用 Android SAF + AES-256-GCM 加密同一 Snapshot v2，不建立第二套状态语义。standby 设备保存本地数据；overlay 用户偏好保持 device-local，但所有持久 overlay/background-brain start path 都受 Active Brain gate。


## 10. Durable Topic Identity / Proactive Outcome

v0.10 使用稳定 `topic_key` 将同一长期主题连接到 Thought、unfinished thread、proactive feedback，以及有意义的 relationship-event metadata。

主动消息收到用户回复后分两步处理：先本地确认消息被回应，再在完整一轮结束后区分 engaged / acknowledged / deferred / resolved / dismissed / redirected。线程状态和 Thought 满足度必须跟该语义结果一致。

长期卫生由 `ThoughtConsolidationEngine` 负责：同 drive + 同 topic 可本地合并；无 topic 时只允许非常高的文本相似度合并。普通聊天的每句话不再自动升级为 Thought。


## v0.11 并发与转移不变量

- 同一时间只有一个 Active Brain；standby 设备只读，不执行自主 Thought/Desire/Memory 写入。
- full app、overlay、background FlutterEngine 视为独立并发 writer，不能依赖单 isolate 内存锁。
- 聊天、主动联系、记忆整理、关系内化、AI Self、长期维护分别使用 SQLite lease/transaction 保护。
- 主动消息最终提交与 `chat_turn_lease` / 最新用户消息 / Active Brain 状态检查原子化。
- 转移先 `transfer_lock=1` 阻止新 writer，再等待已在运行的 writer 退出；源端导出和目标端导入都执行这一原则。
- 目标端导入在同一 transaction 内强制本机 `device_id`、`active_brain=0`、`transfer_lock=1` 并清空运行时 lease，直到旧设备 ACK 后才激活。
- 快照 JSON 是完整状态的短期传输表示，不是长期云端真源。SQLite 仍是设备上的权威持久状态。


## v0.13 Android Lifecycle / True Overlay

- `overlay_user_enabled` is Android device-local runtime intent, not relationship memory and not part of cross-device AI state.
- `OverlayBubbleService` owns the persistent background FlutterEngine and both WindowManager overlay surfaces. The full MainActivity owns its separate rich UI engine.
- Expanded floating chat is a native `TYPE_APPLICATION_OVERLAY` panel, not an Activity and not a service-hosted FlutterView. Native UI calls the service-owned Dart runtime through `ai_companion/background_commands`.
- Read mode is non-focusable; text entry temporarily enables focus/IME, then releases focus after Back/outside touch.
- Collapsing the floating visual surface does not destroy the service-owned Dart chat runtime.
- Full App periodically reconciles SQLite writes produced by the background engine. SQLite remains the cross-engine UI truth.
- NotificationListener/Accessibility real connection state is tracked separately from permission state.
- Native Android device-event callbacks respect `transfer_lock=1` / standby, and Dart background/perception/async-diagnostic paths also call `brainWorkAllowed()`, so snapshot/import freeze covers writers outside the normal feature leases.
- Nearby transport is process-wide but fan-outs events to multiple engine listeners; incoming FILE payloads are size-capped before app-cache copy.


## v0.14 Durable Generation

聊天“欠回复”成为 SQLite 持久任务：用户消息与 generation job 原子创建，DeepSeek 尝试使用独立 run token，最终 assistant + completed + post-turn memory job 原子提交。`chat_turn_lease` 负责正常跨 Engine 串行化，`run_token` 负责防御 lease 过期后旧 Engine 复活的 stale-writer 情况。跨设备 transfer 携带未完成 job，但 receiver 在 Active Brain takeover 完成前不能恢复生成。


## v0.27 Local preflight / diagnostics boundary

Real-device diagnostics are deliberately outside relationship memory. Dart `PreflightDiagnosticsService` reads only non-content SQLite state/counts, `NativePreflightProbe` reads Android runtime prerequisites, and `RuntimeDiagnosticStore` keeps a bounded redacted native phase ring in SharedPreferences. The report never queries relationship/chat/reference plaintext or secure credentials and never uploads anywhere. Ownership IDs are short SHA-256 fingerprints. Deep TTS preflight may verify/init the local runtime but never calls speech generation.
