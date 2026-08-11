# Relationship / Inner-state Companion Presentation · v0.21

## Goal

v0.21 does **not** add a love meter or a second relationship state machine. It projects the existing durable Relationship, Thought, unfinished-thread and temporary Session truth sources into a daily companion-facing surface.

The user should be able to feel that the relationship has continuity without seeing `strength`, `drive`, `baseline`, event `intensity` or `valence` as game stats.

## Three visible layers

### 1. What she still cares about

`currentThoughtsForPresentation()` first applies active/fixation + non-snoozed bounds in SQLite, then `RelationshipPresentation.currentCares()` keeps only a few companion-facing, still-actionable themes. This prevents a multi-year residual/acted pool from crowding current cares out of the read limit.

It excludes:

- perception/awareness Thoughts;
- AI-self reflection maintenance Thoughts;
- snoozed Thoughts;
- dormant/residual/non-driving Thoughts.

It accepts relationship-derived Thoughts, conversation-turn Thoughts, self-drive memory/thread Thoughts and deferred follow-up themes. Topic keys are used to suppress duplicate display themes.

Mechanical prefixes such as “我自己又想起了一条长期记忆” are removed for presentation only. The durable Thought text in SQLite is not rewritten.

### 2. Shared history

`RelationshipEvent` remains the factual source of truth. The daily page shows only:

- a natural event-kind label;
- the durable event summary;
- the date.

Internal `intensity` and `valence` are not shown on the daily surface. They remain available under Advanced/Diagnostics for development and tuning.

### 3. Temporary interaction

The active `InteractionSession` is displayed separately from long-term relationship history. Ending it returns to the normal AI-companion reality layer; it never overwrites AI Self.

## Standby-device rule

The phone/tablet Active Brain model still applies. On a standby or transfer-locked device, the relationship page explicitly says that current Thoughts/Session may be stale and labels current-care content as the **last synchronized** state. Durable shared history remains viewable.

## Home integration

Companion Home no longer displays the latest arbitrary Thought as relationship presence. It uses the same filtered `CompanionCareView`, so transient device-awareness Thoughts do not masquerade as relationship growth.

Home also surfaces one recent shared RelationshipEvent as “你们最近留下的”, linking to the full relationship page. If that event is the same text as the current care, Home skips it and tries the next recent moment rather than showing the same event twice.

## Storage boundary

- no schema migration;
- schema remains 14;
- no new relationship score;
- no duplicate UI-only persistence;
- all presentation is derived from existing local truth sources.
