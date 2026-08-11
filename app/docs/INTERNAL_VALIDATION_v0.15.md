# v0.15 Internal Validation

## Automated checks run in this environment

- `tools/validate_v015.py --baseline-zip <v0.14 zip>`
  - XML / Manifest parse
  - Android lifecycle/true-overlay regression patterns
  - Dart relative imports
  - Dart/Kotlin delimiter scanner
  - conservative duplicate Dart declaration scan
  - v0.15 version/schema tokens
  - v0.14 durable-generation regression
  - v0.15 async-worker ownership/fencing patterns
  - phone/tablet transfer lease coverage
  - TTS critical-file SHA-256 comparison against v0.14
- `tools/validate_durable_generation_sql.py`
  - v0.14 generation ownership / atomicity regression
- `tools/validate_async_worker_sql.py`
  - stale post-turn run token rejected
  - cached post-turn proposal survives reclaim
  - post-turn Desire marker applies once
  - relationship event internalizes once
  - stale deferred-followup claim rejected
  - stale thread retirement rejected
  - duplicate conversation-summary range rejected
- Kotlin source parser-level pass with `kotlinc` and no Android classpath. Android/Flutter unresolved references are expected; no `expecting`/redeclaration-class syntax errors were detected.

## Not available in this environment

- `flutter analyze`
- `dart test` / `flutter test`
- Gradle Android build
- APK install / OEM background lifecycle test
- real overlay IME/game behavior
- real Bert-VITS2/MNN audio playback
- Nearby two-device takeover

Those remain explicit device/toolchain milestones rather than being inferred from static checks.
