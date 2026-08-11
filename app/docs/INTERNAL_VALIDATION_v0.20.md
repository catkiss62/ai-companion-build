# v0.20 Internal Validation

## Scope

v0.20 is constrained to the Perception Context / Daily Awareness layer plus the schema-14 migration required to persist it.

It deliberately does not redesign Memory, Relationship, Desire/Thought lifecycle, Reference retrieval, Durable Generation, Recovery, Nearby takeover or TTS.

## Static source validation

`tools/validate_v020.py --baseline-zip <verified-v0.19-source.zip>` checks:

- Android XML parseability and required receiver/overlay structure;
- Dart relative imports;
- Dart/Kotlin delimiter balance;
- adjacent duplicate Dart declarations;
- app version `0.20.0+20` and schema 14;
- proactive intent/presentation + notification quick-reply regression;
- Companion Home and v0.19 Reference Library contracts;
- awareness model/interpreter/persistence contracts;
- PromptBuilder uses only `activeAwarenessObservations(limit: 6)` and no raw device-event/perception sections;
- PerceptionEngine no longer contains Accessibility raw-text Thought path;
- full/background Android bridges expose perception state and local app category;
- proactive gate reuses bounded busy score;
- awareness participates in long-running hygiene;
- true overlay regression guard;
- all v0.19 files outside the explicit v0.20 allowlist remain byte-identical;
- all 41 TTS critical files remain byte-identical to v0.19.

## SQLite awareness simulation

`tools/validate_awareness_sql.py` verifies:

1. v14 awareness schema/columns;
2. same semantic dedupe key updates one row while preserving id/created_at;
3. managed observation disappearance expires the old row;
4. Active Brain standby blocks awareness writes;
5. transfer lock blocks awareness writes;
6. expired and low-confidence rows are excluded from active prompt candidates;
7. imported source-device awareness receives the takeover grace expiry cap.

## Existing regression suite

The following simulations are rerun after v0.20 changes:

- `validate_proactive_intent_sql.py`;
- `validate_durable_generation_sql.py`;
- `validate_async_worker_sql.py`;
- `validate_recovery_orchestration_sql.py`;
- `validate_reference_library_sql.py`;
- `validate_companion_home_sql.py`.

This protects proactive intent metadata, durable chat atomicity/run-token fencing, async exactly-once ownership, recovery boundaries, Reference consistency and Home read semantics.

## Dart test sources

Additional tests are provided for environments with Flutter/Dart tooling:

- awareness DB-model decode;
- sustained game usage -> coarse human-level observation;
- screen-off observation confidence/TTL;
- raw notification/accessibility text cannot appear in interpreted summaries.

They are included in source but are **not claimed as executed here**, because this environment has no Dart/Flutter SDK.

## Not claimed in this environment

v0.20 does not claim:

- `flutter analyze` passed;
- Dart/widget tests executed;
- Gradle/Android compilation passed;
- UsageStats category values verified across OEMs;
- NotificationListener/Accessibility connection state verified on hardware;
- real screen-off timing/awareness language validated by the user;
- battery/background behavior validated.

Those remain for the established real-device checkpoint rather than generating an APK for every source-only milestone.
