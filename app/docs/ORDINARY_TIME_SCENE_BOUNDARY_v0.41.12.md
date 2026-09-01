# Ordinary Chat Time & Transient Scene Boundary · v0.41.12

## Purpose

Ordinary chat must know that clock time passed without pretending to know what happened during the gap. A short-lived activity mentioned in an earlier turn may no longer be current, while the topic, relationship and long-term memories remain continuous.

This package is deliberately separate from personality-learning Phase 2. It changes only ordinary-chat temporal grounding and does not consume Phase 1 candidates in replies.

## Authority split

- The phone keeps two clocks: the previous real-user scene anchor and the latest interaction end. It computes the current user-turn or proactive-trigger time, elapsed minutes and crossed calendar days.
- The API interprets those trusted fields together with the current real user message.
- The API must not redo timestamp arithmetic or infer a precise itinerary from missing conversation.
- Ordinary history remains role/content history; every historical message is not wrapped in an exact timestamp.

## Gap bands

| Band | Phone condition | Ordinary-chat meaning |
|---|---:|---|
| `same_scene` | under 30 minutes, same day | No detailed previous/current timestamp block is injected; normal conversational continuity applies. |
| `transient_recheck` | 30–119 minutes, same day | The API must re-evaluate short-lived activities from activity type, explicit duration/end point, current time and current user text. |
| `long_gap` | 120 minutes or more, same day | Stronger new-scene boundary; short-lived activities remain `unknown`. |
| `cross_day` | one or more calendar days | New-day boundary; do not call the earlier turn “just now”. |

The 30-minute threshold is not a claim that an activity ended. It is the point at which the model receives one detailed time boundary and must stop mechanically continuing an old short scene. A later AI proactive message does not refresh the real-user clock; after the detailed boundary has already been supplied, later triggers carry only a compact reminder so timestamps do not become recurring noise.

## Transient-state contract

After `transient_recheck`, `long_gap` or `cross_day`:

- “eating, showering and short commuting” usually no longer describe the present; the API should omit them or ask naturally rather than mechanically continue them;
- an explicitly long trip, meeting-until-five or other activity with a duration/end point may still continue when the trusted current time supports it;
- the phone does not decide whether an activity finished, and the API must not invent a precise itinerary or persist its one-turn inference;
- a current `REAL_USER_MESSAGE` such as “I am still eating”, “I just finished”, or “I have been doing it all this time” overrides unknown;
- continuing the earlier topic does not imply continuing the earlier physical activity;
- do not recite timestamps or this policy unless time itself is relevant to the conversation.

## Isolation

Immersive rooms use `ImmersivePromptBuilder`, explicit room state, rolling summary and scene ledger. They do not receive this ordinary-chat expiry contract. Proactive generation uses the same real-user scene clock and current trigger time, but never fabricates a new user turn and never resets the scene clock merely because the AI sent a message.

Personality-learning Phase 1 remains observation-only. Phase 2 reply influence, Phase 3 AI habits and Phase 4 low-frequency clarification/entertainment tests remain separate APK checkpoints.

## Verification

Automated coverage must lock:

1. a 13:00 real-user message followed by a 13:15 user turn remains `same_scene` and receives no detailed boundary;
2. exactly 30 minutes triggers one detailed boundary; 13:00 real user → 15:00 is a 120-minute user-scene gap even if the last assistant reply was at 13:01;
3. 120 minutes is `long_gap`;
4. a calendar-day crossing is `cross_day`;
5. a proactive trigger uses the last real user as anchor, and a prior proactive message causes compact carry-forward rather than resetting or repeating detailed timestamps;
6. the prompt preserves current-user override and gives the API bounded judgment for short versus explicitly long activities;
7. `ImmersivePromptBuilder` does not import the ordinary scene-expiry contract.
