# Prompt Layers · v0.9

The rule architecture is scene-routed. It deliberately separates long-term AI identity from ordinary chat style and intimacy rendering.

| Layer | Load policy |
|---|---|
| 01 AI Companion Core | always |
| 02 Daily Communication | non-intimacy chat |
| 03 Behavioral Realism | always |
| 04 Intimacy Core | intimacy session or explicit first-turn bootstrap |
| 05 Intimacy Rendering | intimacy session or explicit first-turn bootstrap |
| 06 Intimacy Reference | intimacy + retrieved reference material |

`PromptBuilder` always emits a short hard AI-identity guard first, then the resolved editable layers, then local memory/relationship/reference/desire/perception context.

Reference persona documents are not system rules. Full text is preserved locally and only small relevant chunks enter prompt context.
