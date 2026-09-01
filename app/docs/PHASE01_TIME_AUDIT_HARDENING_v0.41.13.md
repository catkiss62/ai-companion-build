# Phase 0+1 & Time Audit Hardening · v0.41.13

## Scope

This independent APK hardens two already implemented foundations before Phase 2 begins:

- Phase 0+1 personality learning remains observation-only, but legacy Memory/Relationship write and recall paths can no longer bypass that isolation.
- Ordinary and proactive chat use a 30-minute, one-detailed-injection time boundary based on the last real user message.
- A narrow outbound guard retries or blocks the observed error where the current user is narrated as “他”.

Version is `0.41.13+152`; database schema stays 42 and Snapshot protocol stays 5. No learning candidate is consumed by replies, AI Self, Desire, Moe or AI habits. No stored user row is deleted or migrated.

## Audit findings and fixes

| Finding | Risk | Local decision |
|---|---|---|
| Learning tables were isolated, but the same model extraction could duplicate an interaction preference into legacy Memory or Relationship Event | Phase 1 result could influence replies through a second path | Reject new duplicates and filter matching legacy rows from prompt recall while preserving backup data |
| A user statement that learning/growth capability was “enabled” could become a relationship promise | The AI could claim implementation beyond code truth | Capability claims are protected; relevant chat receives a conditional observation-only capability fact |
| `direct_feedback` trusted model target selection | A real positive phrase could attach to an unrelated candidate | Require verbatim prior-AI expression plus expression-to-proposition grounding |
| Content preferences and broad propositions could enter the behavior-learning namespace | “Beach photography” or “occasionally stubborn” could become an always-on personality rule | Subject-domain whitelist plus proposition evidence/absolute-cue checks |
| Last interaction time was used as the only practical scene boundary | AI proactive messages or assistant replies could hide how long the user scene was stale | Keep real-user scene time and interaction time separately; AI output never refreshes user reality |
| Time details repeated too often or a hard unknown rule removed useful model judgment | Prompt noise, and long travel/meeting could be treated like eating | Under 30 minutes: no detailed pair; first boundary: detailed; later same scene: compact; API judges activity type and explicit duration |
| Rare output narrated the current user as “他” | Visible viewpoint break | Existing prompt contract plus one retry and high-confidence runtime block; genuine third parties remain allowed |

## API and phone responsibilities

The API still proposes extraction because it is better at natural paraphrases and contextual meaning. The phone retains all irreversible decisions: verbatim-source checks, scopes, subject domains, protected contracts, target existence, direct-feedback provenance, proposition expansion, maturity, idempotence and rejection. Only a unique, explicit, semantically plausible but locally under-matched reinforcement may use the isolated semantic-review API; ambiguous, unrelated, low-confidence or unavailable review is rejected.

For time, the phone performs timestamp arithmetic and chooses `none / detailed / carry_forward`. A proactive prompt injection is marked even if the model chooses `WAIT`, so later background heartbeats do not repeat exact timestamps; a later real user turn still receives its own detailed boundary. The API decides whether the old activity plausibly continues using the trusted interval, activity type, any explicit duration/end point and current user text. That inference is not written as long-term fact.

## Regression boundary

- Ordinary content preference remains Memory; behavioral interaction preference remains Phase 1 evidence only.
- Existing backup rows are preserved but behavioral legacy rows do not enter reply prompts while Phase 1 is observation-only.
- “慢慢来/不急” remains context-only unless the user explicitly states a pacing preference.
- “海边散步” and “海边拍照” cannot merge through generic-word edge bigrams and cannot become behavior-learning subjects.
- A proposition cannot add “每轮/永远/必须” unless that absolute cue appears in the user evidence.
- The current user remains “你”; genuine third-party discussion can still use “他/她”.
- Immersive room continuity remains on its separate Session path.

## Delivery boundary

The branch is `agent/v04113-phase01-time-audit-hardening`. Full static validation, Flutter analyze/tests, Kotlin tests, Release APK, fixed signing and payload checks must pass in GitHub Actions. The branch is not merged to `main`, and the test release remains a draft. True-device results remain pending until the supplied replay and time-observation steps are completed.
