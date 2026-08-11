# v0.28 · First Real-device Checkpoint Harness

v0.28 does not add another companion brain feature. It packages the already-built runtime capabilities into one guided hardware-verification surface so the first APK can be tested in a controlled order.

## Test order

1. **Quick preflight** — database/schema/ownership, Android permissions, background restrictions, Nearby prerequisites, audio route and current TTS availability.
2. **Deep TTS preflight** — re-hash all 37 MejuTTS golden payloads and initialize JNI/MNN without speaking.
3. **Real TTS playback** — fixed local sentence through the production `TtsService.preview()` path. The sentence includes `Yuki`, so the existing spoken-only `Yuki -> 有希` replacement is exercised without changing chat text.
4. **Perception/permissions** — grant UsageStats, notification-listener, Accessibility, overlay and notification permissions; read current screen/lock/listener state from the existing Android bridge.
5. **Overlay/background/notifications** — exercise the real system page and normal chat surfaces. The checkpoint harness does not create fake relationship messages merely to make a test pass.
6. **Phone <-> tablet takeover** — only after the single-phone checks pass; use the existing v0.26 generation/lineage/snapshot protocol.

## Failure handling

The harness links back to the v0.27 redacted preflight exporter. Hardware failures should produce a local diagnostic report before any one-off code change is attempted.

The fixed voice probe is not written into chat history, Memory, RelationshipEvent, Thought, Daily Continuity or Reference. It is a direct preview through the production local TTS provider.

## Build boundary

The source tree is ready for a standard Flutter/Android build, but the current execution environment used for this handoff has Java/Kotlin only and does not provide Flutter SDK, Android SDK, ADB or a complete Gradle wrapper binary. `tools/check_android_build_env.py` makes this boundary explicit instead of claiming a successful APK build.
