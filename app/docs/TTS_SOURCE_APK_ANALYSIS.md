# MejuTTS source APK analysis · v0.25

Golden source supplied by the user:

- `MejuTTS_DoomsdayBridge_v2.7.apk`
- 118,896,875 bytes
- SHA-256 `63a8c10f5fc097205f7be8649bf9a60974e02714ef550b54eb5bd74bbc58c5e7`

Only the local TTS path is used. AI Companion does not package the source APK, HTML pages, JS bridge, WebView shell, cloud TTS or unrelated game/account/UI behavior.

Confirmed exact source match in v0.25:

- 22 `assets/tts_models/**` files: byte-identical;
- 6 selected `lib/arm64-v8a/*.so`: byte-identical;
- `runtime_01.jar` ... `runtime_09.jar` `classes.dex` payloads: identical to golden `classes.dex` ... `classes9.dex` 9/9;
- pinyin dictionaries, `nlp/word_freq_dict.txt`, `nlp/chinese_ts_char.txt` and `DebugProbesKt.bin` retained inside runtime_01 and byte-identical.

The original native JNI ABI remains tied to the original compatibility classes. Therefore v0.25 intentionally keeps the already-working compiled preprocessing/G2P dependency closure isolated behind `LegacyTtsRuntime` instead of attempting a speculative source rewrite before sound verification.

The rest of AI Companion only depends on its own `TtsProvider`/`NativeTtsBridge` interface.
