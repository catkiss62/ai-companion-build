# Native TTS Porting Status · v0.25

The historical HTML/WebView shell is not used by AI Companion.

Direct chain:

`Flutter -> MethodChannel -> NativeTtsEngine -> LegacyTtsRuntime (isolated Chinese preprocessing/G2P dependency closure) -> JNI -> libbertvits2.so -> MNN -> .mnn -> Base64 WAV -> AudioTrack`

Golden reference is the user-supplied `MejuTTS_DoomsdayBridge_v2.7.apk`, SHA-256 `63a8c10f5fc097205f7be8649bf9a60974e02714ef550b54eb5bd74bbc58c5e7`.

v0.25 verifies 37 packaged core artifacts before native initialization and fixes stale private runtime-cache reuse. See `NATIVE_TTS_CORE_v0.25.md` and `TTS_GOLDEN_MANIFEST_v0.25.json`.

Visible text is never rewritten by pronunciation replacements. `Yuki -> 有希` remains speech-only. `reasoning_content` is physically routed away from the TTS stream.

Real-device JNI/MNN/audio behavior is intentionally not claimed until an APK checkpoint is actually required.
