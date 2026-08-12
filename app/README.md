# AI Companion · v0.29.1 TTS / UI Polish

Local-first Android AI companion. The AI keeps an explicit AI identity, six-layer relationship rules, local long-term memory, Relationship/Desire/Thought continuity, proactive messaging, Android awareness, true overlay chat, local Meju Bert-VITS2 voice, durable generation/recovery and single-Active-Brain phone↔tablet continuity.

## v0.29.1 checkpoint

The first Android 15 device checkpoint has now passed app startup, SQLite, permissions, chat generation and the legacy TTS coroutine/ClassLoader bridge. v0.29.0 addresses the remaining TTS cadence mismatch by restoring the verified Meju A2 scheduling behavior instead of serially doing `generate -> play -> generate -> play`.

Key TTS properties:

- verified original A2 `libbertvits2.so` body (`635352` bytes, SHA-256 `a1ca5180…c5551b`) remains frozen inside the padded APK entry;
- split only on `。！？；.!?;`;
- no comma/newline/ellipsis or character-count splitting;
- later sentence WAVs generate while the current sentence is playing;
- FIFO playback with the original ~200 ms ready-queue gap;
- no 60-second pending-request cleanup;
- `Yuki -> 有希` remains speech-only.

Database schema remains **18**. No Memory/Relationship/Active Brain/Transfer migration is introduced.

## GitHub baseline promotion

v0.29.0 is also the cutoff for the temporary five-part ZIP + patch-chain build process. A one-time promotion workflow reconstructs the verified source and commits the complete Flutter project under `app/`. Only after a clean build from `app/` succeeds should the old split parts and v0.28.x patches be removed.

See:

- `docs/TTS_A2_BASELINE_v0.29.md`
- `docs/GITHUB_CLEAN_BASELINE_v0.29.md`
- `docs/REAL_DEVICE_CHECKPOINT_v0.28.md`
- `docs/DEV_STATUS.md`
- `docs/ROADMAP.md`


## v0.29.1 polish

The Meju A2 native/runtime baseline remains frozen. v0.29.1 normalizes layout line breaks before A2 segmentation, renders reasoning above assistant text, shrinks/fixes the overlay unread bubble, returns the latest 8 overlay messages immediately from SQLite, and introduces `docs/HANDOFF.md` as the mandatory cross-window handoff source.
