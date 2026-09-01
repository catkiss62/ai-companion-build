# Ordinary Chat Time & Transient Scene Boundary · v0.41.12

## Purpose

Ordinary chat must know that clock time passed without pretending to know what happened during the gap. A short-lived activity mentioned in an earlier turn may no longer be current, while the topic, relationship and long-term memories remain continuous.

This package is deliberately separate from personality-learning Phase 2. It changes only ordinary-chat temporal grounding and does not consume Phase 1 candidates in replies.

## Authority split

- The phone computes the previous ordinary-chat end time, the current user-turn time, elapsed minutes and crossed calendar days.
- The API interprets those trusted fields together with the current real user message.
- The API must not redo timestamp arithmetic or infer a precise itinerary from missing conversation.
- Ordinary history remains role/content history; every historical message is not wrapped in an exact timestamp.

## Gap bands

| Band | Phone condition | Ordinary-chat meaning |
|---|---:|---|
| `same_scene` | under 45 minutes, same day | A short activity may plausibly continue; current user text still overrides. |
| `transient_recheck` | 45–119 minutes, same day | Short-lived activities become `unknown`; topic continuity remains. |
| `long_gap` | 120 minutes or more, same day | Stronger new-scene boundary; short-lived activities remain `unknown`. |
| `cross_day` | one or more calendar days | New-day boundary; do not call the earlier turn “just now”. |

The 45-minute threshold is not a claim that an activity ended. It is only the point at which the model loses permission to assert that the activity is still happening.

## Transient-state contract

After `transient_recheck`, `long_gap` or `cross_day`:

- “eating, showering, commuting, going out, in a meeting, preparing to sleep” and similar short-lived ongoing activities are unknown;
- do not state that the activity continues;
- do not invent the opposite fact that it finished;
- a current `REAL_USER_MESSAGE` such as “I am still eating”, “I just finished”, or “I have been doing it all this time” overrides unknown;
- continuing the earlier topic does not imply continuing the earlier physical activity;
- do not recite timestamps or this policy unless time itself is relevant to the conversation.

## Isolation

Immersive rooms use `ImmersivePromptBuilder`, explicit room state, rolling summary and scene ledger. They do not receive this ordinary-chat expiry contract. Proactive generation retains its existing grounding behavior and does not fabricate a new user turn.

Personality-learning Phase 1 remains observation-only. Phase 2 reply influence, Phase 3 AI habits and Phase 4 low-frequency clarification/entertainment tests remain separate APK checkpoints.

## Verification

Automated coverage must lock:

1. 13:00 conversation end followed by a 13:15 user turn remains `same_scene`;
2. a 13:01 assistant reply followed by a 15:00 user turn is 119 minutes and must be `transient_recheck`;
3. 120 minutes is `long_gap`;
4. a calendar-day crossing is `cross_day`;
5. the prompt explicitly preserves current-user override and forbids both “still happening” and invented “already finished” claims;
6. `ImmersivePromptBuilder` does not import the ordinary scene-expiry contract.
