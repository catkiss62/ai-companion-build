# Roadmap after v0.29.0

## 当前顺序

1. 真机验证 A2 TTS：长文本、句间停顿、停止/重播。
2. GitHub clean baseline 从 `app/` 直接构建成功后清理旧五分包/patch。
3. UI/悬浮窗：角标层级、悬浮球缩小、reasoning 在正文上方、悬浮窗最近聊天记录。
4. 主动感知/联系真机调优：Usage / Notification / Accessibility -> Thought/Desire -> 合理触发。
5. 长期记忆压力测试与强杀/重启/升级恢复。
6. 手机↔平板 Active Brain / Nearby 真机接管。

---

# Roadmap after v0.28.5

## v0.28.5 checkpoint order

先完成 TTS `initialize → generateTTS → WAV → AudioTrack` 真机验收并冻结首个可用运行基底；随后进入已记录的 UI/悬浮窗优化，再做 Android 15/HyperOS 主动感知触发、长期记忆压力、后台恢复和手机↔平板 Active Brain 接管。


## Immediate checkpoint
First confirm the two real-device blockers fixed in v0.28.4: release-packaged Meju native fingerprints and chat initialization. Use the new API probe to separate DeepSeek connectivity from local maintenance/UI issues. After TTS + chat both pass, freeze the runtime baseline and move UI polish into a dedicated stage rather than mixing it with core debugging.

---


## Current checkpoint

v0.12–v0.27 established the durable/local-first companion architecture, long-term relationship memory, proactive behavior, Android awareness, verified MejuTTS core, single-Active-Brain phone↔tablet transfer and local redacted diagnostics.

v0.28 added the **first real-device checkpoint harness**. The first real Android 15 APK then exposed a pre-first-frame black-screen stall because v0.28 awaited SQLite readiness before `runApp()`. v0.28.1 made startup failures visible. The first visible failure was Android sqflite rejecting `PRAGMA journal_mode = WAL` through `execute()`. v0.28.2 fixes the Android database-open path without changing schema or companion semantics.

## Immediate next action

Build the v0.28.2 SQLite-recovery APK and confirm database open, device identity and main-shell entry on the real Android 15 phone. If startup succeeds, continue the original hardware checkpoint in order:

1. quick preflight;
2. deep MejuTTS/JNI initialization;
3. actual TTS voice and `Yuki -> 有希` pronunciation;
4. permissions/perception;
5. overlay/background/notification behavior.

Only after those pass, install the same checkpoint on the tablet and validate Nearby transfer + game-account-style takeover, including interruption/late-ACK behavior.

Any failed item should export the local redacted diagnostic report before code changes are attempted.

## After the first hardware checkpoint

Prioritize fixes found by real hardware/OEM behavior. Do not resume feature expansion until TTS, lifecycle, perception and ownership transfer are stable enough to trust. Once that checkpoint is clean, continue with experience/UI refinement and longer-running soak tests rather than adding new core architecture.

## Later scale milestone

Before multi-year databases approach hundreds of MB, measure whole-state transfer peak memory. If needed, replace JSON whole-state snapshots with table streaming or SQLite backup/snapshot transport while preserving the same lineage/generation ownership protocol. Only consider embeddings/vector indexing if bounded local lexical retrieval becomes measurably insufficient.