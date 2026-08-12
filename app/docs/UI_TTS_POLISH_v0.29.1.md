# v0.29.1 · TTS / UI polish

This is deliberately a low-risk polish release on top of the real-device verified v0.29.0 clean baseline.

## TTS

- Meju A2 native/model/runtime payload remains frozen.
- A2 sentence boundaries remain exactly `。！？；.!?;`.
- CR, LF, U+2028 and U+2029 layout separators are normalized to ordinary spaces **before** A2 boundary scanning.
- No comma split, no length fallback, no queue redesign.
- Generation-ahead, FIFO playback and the ~200 ms ready-queue gap are unchanged.

This is the final dedicated TTS polish before project work moves on. Any remaining cadence imperfection is non-blocking and can be revisited later.

## Chat UI

- Reasoning is rendered above the assistant body in completed and streaming messages.
- The same ordering is used in the native overlay when reasoning is expanded.

## Overlay

- Bubble window: 70 dp -> 62 dp.
- Avatar: 58 dp -> 50 dp.
- Badge: 24 dp -> 20 dp.
- Badge receives explicit elevation/translationZ and `bringToFront()` so unread count stays above the avatar.
- Opening the overlay returns the latest 8 SQLite messages immediately; full ChatController wake-up happens asynchronously.
- Older history remains opt-in through the existing button (24 at a time), so the overlay does not carry the full chat history by default.
