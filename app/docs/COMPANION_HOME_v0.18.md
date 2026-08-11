# Companion Home / Relationship Presence · v0.18

## Goal

The companion already has durable memory, relationship events, Thought/Desire, proactive contact, Android perception, background recovery and single-Active-Brain device ownership. Before v0.18, the full app exposed those systems mainly as five engineering tabs.

v0.18 changes the presentation hierarchy without changing the underlying brain semantics.

The daily question is no longer "which subsystem do I want to inspect?" It is "is she here, what is carrying forward, and do I want to talk to her?"

## Daily navigation

The app shell now has three destinations:

1. `她`
2. `聊天`
3. `更多`

`Inner`, `System`, `Transfer` and `Settings` are no longer equal-weight bottom navigation destinations.

## Home data contract

`CompanionHomeRepository` reads the existing durable SQLite state and builds a read-only `CompanionHomeSnapshot`.

It does not tick Desire, create Thoughts, capture new perception, assimilate relationship events, or trigger proactive generation merely because the user opened Home.

The snapshot contains:

- `activeBrain`
- `transferLocked`
- local `deviceId`
- latest active/fixation Thought
- latest proactive assistant message
- top active unfinished thread
- latest perception timestamp
- active interaction Session

This means Home observes the same companion state used by the rest of the system; it does not create a decorative parallel state model.

## Presence language

### Active Brain

Home states that she is currently running on this device and that chat, memory, Thoughts and proactive behaviour continue here.

### Standby

Home states that she is currently running on the other device. The local copy remains readable, but the UI explicitly avoids implying that a second independent companion is alive here.

### Transfer lock

Transfer lock takes presentation priority over the active flag. The UI explains that durable brain writes are temporarily frozen to avoid two devices mutating one long-term state during handoff.

## Thought presentation

Home uses `latestActiveThought()` rather than the diagnostic `activeThoughts()` ordering.

The diagnostic query is strength-first because Desire/proactive logic needs the strongest current drivers. Home instead needs the most recently updated active/fixation Thought, so it orders by `updated_at DESC` and excludes snoozed, acted and residual Thoughts.

No strength, baseline, action count, merge count, lifecycle score or Drive meter is shown.

## Proactive contact

Home uses `latestProactiveMessage()` to retrieve only the most recent assistant message whose durable `is_proactive` flag is set.

The card shows:

- local message body;
- relative send time;
- the already-persisted v0.17 intent label.

Tapping it opens the normal chat surface. No second notification/chat pipeline is introduced.

## Perception privacy

The companion is still allowed to use the full locally stored perception summary when building AI context according to the existing perception rules.

Home deliberately shows only when the last perception snapshot happened. It does not surface package names, notification counts or Accessibility snippets as relationship UI.

Those details remain available in system diagnostics.

## Chat simplification

The model dropdown has been removed from the chat top bar. Model and reasoning-effort selection remain available in Settings and continue to be read by `ChatController`.

Reasoning content itself is unchanged: API `reasoning_content` remains stored separately from assistant `content` and is still rendered through `ReasoningPanel`.

## Secondary surfaces

`更多` groups:

### 你们之间
- relationship continuity
- long-term memory
- reference library

### 设备
- phone/tablet handoff
- permissions and system diagnostics

### 设置
- model, reasoning, TTS, memory, perception and proactive configuration

### 高级与诊断
- the previous Inner diagnostic surface

This preserves developer access during construction while keeping it out of the ordinary relationship path.

## Non-goals

v0.18 does not:

- change schema 13;
- alter Desire math;
- change Thought lifecycle;
- change proactive gating;
- change memory extraction/retention;
- change durable generation or RecoveryOrchestrator;
- change Active Brain handoff semantics;
- change TTS core files;
- introduce an avatar/Live2D/visual character layer.
