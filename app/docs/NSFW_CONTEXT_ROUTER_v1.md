# NSFW Context Router v1 · v0.35.3+78

## Product contract

- Chat top bar exposes one compact rectangular `NSFW` button: white text/border when off and purple when active.
- Before an ordinary user reply, a small non-thinking DeepSeek pass classifies recent context as `daily`, `nsfw`, or `nsfw_reference`. The result controls the prompt layers used by the actual reply and updates the button.
- A user tap is a one-turn correction with higher priority than automatic routing. It changes the visible state immediately; after that turn, automatic classification resumes.
- Classifier failure never loses a durable user turn. It falls back to ordinary chat so an unrelated turn cannot inherit adult rendering; the user can correct the next turn manually.

## Layer loading

- `daily`: excludes `04_intimacy_core`, `05_intimacy_rendering`, and `06_intimacy_reference`.
- `nsfw`: loads the complete `04_intimacy_core` and `05_intimacy_rendering` bodies.
- `nsfw_reference`: additionally loads `06_intimacy_reference` for detailed position, clothing/contact state, toys/devices, remote constraints, or extended scene continuity.
- The old exact-phrase bootstrap is removed. An already-open Session is not required before adult prompt layers may load.

## Session and Somatic boundary

NSFW routing decides adult language/rendering. Session continues to record a shared scene's position, action, clothing and stage continuity; it does not grant adult-content permission. Somatic dual channels may describe the AI's own internal response without claiming an unseen facial expression, physical temperature, touch, or co-presence as external fact.

## Seductress style

`seductress` is explicitly supplied to the router as an NSFW bias. Genuine adult innuendo or invitation crosses the NSFW threshold more readily, while unrelated ordinary conversation remains `daily`. The style's user-authored prompt body is unchanged.

## Exact prompt integrity

The 31 subsection bodies from the six supplied files are stored in `rule_layer_content_v0353.dart`. Their approved SHA-256 values are enforced by `validate_v0353_nsfw_context_router.py`; titles, IDs and routing metadata remain code-owned. Untouched v0.35.2 defaults upgrade in place, while any user-edited body remains preserved.

## Prompt-pack files and sampling

Primary prompt-pack export/import now uses Android `ACTION_CREATE_DOCUMENT` / `ACTION_OPEN_DOCUMENT` with the existing direct-picker overlay guard. Clipboard copy/paste remains a secondary overflow-menu option. Temperature UI, persistence use, request parameter and chat/proactive wiring are removed; model thinking mode remains available.

## Build evidence

- Source head: `728910bbc1c34096eeef9768cd195d121cf28faa`
- GitHub Actions run: `32193850897` (all validators, Kotlin tests, Flutter analyze/tests, APK build and payload verification passed)
- APK: `AI-Companion-v0.35.3-78-NSFW-Context-Router-APK.apk`
- SHA-256: `527cb134f205b71ef4096c7fc3edb944b642c6e54e383f0af175febb053ef5ee`
- Draft release: `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-e85044b50d823eb96cbd`
- Remaining evidence: real-device routing, button correction, prompt-pack round trip, and language-quality checks. CI success does not claim those are already proven.
