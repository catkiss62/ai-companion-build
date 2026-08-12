# v0.30.0 · Background Presence

This stage turns the existing Android sensing/overlay infrastructure into an actually reachable background companion path. It does not redesign memory, TTS, Active Brain, or the proactive personality model.

## Root cause fixed: overlay background Dart entrypoint

The native service started a second `FlutterEngine` with the entrypoint name `companionBackgroundMain`, but that function lived only in `background_main.dart`. The release root library (`main.dart`) did not import/anchor it. The service could therefore own a real engine/channel object while Dart never installed `BackgroundChatCommandServer`, which matches the real-device symptom: empty overlay history and `notImplemented` -> “她还在重新连接”.

v0.30.0 exports a `@pragma('vm:entry-point')` proxy from the root library and imports the background runtime explicitly. Native also publishes the engine identity before executing Dart so the first `backgroundDartReady` handshake cannot lose a race against `backgroundEngine = createdEngine`.

## Overlay reconnect behavior

- An expanded overlay refreshes immediately when the Dart-ready handshake arrives.
- Send does not clear/optimistically enqueue the user's text while the background brain is not ready. The input remains visible and the UI shows “正在连接后台大脑…”.
- Existing restart/timeout logic remains bounded; the ready handshake is still authoritative.

## Reactive phone-presence wake

Raw phone events remain local and redacted exactly as before. v0.30.0 only adds a coarse wake signal:

- notification posted -> `signal:notification`
- Accessibility window-state change -> `signal:accessibility_window`
- device unlock/present -> `signal:device_present`

No package name, notification text, Accessibility text, title, or content is placed in the wake reason.

Native coalesces these wakes to at most one every 90 seconds. Dart applies a second 90-second minimum before advancing perception early. Normal scheduled heartbeats still use the existing 7-24 minute desire-driven cadence.

A reactive wake does **not** directly send a message. It only allows the normal chain to run sooner:

`device signal -> Perception/Awareness -> Thought/Desire -> existing proactive Gate -> optional model wording -> notification/overlay unread`

All existing anti-spam ceilings, busy soft multiplier, Active Brain fencing, chat-turn lease and proactive lease remain in force.

## Diagnostics

The redacted preflight report now includes:

- native `backgroundBrainReady` as a visible check;
- last coarse background wake reason;
- last proactive decision reason;
- last perception capture timestamp;
- next scheduled heartbeat timestamp.

This is deliberately enough to distinguish “Android event never woke Dart”, “perception ran but Gate waited”, and “message delivery failed” without exporting private notification/chat text.
