# AI Companion · v0.30.1 Overlay Touch Recovery

Local-first Android AI companion focused on one persistent AI self: long-term memory, relationship state, Thought/Desire, coarse phone awareness, proactive contact, local Meju TTS, true native overlay chat, and single-Active-Brain phone/tablet takeover.

## v0.30.1 checkpoint

v0.29.0 established the clean GitHub source baseline and Meju A2 TTS scheduling. v0.29.1 completed non-blocking TTS/UI polish, but real-device testing exposed a deeper background issue: the native overlay opened while the headless Dart command server was not actually reachable, leaving overlay history empty and sends at “她还在重新连接”.

v0.30.0 fixed the background Dart entrypoint/handshake path and began real Background Presence. v0.30.1 keeps that path unchanged and hardens the Android overlay input channel after real-device testing found an intermittent “visible but untouchable” bubble.

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
