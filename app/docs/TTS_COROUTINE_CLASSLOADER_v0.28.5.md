# v0.28.5 TTS coroutine/ClassLoader bridge

## Real-device failure

v0.28.4 reached the packaged Meju runtime and resolved the real suspend method,
but Android 15 reported `NoSuchFieldException: INSTANCE` while the bridge tried
to reflect `kotlin.coroutines.EmptyCoroutineContext.INSTANCE`.

The legacy dex does contain that field. The unsafe assumption was the class
lookup: Android class loading is parent-first, so a lookup by Kotlin class name
can resolve a host/R8-processed Kotlin runtime instead of the exact runtime ABI
used by the resolved legacy `Continuation`.

## v0.28.5 fix

- no reflection of `EmptyCoroutineContext.INSTANCE`;
- no reflection of `IntrinsicsKt.getCOROUTINE_SUSPENDED()` or a static suspend marker;
- derive the exact `CoroutineContext` interface from the resolved legacy
  `Continuation.getContext()` signature;
- provide an empty context using a dynamic proxy implementing that exact interface;
- identify `resumeWith` by signature rather than depending on a host Kotlin type;
- decode Kotlin `Result.Failure` by locating a Throwable-valued instance field,
  avoiding a hard dependency on an R8 field/class name;
- use the same bridge for `initialize()` and `generateTTS()`.

## Staged diagnostic

The real-device checkpoint now includes a non-audible staged TTS probe. It runs
through golden integrity, legacy class loading, engine construction, coroutine
bridge, `initialize`, JNI/MNN readiness, `generateTTS`, Base64 decode, and
RIFF/WAVE header validation. The last completed stage is returned to Flutter and
is also safe to include in the redacted diagnostic report.
