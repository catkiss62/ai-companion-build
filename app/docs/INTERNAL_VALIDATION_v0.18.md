# v0.18 Internal Validation

## Scope

v0.18 is an experience-layer milestone. The intended code changes are limited to:

- full-app navigation hierarchy;
- Companion Home read model and UI;
- secondary `更多` hub;
- chat top-bar simplification and navigation wording;
- two read-only database query helpers;
- version/docs/tests.

No schema migration, TTS change, Android lifecycle change, proactive gate change, durable generation change, recovery change or transfer-protocol change is intended.

## Static/source validation

Command:

```bash
python tools/validate_v018.py --baseline-zip <verified-v0.17-source.zip>
```

Result: PASS.

Validated:

- Android XML / Manifest parsing;
- relative Dart imports;
- Dart/Kotlin delimiter structure;
- adjacent duplicate Dart declaration guard;
- package version `0.18.0+18`;
- database schema remains v13;
- v0.17 proactive intent/presentation policy tokens;
- proactive pipeline metadata persistence;
- Android RemoteInput quick-reply routing and stable message-id path;
- full chat / overlay proactive intent labels;
- new `她 / 聊天 / 更多` daily navigation;
- Home read-only data contract;
- no raw Drive/baseline HUD leaked into Home;
- model selector removed from daily chat while `ReasoningPanel` remains;
- true overlay regression tokens remain present.

## v0.17 whole-tree freeze audit

The validator also compares every file that existed in the supplied verified v0.17 source ZIP.

Only the explicit v0.18 allowlist may differ:

- `README.md`
- `docs/DEV_STATUS.md`
- `docs/ROADMAP.md`
- `docs/TEST_CHECKLIST.md`
- `lib/app.dart`
- `lib/core/database/app_database.dart`
- `lib/features/chat/chat_controller.dart`
- `lib/features/chat/chat_page.dart`
- `lib/features/inner/inner_page.dart`
- `pubspec.yaml`

Result:

- **198 baseline files byte-identical outside the allowlist**.

This means Desire, Memory, Relationship, Rule Layers, AI generation, Recovery, Sync/Nearby, Android native code, overlay code, TTS Dart services and other existing feature pages were not accidentally modified.

## TTS baseline verification

The same validation run compares the 41 TTS-critical files against the verified v0.17 source ZIP by SHA-256.

Result:

- **41 checked**
- **0 changed**
- **0 missing**

Unlike an existence-only run, this test had a real v0.17 baseline ZIP.

## Companion Home SQLite semantics

Command:

```bash
python tools/validate_companion_home_sql.py
```

Result: PASS.

Checks:

- latest proactive query returns the newest proactive assistant message even when a newer ordinary user turn exists;
- Home Thought query prefers recency rather than strength;
- residual Thoughts are excluded;
- snoozed active Thoughts are excluded;
- active/fixation state remains eligible.

## Existing SQLite regression suites

Commands:

```bash
python tools/validate_proactive_intent_sql.py
python tools/validate_durable_generation_sql.py
python tools/validate_async_worker_sql.py
python tools/validate_recovery_orchestration_sql.py
```

All PASS.

Covered regressions include:

- v12 -> v13 proactive metadata backfill;
- thread-vs-drive proactive classification precedence;
- intent-history query/index path;
- durable user-message + generation-job ownership/atomicity;
- stale post-turn run-token fencing;
- cached post-turn retry behaviour;
- exactly-once relationship assimilation;
- deferred follow-up ownership fencing;
- optimistic unfinished-thread retirement;
- proactive outcome idempotence;
- conversation-summary range idempotence;
- failed generation attention rules;
- manual generation/post-turn retry respecting Active Brain and transfer freeze;
- no second blocking generation job.

## Python validator integrity

All Python tools are syntax-compiled with `python -m py_compile` before release packaging.

## Manual diff audit

`app_database.dart` was diffed directly against v0.17. Its only changes are:

- `latestProactiveMessage()`
- `latestActiveThought()`

`chat_page.dart` was diffed directly against v0.17. Its only functional UI change is removal of the model dropdown and replacement with companion/recovery status text. Existing message rendering, proactive label, TTS replay and `ReasoningPanel` remain.

## Validation boundary

The current environment has Java but no Flutter SDK, Dart SDK, Gradle executable or Android SDK toolchain.

Therefore v0.18 does **not** claim:

- `flutter analyze` success;
- Flutter widget-test execution;
- Gradle/Android compilation;
- APK installation;
- real-device rendering, permission, overlay, TTS, background or Nearby behaviour.

Those remain part of the agreed real-device checkpoint rather than being pushed onto the user for every source milestone.
