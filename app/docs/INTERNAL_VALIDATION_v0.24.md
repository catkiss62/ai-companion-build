# Internal validation · v0.24

Validation scope is source/static/SQLite only. The current environment has no Flutter, Dart, Gradle or Android SDK, so this document does not claim APK compilation or real-device scheduling/UI behavior.

## Daily continuity deterministic simulation

`tools/validate_daily_continuity_v17_sql.py` verifies:

- v16 -> v17 additive table contract;
- one UNIQUE row per local day across retries;
- finalized-yesterday immutability;
- Active Brain / transfer-lock write blocking inside the transaction;
- unresolved-thread carry without daily repetition;
- quiet day remains neutral rather than regression;
- phone/tablet state transfer preserves rows;
- retention stays inside the recent bridge boundary.

## Static stage validator

`tools/validate_v024.py` checks:

- Manifest and Dart/Kotlin structural integrity;
- schema v17 / export / import contract;
- local deterministic engine (no model/API path);
- prompt cap of two records and anti-recursion copy;
- post-turn + heartbeat scheduling and failure isolation;
- 180-day / 220-row retention bound;
- Home / `你们之间` presentation and standby wording;
- v0.22 memory semantics, v0.23 proactive rhythm, Reference, Awareness, Relationship and true-overlay regression contracts;
- v0.23 frozen-file comparison;
- all 41 TTS critical files against the v0.23 source baseline.

## Completed regression result

- v0.24 static validator: passed against the v0.23 source baseline.
- 231 v0.23 files outside the v0.24 allowlist: byte-identical.
- 41 critical TTS files: byte-identical / 0 missing.
- v0.24 Daily Continuity SQLite simulation: passed.
- v0.23 proactive rhythm simulation: passed.
- v0.22 long-term memory conflict/evidence simulation: passed.
- Awareness, Relationship Presentation, Reference Library, Companion Home, proactive intent, Durable Generation, async-worker ownership/exactly-once and Recovery Orchestrator simulations: passed.
