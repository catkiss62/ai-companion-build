# v0.21 Internal Validation

## Scope

v0.21 is constrained to partner-facing Relationship/Thought presentation plus diagnostics relocation. It does not redesign Relationship assimilation, Memory, Desire lifecycle, proactive contact, perception, Active Brain takeover, Durable Generation, Recovery, Reference or TTS.

## Static validation

`tools/validate_v021.py --baseline-zip <verified-v0.20-source.zip>` checks:

- Android XML / Manifest integrity;
- Dart relative imports and Dart/Kotlin delimiter balance;
- version `0.21.0+21`, schema still 14;
- v0.17 proactive/notification quick-reply regression guards;
- v0.19 Reference Library regression guards;
- v0.20 Perception Context regression guards;
- Home uses filtered companion-facing cares + one shared relationship moment;
- daily Relationship page contains no numeric `intensity`/`valence` display;
- perception/awareness Thoughts are explicitly excluded from relationship-facing care projection;
- snoozed/non-driving Thoughts cannot enter the daily relationship projection;
- the SQLite companion-facing Thought read model excludes residual/acted/dormant/snoozed rows before the bounded LIMIT;
- standby/transfer relationship copy cannot pretend stale current state is live;
- raw relationship event numbers remain only under Advanced/Diagnostics;
- all v0.20 files outside the explicit v0.21 allowlist remain byte-identical;
- all 41 TTS critical files remain byte-identical to v0.20.

## Existing regression suite

The following source-independent SQLite simulations are rerun:

- `validate_proactive_intent_sql.py`;
- `validate_durable_generation_sql.py`;
- `validate_async_worker_sql.py`;
- `validate_recovery_orchestration_sql.py`;
- `validate_reference_library_sql.py`;
- `validate_companion_home_sql.py`;
- `validate_awareness_sql.py`;
- `validate_relationship_presentation_sql.py`.

## Dart test sources

`test/relationship_presentation_v21_test.dart` covers:

- raw perception Thought filtering;
- snoozed/dormant filtering;
- topic-key display dedupe;
- shared-moment label projection without exposing scores.

`test/companion_home_state_test.dart` is also corrected to match the post-v0.18 companion-facing copy rather than expecting leaked `Active Brain` developer wording.

These Dart tests are included but not claimed as executed because the current environment has no Dart/Flutter SDK.

## Not claimed

- Flutter analyzer;
- Dart/widget test execution;
- Gradle/Android compilation;
- real-device visual sizing;
- subjective relationship-language quality after months of real usage.
