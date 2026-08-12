# AI Companion · v0.31.1 Proactive Grounding + Chat Timestamps

Local-first Android AI girlfriend focused on one persistent AI self: long-term memory, relationship state, Thought/Desire, coarse phone awareness, proactive contact, local Meju TTS, native overlay chat, and single-Active-Brain phone/tablet takeover.

## v0.31.1 checkpoint

v0.31.0 established correct Reality Grounding metadata, but real-device testing showed DeepSeek proactive **reasoning** could still psychologically latch onto an already-answered user message such as “你好”. v0.31.1 closes that remaining model-input gap:

1. **Proactive Context Isolation** — answered chat history is collapsed into a read-only system transcript. Proactive generation has no current `role=user` turn to answer.
2. **Reasoning Grounding** — both DeepSeek `reasoning_content` and final body must respect `CURRENT_USER_TURN=NONE`. A narrow deterministic reasoning guard detects falling back into “reply to the user's last answered message” mode.
3. **One corrective retry** — the first grounding violation gets one clean regeneration with an explicit correction contract. A second violation is blocked before persistence.
4. **Chat timestamps** — the full-app chat displays per-message `HH:mm` metadata plus date separators. TTS remains content-only, so timestamps are never spoken.

Database schema remains v18. Desire Core v2 / Presence / TTS / Android Overlay internals are not redesigned in this version.

### Frozen known issue

HyperOS/Android 15 may leave the floating overlay visible but untouchable after entering/returning from the system file picker. Opening AI Companion restores it. Overlay work remains frozen unless a future main-line change can fix it safely.

Read `docs/HANDOFF.md` first in a new development window. Long-lived work tracking is in `docs/PROJECT_TASK_LEDGER.md`.
