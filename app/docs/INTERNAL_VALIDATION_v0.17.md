# v0.17 Internal Validation

## Automated source/static validation

Run:

```bash
python tools/validate_v017.py --baseline-zip /mnt/data/ai_companion_v0_16_source.zip
python tools/validate_proactive_intent_sql.py
python tools/validate_recovery_orchestration_sql.py
python tools/validate_durable_generation_sql.py
python tools/validate_async_worker_sql.py
```

Validated:

- XML and AndroidManifest parse;
- `CompanionReplyReceiver` exists and is non-exported;
- Dart relative imports;
- Dart/Kotlin delimiter balance;
- adjacent duplicate Dart declarations;
- `0.17.0+17` and schema v13;
- eight proactive intent keys;
- three delivery styles and three privacy modes;
- intent-aware response rhythm;
- notification privacy route;
- gentle Android notification channel;
- RemoteInput quick reply route;
- stable quick-reply message-ID idempotency;
- true-overlay architecture regression guard;
- 41 critical TTS files unchanged from v0.16.

## SQLite migration simulation

`validate_proactive_intent_sql.py` constructs a simplified v12 database and applies the v13 metadata migration. It verifies:

- attachment Thought → `miss_you`;
- libido Thought → `intimacy_invitation`;
- reflection Thought → `share_thought`;
- linked unfinished thread → `followup`, taking precedence over drive;
- all migrated proactive deliveries default to `normal`;
- non-proactive user messages remain untagged;
- intent-history query path works after index creation.

## Previous stability regressions

The following existing SQL simulations are rerun unchanged:

- RecoveryOrchestrator / failed-generation attention;
- Durable Generation ownership and atomicity;
- async-worker run-token / exactly-once behavior.

All pass under the v0.17 source tree.

## Kotlin parser-level scan

`kotlinc` is available but Android/Flutter SDK classpaths are not. Compiling all Kotlin therefore intentionally produces unresolved Android/Flutter references. The stderr scan reports zero occurrences of:

- `expecting`
- `conflicting overloads`
- `redeclaration`
- `type mismatch`
- `smart cast`

This is a parser/structure signal only, not a Gradle build claim.

## TTS regression

41 critical Bert-VITS2 / MNN files are SHA-256 compared with v0.16:

- changed: 0
- missing: 0

## Not claimed

This environment still cannot claim:

- Flutter analyzer/test execution;
- Gradle APK build;
- Android RemoteInput/notification-channel behavior on OEM devices;
- true overlay + IME behavior in QQ/games;
- Foreground Service kill/restart behavior on a real device;
- Bert-VITS2/MNN actual audio output;
- Nearby two-device takeover.
