# v0.19 Internal Validation

## Scope

v0.19 is deliberately constrained to:

- Reference Library daily UX;
- Reference document/chunk consistency fixes;
- user-facing copy consistency across Home, full Chat, More and true overlay;
- version/docs/tests.

No database migration is introduced. Schema remains 13.

## Static source validation

`tools/validate_v019.py --baseline-zip <verified-v0.18-source.zip>` checks:

- Android XML parseability and required receiver/overlay structure;
- Dart relative imports;
- Dart/Kotlin delimiter balance;
- accidental adjacent duplicate Dart declarations;
- v0.19 version + schema 13;
- proactive intent/presentation and notification quick-reply regression;
- v0.18 Companion Home contract;
- v0.19 Reference list/detail/editor contracts;
- bounded on-demand Reference retrieval (`limit: 6`);
- no `ConflictAlgorithm.replace` in existing-document Reference edit path;
- regenerated chunks inherit owning document enabled state;
- companion-facing copy consistency in Home/Chat/More/overlay;
- true overlay regression guard;
- v0.18 frozen-file byte identity outside the explicit v0.19 allowlist;
- all 41 TTS critical files byte-identical to the verified v0.18 baseline.

## SQLite Reference consistency simulation

`tools/validate_reference_library_sql.py` verifies:

1. a disabled document stays excluded after rechunk;
2. editing preserves `created_at` while changing `updated_at/raw_content`;
3. rechunk does not mutate full raw text;
4. rechunk does not silently re-enable retrieval;
5. re-enable keeps document and chunks synchronized;
6. a simulated failure between Document update and chunk replacement rolls the entire save back;
7. delete removes full document and all derived chunks.

## Regression suite

The major v0.13-v0.18 SQLite/static regressions are also rerun:

- proactive intent migration/presentation persistence;
- durable generation atomicity and stale run-token protection;
- async worker ownership/exactly-once behavior;
- RecoveryOrchestrator recovery boundaries;
- Companion Home read-model semantics.

## Not claimed in this environment

This environment has no Flutter SDK / Android SDK, so v0.19 does **not** claim:

- `flutter analyze` passed;
- widget tests passed;
- Gradle/Android build passed;
- real-device Reference layout/IME behavior passed;
- real-device true-overlay copy/button sizing passed.

Those remain for the established real-device APK checkpoint rather than producing an APK for every source-only milestone.
