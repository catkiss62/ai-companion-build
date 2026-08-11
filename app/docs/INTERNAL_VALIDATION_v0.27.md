# v0.27 Internal Validation

## Scope

v0.27 is constrained to local preflight/diagnostic readiness. Database schema remains v18; relationship state, Memory, Desire/Thought semantics, Daily Continuity, Active Brain protocol and MejuTTS binary payloads are not redesigned.

## New deterministic checks

- Native diagnostic redaction helper compiles/runs on JVM and removes paths, UUIDs and long hashes while producing 12-character SHA-256 identity fingerprints.
- `NativePreflightProbe` compiles against Android/Google Play services API stubs.
- Preflight privacy contract statically rejects content-bearing database queries and TTS `speak/preview` calls.
- Runtime history is bounded to 160 events / 30 days.
- Nearby persisted diagnostics are connected at the process-wide `emit()` boundary but skip endpoint-found/lost churn.
- TTS persists golden verify/init phases and only the inference failure class; spoken text is never persisted in the native ring.
- Diagnostic export uses Android SAF and a max-2MB local report source.

## Regression suites rerun

All existing SQLite simulations are rerun:

- durable generation ownership/atomicity;
- async worker stale-token/exactly-once;
- recovery orchestration;
- Reference transaction consistency;
- Companion Home read model;
- Awareness migration/dedupe/expiry/Active Brain;
- Relationship presentation;
- long-term memory v15 semantics;
- proactive intent and v16 rhythm learning;
- daily continuity v17;
- transfer generation/replay/rollback/fencing v18.

Kotlin/JVM checks rerun:

- Nearby v3 + NativeEventStore + manual crypto stubs;
- manual AES-GCM roundtrip/wrong-pass/truncation;
- TTS queue cancel/FIFO/error isolation;
- key TTS bridge/runtime source compilation against stubs;
- new preflight probe and redaction tests.

## Environment boundary

No Flutter SDK or Android SDK is installed in the current environment. Therefore v0.27 does not claim:

- Flutter analyzer/build success;
- APK packaging/installation;
- Android SAF picker behavior on OEM devices;
- actual permission connection state;
- JNI/MNN runtime initialization on ARM64 hardware;
- audio playback quality/latency;
- physical Nearby radio discovery/transfer/takeover.

Those are precisely the next real-device checkpoint.
