# Native TTS Core Integration · v0.25

> Historical baseline. The active v0.39.5 contract is documented in
> `TTS_RUNTIME_UPGRADE_v0.39.5.md`.

## Goal

Integrate the user's verified MejuTTS voice directly into AI Companion without carrying the historical HTML/WebView/JS shell.

Golden reference:

- `MejuTTS_DoomsdayBridge_v2.7.apk`
- SHA-256 `63a8c10f5fc097205f7be8649bf9a60974e02714ef550b54eb5bd74bbc58c5e7`

The standalone APK itself is **not** embedded in AI Companion.

## What is retained

The direct local chain is:

`Flutter -> MethodChannel -> NativeTtsEngine -> isolated compatibility preprocessing runtime -> JNI -> Bert-VITS2/MNN -> WAV -> AudioTrack`

Retained golden payload:

- 22 `tts_models/` model/preprocess assets;
- 9 isolated runtime JARs whose `classes.dex` payloads match the golden APK's `classes.dex` ... `classes9.dex`;
- pinyin/NLP classpath resources inside `runtime_01.jar` matching the golden APK;
- 6 arm64 native libraries: Bert-VITS2, MNN, tokenizer and Jieba.

Not retained:

- HTML pages;
- WebView shell;
- JavaScript injection/bridge;
- cloud TTS;
- original game/account/UI flows.

The compatibility DEX is intentionally isolated behind `LegacyTtsRuntime`. It preserves the already-working Chinese normalization/G2P dependency closure rather than guessing at a source rewrite before real-device voice verification. No Companion feature calls original HTML/JS APIs.

## Golden integrity gate

v0.25 adds `TtsGoldenBaseline` + `TtsArtifactVerifier`.

Before first native initialization the app validates 37 packaged artifacts by SHA-256 and byte size:

- 22 model/preprocess assets;
- 9 runtime JARs;
- 6 native libraries.

The expensive scan is cached for the process lifetime. Settings -> `校验 TTS` can force a re-scan. A fingerprint mismatch fails closed: the local model is not initialized.

The source/audit copy of the expected hashes is `docs/TTS_GOLDEN_MANIFEST_v0.25.json`.

## Runtime cache correctness

Older code reused any non-empty JAR already present in private `codeCacheDir`. That could leave an older compatibility runtime active after an APK upgrade.

v0.25 uses a versioned cache directory and validates every cached runtime JAR against its golden SHA-256/size. Invalid or stale copies are atomically replaced from packaged assets and then marked read-only before `DexClassLoader` sees them.

## Queue / cancel / failure boundaries

- reasoning text never enters the speech queue;
- visible text and spoken text remain separate (`Yuki -> 有希` only affects speech);
- streaming sentences stay FIFO;
- `stop()` invalidates not-yet-started Dart chunks immediately;
- native `speechGeneration` discards WAV returned by an already-cancelled MNN inference;
- one sentence failure must not poison following queued sentences;
- TTS diagnostics are best-effort and cannot turn an optional voice failure into a chat/proactive durability failure.

Dart tests cover queue cancel/order/error behavior. The current environment lacks Dart/Flutter, so those sources are validated structurally but are not claimed as executed here.

## Validation boundary

This environment can:

- hash/compare the golden APK and source payloads;
- run deterministic Python checks;
- compile the key Kotlin TTS bridge/runtime sources against Android/Flutter API stubs with `kotlinc`;
- run the project's source/static/SQLite regressions.

It cannot verify actual JNI linking, MNN inference, voice identity, latency, AudioTrack behavior or OEM background audio without Android build tooling and a real arm64 device. Those remain for the first required APK checkpoint.
