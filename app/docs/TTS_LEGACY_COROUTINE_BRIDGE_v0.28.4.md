# v0.28.4 Legacy TTS coroutine bridge

Real-device v0.28.3 proved the 37/37 Meju payload integrity check passes, but `LocalTTSEngine.initialize()` failed with `NoSuchMethodException ... [interface WO.d]`.

The cause is class-loader/type identity, not a missing TTS method: the Meju dex method descriptor is `initialize(kotlin.coroutines.Continuation)`, while the host release may R8-rename its own Kotlin Continuation. The bridge previously looked up the method using the host Continuation class.

v0.28.4 resolves the legacy suspend methods from the loaded Meju class itself and creates a dynamic Continuation proxy implementing the exact interface from the legacy class loader. The same path is used for both `initialize()` and `generateTTS()`.
