# AI Companion · v0.31.0 Grounded Desire Core

Local-first Android AI girlfriend focused on one persistent AI self: long-term memory, relationship state, Thought/Desire, coarse phone awareness, proactive contact, local Meju TTS, native overlay chat, and single-Active-Brain phone/tablet takeover.

## v0.31.0 checkpoint

v0.31 starts by fixing two foundations before tuning proactive frequency again:

1. **Reality Grounding** — the model is explicitly told the device-local date/time/daypart and the real conversation state. SQLite `messages + generation_jobs` determine whether the last real user turn has already been answered. Thought/Memory/Awareness/Inference remain separate evidence classes and cannot be rewritten as user speech. A final proactive grounding guard blocks impossible “you just said/replied …” claims while SQLite says the user has stayed silent.
2. **Grounded Desire Core** — the existing 8 Drive / Thought / Intent system is promoted into a deterministic policy layer with bounded Thought boosts, per-drive refractory, fatigue rest gate, bounded coupling and action-aware satisfy. Phone Presence enters through Drive/Thought and is no longer counted again as a direct Gate boost.

The project source under `app/` remains the GitHub single source of truth. Database schema remains v18.

### Frozen known issue

HyperOS/Android 15 may leave the floating overlay visible but untouchable after entering/returning from the system file picker (for example ChatGPT upload). Opening AI Companion restores it. Overlay work is frozen unless a future main-line change can fix it safely; this issue does not block v0.31.

### Non-regression guardrails

- Active Brain / transfer fencing, chat/proactive leases and 2/2h + 8/24h proactive hard caps remain.
- DeepSeek `reasoning_content` stays separate from body text.
- Raw package names, notification text and Accessibility text do not enter long prompts/Thought/export diagnostics.
- Meju A2 TTS native/model/scheduling baseline is untouched; `Yuki -> 有希` remains speech-only.

Read `docs/HANDOFF.md` first in a new development window. Long-lived work tracking is in `docs/PROJECT_TASK_LEDGER.md`.
