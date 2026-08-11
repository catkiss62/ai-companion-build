# Internal Validation · v0.25

Validated without producing an APK:

- golden APK SHA-256 matches the user-supplied MejuTTS v2.7 baseline;
- all 22 `tts_models` assets match the golden APK byte-for-byte;
- all 6 selected arm64 native libraries match the golden APK byte-for-byte;
- runtime JAR `classes.dex` payloads match golden `classes.dex` ... `classes9.dex` 9/9;
- pinyin/NLP resources in `runtime_01.jar` match the golden APK;
- no HTML or JavaScript file is shipped in the AI Companion source tree;
- TTS Kotlin integration contains no WebView/JavascriptInterface/evaluateJavascript dependency;
- 37-artifact runtime integrity gate is wired through Flutter -> MethodChannel -> Kotlin;
- stale/private runtime cache copies are fingerprint-checked and replaced;
- pronunciation replacements still operate only on spoken text;
- reasoning_content remains outside the TTS stream;
- queue/cancel/error test sources exist and the queue is decoupled behind `TtsQueueService`;
- key TTS Kotlin sources compile with `kotlinc` against generated Android/Flutter stubs;
- prior v0.13-v0.24 source/SQLite contracts remain green;
- database schema remains v17.

Not claimed:

- Flutter analyzer/test execution (Flutter/Dart SDK unavailable);
- Android Gradle build (Android SDK unavailable);
- JNI/MNN runtime success;
- subjective voice/latency/background-audio behavior.
