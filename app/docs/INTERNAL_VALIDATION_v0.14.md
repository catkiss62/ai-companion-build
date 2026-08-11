# v0.14 Internal Validation

Environment limitation: Flutter SDK and Android SDK are not installed in the current build environment. These checks are source/static/SQLite/Kotlin-parser-level checks and are **not** represented as a successful APK build.

## Durable-generation checks

- `generation_jobs` schema v11 exists with unique user/assistant IDs.
- User message + durable generation job creation is transactionally atomic.
- Final assistant + post-turn queue + generation completion is transactionally atomic.
- Per-attempt `run_token` fences stale FlutterEngines after lease expiry/reclaim.
- Old run token cannot checkpoint, fail, suspend or commit a newly claimed attempt.
- Running job stale recovery is supported.
- DeepSeek stream must observe terminal completion signal before final commit.
- Partial reasoning/content remain diagnostic checkpoints only.
- Device-local missing API key defers without consuming an attempt.
- Saving API configuration wakes retryable jobs.
- Recoverable failures use long-lived backoff instead of becoming a conversation hole after a few network retries.
- Active Brain / transfer guards are checked before claim and before commit.
- Imported running jobs become pending and clear source run ownership.
- Proactive work is suppressed while a generation obligation is blocking.

`tools/validate_durable_generation_sql.py` exercises the atomicity and stale-attempt ownership model against real SQLite semantics.

## Cross-version / package checks

- schema v10 -> v11 creation path inspected and simulated.
- v0.13 TTS baseline comparison: all 41 critical Bert-VITS2/MNN/native/runtime files unchanged.
- Android XML parses.
- relative Dart imports resolve.
- Dart/Kotlin delimiter scanner passes.
- accidental adjacent duplicate Dart declarations check passes.
- v0.13 true-overlay architecture checks remain passing.
- unsupported non-http(s) API endpoint schemes are rejected.
- Kotlin compiler was run without Android classpath; expected Android/Flutter unresolved references occur, while no parser-level `expecting`/redeclaration syntax errors were found.

## Audit defects fixed while implementing v0.14

1. Legacy `importAll()` contained an accidental duplicated `row.addAll({` block from an earlier edit. This was a real compile-level defect and was removed.
2. A simple job-ID-only recovery design was insufficient if an old engine froze beyond lease TTL and later resumed. Per-attempt `run_token` ownership was added before release.
3. A stream that ended without `[DONE]` could otherwise have committed whatever partial text happened to arrive. Terminal-signal validation now prevents that.
4. A transferred job on a device without its local API key would otherwise consume/fail attempts. Missing credentials now defer before claim.
5. Retry count was initially too short for a durable local-first conversation. Recoverable errors now use durable bounded-backoff retries; non-recoverable protocol errors remain terminal.
6. API endpoint validation previously accepted any URI scheme despite its UI claiming http(s). It now accepts only http/https.
