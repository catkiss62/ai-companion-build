# v0.27 · Real-device Readiness / Preflight Diagnostics

## Purpose

The remaining high-risk questions are now Android-runtime/hardware questions: whether permissions really connect on a specific OEM, whether the background engine survives, whether MejuTTS initializes and sounds identical on-device, and whether Nearby behaves correctly across two physical devices.

v0.27 adds enough local evidence to diagnose those failures **before** asking the user to iterate through blind APK builds.

## Data flow

The preflight page reads four existing authorities:

1. SQLite read-only state: schema, Active Brain, transfer lock, pending transfer identity, recovery/job counts and non-content record counts.
2. Android `NativePreflightProbe`: permission/runtime, Google Play services, Nearby prerequisites, background restriction and audio-route information.
3. `TtsService`: current status; deep mode additionally executes golden verification and JNI/MNN initialization.
4. `RuntimeDiagnosticStore`: bounded redacted native phases from Nearby and TTS.

No model call is made. No relationship content is summarized for diagnostics.

## Quick vs deep

Quick mode is suitable for normal refresh and does not initialize the TTS model if it is still cold.

Deep mode explicitly performs:

- 37-item MejuTTS v2.7 golden fingerprint verification;
- legacy runtime / JNI / MNN initialization;
- current Android audio-route inspection.

It deliberately does not call `speak()` or `preview()`. Voice match, pronunciation and first-sentence latency remain subjective/physical-device tests.

## Native diagnostic ring

`RuntimeDiagnosticStore` is not relationship memory. It is a process/runtime troubleshooting ring stored in app-local SharedPreferences:

- maximum 160 retained events;
- maximum 30-day age on read/write;
- endpoint discovery churn is not persisted;
- arbitrary relationship/chat/reference strings are never accepted as metadata;
- device/lineage/snapshot/hash identifiers are SHA-256 fingerprinted;
- filesystem paths, UUIDs and long hexadecimal tokens are redacted from safe detail fields.

Nearby's live EventChannel still carries the exact endpoint/session values needed by the current Transfer UI. Only the **persisted diagnostic copy** is redacted.

## Export

The Dart preflight service constructs `ai-companion-redacted-preflight-v1` and writes a temporary text file. Android SAF `ACTION_CREATE_DOCUMENT` then copies it to a user-selected location.

The temporary source file is deleted when the picker call completes. No cloud upload or analytics SDK is involved.

## Explicit report exclusions

The report never queries or includes:

- message/reasoning content;
- Memory text/evidence text;
- RelationshipEvent content;
- Thought/unfinished-thread text;
- Reference raw text/chunks;
- Daily Continuity text;
- raw device events / usage package list;
- notification/Accessibility plaintext;
- DeepSeek key or other secure storage values.

The report may include **counts** of these databases where useful for scale/debugging.

## Ownership diagnostics

The report includes only fingerprinted ownership identifiers plus generation and state flags. It can therefore distinguish:

- normal Active Brain;
- normal standby;
- pending imported standby;
- expected transfer freeze;
- suspicious `transfer_lock=1` with no pending snapshot;
- blocking/failed durable generation or post-turn work.

It does not attempt to auto-repair ownership from the diagnostic page.
