# Internal validation · v0.23

Validation scope is source/static/SQLite only. The current environment has no Flutter, Dart, Gradle or Android SDK, so this document does not claim APK compilation or real-device scheduling behavior.

## Deterministic proactive-rhythm simulation

`tools/validate_proactive_rhythm_v16_sql.py` verifies:

- v15 -> v16 additive migration;
- no-response is weak timing evidence and zero topic rejection;
- timing rejection / topic rejection train different dimensions;
- short negative streaks remain bounded;
- repeated ignored messages do not become global topic suppression;
- coarse daypart and activity contexts learn independently;
- evidence fades with a 45-day half-life;
- phone/tablet full-state transfer preserves context and fit signals.

## Stage regression

`tools/validate_v023.py` rechecks Manifest/Dart/Kotlin structure, v0.22 memory semantics, proactive presentation/notification reply, Companion Home, Reference, Awareness, Relationship Presentation and true overlay. With a v0.22 baseline ZIP it also freezes all old files outside the v0.23 allowlist and byte-compares all 41 critical TTS files.


## Completed regression result

- v0.23 static validator: passed against the v0.22 source baseline.
- 229 v0.22 files outside the v0.23 allowlist: byte-identical.
- 41 critical TTS files: byte-identical / 0 missing.
- proactive intent, durable generation, async-worker ownership/exactly-once, recovery orchestration, Reference, Companion Home, Awareness, Relationship Presentation, v0.22 Memory semantics and v0.23 Rhythm simulations: passed.
