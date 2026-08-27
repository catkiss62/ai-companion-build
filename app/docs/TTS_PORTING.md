# Native TTS Porting Status · current (v0.39.5)

The historical HTML/WebView shell is not used by AI Companion.

Direct chain:

`Flutter -> MethodChannel -> NativeTtsEngine -> LegacyTtsRuntime (ZH) -> JNI -> libbertvits2.so -> MNN -> .mnn -> byte[] RIFF/WAV -> AudioTrack`

Current reference is the user-supplied `完整文件(1).zip`, SHA-256 `b72ebc8544de88ee368946d2ac824ea1641377ddbe6e2da378d4112c379a9671`.

v0.39.5 verifies 32 packaged core artifacts before native initialization. The current inventory is `TTS_RUNTIME_MANIFEST_v0.39.5.json`; the old v0.25 manifest remains only as historical evidence.

Visible text is never rewritten by pronunciation replacements. `Yuki -> 有希` remains speech-only. `reasoning_content` is physically routed away from the TTS stream.

The new call contract returns WAV bytes directly instead of Base64. Normal A2 punctuation boundaries, generation-ahead FIFO playback, whole-queue stop and emotion lead-in semantics remain unchanged. Only an exceptional punctuation-free run receives a 72-character safety split so the ZH frontend stays below its 300-phone limit.

Real-device JNI/MNN/audio behavior is not claimed until the built APK is tested on an arm64 Android device.
