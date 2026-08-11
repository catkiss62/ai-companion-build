# v0.28 Internal Validation

## Scope

- Checkpoint route and guided UI contract.
- Production TTS preview path, not a fake/test engine.
- Fixed voice probe includes `Yuki` so spoken-only replacement can be heard.
- Checkpoint page performs no direct relationship/database mutation.
- Existing v0.27 redacted preflight remains the failure-report path.
- Schema remains v18.
- v0.27 baseline freeze and TTS golden-payload freeze are rechecked.
- All previous SQLite/Kotlin/crypto regressions are rerun.

## Build-environment probe

`tools/check_android_build_env.py` is intentionally separate from source validation. A missing external Flutter/Android toolchain is reported as a build-environment limitation, not as an app-source test failure.

## Result in handoff environment

- Static source/checkpoint/privacy contracts: PASS.
- v0.27 baseline freeze outside v0.28 allowlist: 275 files byte-identical.
- MejuTTS model/runtime/native freeze against v0.27: 37/37 byte-identical.
- MejuTTS source payload vs user-supplied v2.7 golden APK: PASS.
- Kotlin stub compile: Native preflight, diagnostic store, transfer protocol and TTS core PASS.
- SQLite simulations: proactive, durable generation, async ownership, recovery, Reference, Home, Awareness, Relationship, v15 memory, v16 proactive rhythm, v17 daily continuity, v18 transfer PASS.
- External Android build environment probe: NOT READY (Flutter/Dart/Android SDK/ADB/Gradle wrapper binary unavailable in this container).
