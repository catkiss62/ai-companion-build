# AI Companion · v0.30.3 Overlay Regression Repair

Local-first Android AI companion focused on one persistent AI self: long-term memory, relationship state, Thought/Desire, coarse phone awareness, proactive contact, local Meju TTS, true native overlay chat, and single-Active-Brain phone/tablet takeover.

## v0.30.3 checkpoint

v0.29.0 established the clean GitHub source baseline and Meju A2 TTS scheduling. v0.29.1 completed non-blocking TTS/UI polish, but real-device testing exposed a deeper background issue: the native overlay opened while the headless Dart command server was not actually reachable, leaving overlay history empty and sends at “她还在重新连接”.

v0.30.2 successfully advanced Presence Intelligence, but its overlay recovery became too aggressive on HyperOS: normal use could trigger dozens of self-heals/cover recoveries, and even the overlay “打开” action could regress. v0.30.3 keeps Presence Momentum/Thought/Gate behavior frozen and repairs only the overlay lifecycle: narrow cover detection, re-entrancy guarded recovery, long cooldown, lightweight Activity reconcile, and launch-first full-App opening.

- root-library `@pragma('vm:entry-point')` anchor for the headless companion runtime;
- engine identity published before Dart execution to remove the ready-handshake race;
- overlay auto-refresh after ready and non-destructive reconnect behavior;
- coarse, privacy-preserving reactive wakes from notification/window/unlock signals;
- native + Dart 90-second coalescing before an early perception heartbeat;
- no bypass of Active Brain fencing, chat/proactive leases, proactive Gate, busy soft multiplier or hard message ceilings;
- redacted diagnostics for background ready/wake/perception/proactive progression.

Overlay touch hardening in v0.30.1:

- WindowInsets safe area for persisted/snap coordinates;
- hidden chat overlay windows are fully removed on collapse;
- Activity reconcile can rebuild the bubble WindowManager input channel;
- ACTION_CANCEL and failed WindowManager updates recover drag state;
- redacted `overlayTouch` diagnostics expose attachment/touchability/safe-position/self-heal state.

The project source under `app/` is the single source of truth in GitHub. Historical split ZIPs and v0.28 patch-chain inputs are obsolete.

See `docs/HANDOFF.md` first when continuing the project in another chat/window.


v0.30.3 changes:

- Presence Momentum / Thought / bounded Presence Gate boost are byte-for-byte unchanged from v0.30.2;
- system-cover recognition is narrowed to real file-picker/permission/settings surfaces instead of all system apps;
- overlay recovery has scheduled/in-progress re-entrancy guards plus an 8-second minimum gap;
- recovery-generated visibility callbacks are ignored so remove/add cannot recursively trigger another rebuild;
- visible full-App reconciliation is lightweight unless a cover transition explicitly marked the input channel suspect;
- overlay “打开” requests the full Activity first and lets MainActivity collapse the overlay after resume;
- redacted overlay diagnostics now also expose whether a recovery is currently in progress.
