# v0.26 Internal Validation

Validation performed without Flutter/Android SDK:

- generic XML/Manifest, relative import, Dart/Kotlin delimiter and duplicate-declaration checks;
- deterministic SQLite v18 simulation for generation monotonicity, replay/stale rejection, source fencing and import rollback;
- AES-256-GCM JVM roundtrip with wrong-passphrase and truncation failures;
- `kotlinc` compilation of Nearby v3 protocol, NativeEventStore ownership fence and manual crypto against generated API stubs;
- v0.25 TTS queue and Kotlin core checks;
- all earlier SQLite regressions for proactive intent/rhythm, durable generation, async exactly-once, recovery, Reference, Home, Awareness, Relationship, long-term memory and Daily Continuity;
- byte-freeze comparison against the archived v0.25 source ZIP for files outside the v0.26 allowlist;
- byte-freeze comparison of all 37 golden TTS model/runtime/native payload artifacts.

Not validated here:

- actual Flutter compilation/analyzer;
- Gradle/Android packaging;
- Google Nearby radio/discovery behavior on two physical devices;
- OEM background restrictions;
- real Android Storage Access Framework behavior;
- real-device overlay restoration around repeated takeover;
- subjective TTS/audio behavior.
