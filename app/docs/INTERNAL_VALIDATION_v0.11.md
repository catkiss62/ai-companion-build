# Internal validation · v0.11

This file records source-level checks performed without claiming a Flutter/Gradle Android build.

## Structural

- Dart delimiter/string/comment scan.
- Relative Dart import existence scan.
- YAML parse.
- Android XML parse.
- Kotlin parser pass for modified Nearby source (unresolved Android/Google references are expected outside Android SDK; parser-level syntax diagnostics are checked separately).

## Database

- fresh v10 relevant schema SQL simulation.
- v9 -> v10 migration simulation with existing unfinished-thread data.
- new follow-up defaults and post-turn-job uniqueness.
- maintenance table/index creation.

## Cross-engine audit

The audit intentionally reviews races between the full app, overlay FlutterEngine, background FlutterEngine and Nearby transfer, rather than assuming a single writer.

- owner-token lease release behavior reviewed, including the same-isolate re-acquire/old-finally edge case.
- chat/proactive streaming paths renew their own token periodically; lease renewal refuses a token that no longer owns the database row.
- DeepSeek streaming header/inactivity and non-streaming JSON calls now have bounded 120-second waits.
- Desire read/modify/write moved into SQLite transaction.
- post-turn extraction made durable and background-retryable; the job is persisted before `chat_turn_lease` is released and UI recovery uses a safe drain wrapper.
- chat write lease added across full/overlay engines; proactive final commit atomically re-checks that lease/new user activity before INSERT.
- transfer freezes new work and waits for active state writers on both source export and receiver import.

## Transfer audit

- cross-table snapshot is transactionally consistent.
- receiver keeps local `device_id`.
- receiver restores as standby+transfer-locked in the same SQLite import transaction rather than briefly inheriting source Active Brain.
- two-phase Nearby takeover requires source-side offline action before receiver activation event.
- stale/disconnected snapshots are invalidated.
- ZIP entries are allowlisted, duplicate-rejected and size/hash/schema checked; stream-backed archive input stays open until extraction completes; temporary plaintext files are removed.

## Native TTS regression

The Bert-VITS2/MNN **native/model/runtime subset (32 files)** is byte-identical to v0.10: 0 missing, 0 changed. One Dart TTS orchestration file, `tts_playback_queue.dart`, is intentionally changed so native/MethodChannel stop failures cannot escape as unhandled futures during chat/dispose.

## Database simulations

- v9 -> v10 unfinished-thread migration: PASS.
- `post_turn_jobs.assistant_message_id` uniqueness: PASS.
- deferred follow-up one-shot selection: PASS.
- receiver runtime override model (`local device_id`, standby, transfer lock, cleared leases): PASS.
- atomic proactive commit model: normal insert succeeds; held chat lease and newer user message both block the outbound insert.

## Not claimed here

- `flutter analyze` / `flutter test` execution (Dart/Flutter SDK unavailable in this environment).
- Gradle Android build.
- Android permission/foreground-service behavior on real OEM devices.
- actual native TTS audio.
- real Nearby timing/connection behavior.
