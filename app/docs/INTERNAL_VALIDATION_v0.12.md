# v0.12 Internal Validation

## Scope

Android lifecycle audit only. Database schema remains v10.

## Source-level checks

- Android manifest XML parses.
- Permission declarations are runtime-gated; ACCESS_FINE_LOCATION/Wi-Fi compatibility extend through API 32 and NEARBY_WIFI runtime request starts at API 33.
- boot receiver + RECEIVE_BOOT_COMPLETED declaration present.
- foreground companion service remains `specialUse` and has subtype property.
- NotificationListener has connected/disconnected diagnostics and `requestRebind` path.
- Accessibility has connected/interrupted/destroy lifecycle state.
- overlay permission watchdog present.
- service stores explicit user-enabled state separately from process-local running state.
- Activity onResume reconciliation present.
- background engine bridges are disposed before engine destroy.
- background Dart database init and diagnostic writes are inside non-fatal retry paths.
- low-memory notifications reach Flutter SystemChannel and Dart VM.
- Nearby transport supports multiple listeners and contains one `Payload.Type.BYTES` branch.
- NativeEventStore refuses device-event writes while `transfer_lock=1` or `active_brain=0`.
- overlay configuration-change handler clamps bubble coordinates to the current display and persists the snapped position device-locally.
- notification-disabled path preserves local message and writes diagnostics.
- background isolate, PerceptionEngine and MemoryExtractor diagnostic paths all honor `brainWorkAllowed()` before mutation.
- TransferPage restores standby/manual-takeover UI from durable SQLite state after recreation.
- Nearby incoming FILE payloads enforce a transport-level 512 MiB cap and call `cancelPayload()` when exceeded.
- snapshot restore remains a logical SQLite transaction; no database-file replacement/stale-inode path is used.
- transitional overlay root close falls back to `SystemNavigator.pop()` instead of relying on an empty Navigator stack.
- ChatController async notifications are dispose-guarded and ChatPage async/post-frame callbacks check `mounted`.
- Activity-owned FlutterEngine destruction during an active stream is documented as an unresolved lifecycle boundary, not silently counted as solved.
- NativeTtsEngine serializes initialize/config/release with inference under the same process-wide lock.
- all local Dart relative imports resolve.
- pubspec / Android XML parse.

## Regression checks

- SQLite schema remains 10: no migration is introduced in v0.12.
- six rule layers remain in source/defaults.
- TTS JNI/model/legacy-runtime assets are byte-for-byte compared with v0.11; only `NativeTtsBridge.kt` and `NativeTtsEngine.kt` are expected to differ, both for explicit lifecycle/concurrency fixes.
- archive integrity checked after packaging.

## Known gap

The bubble is a true TYPE_APPLICATION_OVERLAY, but expanded chat is still a translucent FlutterActivity. It is explicitly *not* counted as final overlay-chat completion. Activity destruction can also abort an in-flight Dart chat turn; v0.13 service-owned overlay hosting is the planned fix for the floating-chat path.
