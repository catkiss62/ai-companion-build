# v0.16 Internal Validation

## Automated source checks

`tools/validate_v016.py` checks:

- XML / Manifest parse and required Android lifecycle declarations;
- Dart relative imports;
- Dart/Kotlin delimiter balance and duplicate Dart declarations;
- true-overlay invariants;
- version 0.16.0+16 with schema 12;
- durable-generation invariants inherited from v0.14;
- async-worker ownership invariants inherited from v0.15;
- RecoveryOrchestrator lease, independent heartbeat clock, queue budget and wake route;
- background Dart-ready handshake, Engine ready watchdog/restart, fresh wake retry budget;
- SystemBridge / AndroidBridge recovery diagnostics;
- API-config durable-queue wake;
- manual generation/post-turn recovery guards;
- transfer/snapshot orchestrator reset;
- TTS critical-file hash baseline against v0.15.

## SQLite simulations

- `validate_durable_generation_sql.py`: durable generation ownership + atomicity.
- `validate_async_worker_sql.py`: stale post-turn token, cached proposal, relationship/deferred/summary idempotence.
- `validate_recovery_orchestration_sql.py`: latest failed-generation attention, Active Brain/transfer guards, single blocking generation, manual post-turn retry ownership, earliest effective post-turn due selection.

## Kotlin parser-level boundary

`kotlinc` exists but Android/Flutter SDK classpath does not. Running all Kotlin sources therefore intentionally produces unresolved Android/Flutter symbols. The useful parser-like signals are checked separately: no `expecting`, conflicting overload, redeclaration, type-mismatch or smart-cast diagnostics were found in the current v0.16 source.

This is not a Gradle build and must not be reported as one.

## TTS regression

41 critical Bert-VITS2 / MNN model/native/runtime files compare byte-for-byte equal to v0.15.
