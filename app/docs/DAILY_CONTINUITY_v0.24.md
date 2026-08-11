# v0.24 · Companion Continuity / Daily Reflection

## Goal

Make recent days feel connected without inventing a second diary or asking a model to narrate the relationship every night.

The canonical long-term truth sources remain:

- `memory_items` / `memory_evidence`;
- `relationship_events`;
- `unfinished_threads`;
- `thoughts`;
- `awareness_observations`;
- raw chat messages.

`daily_continuity` is only a bounded projection over those sources.

## Why this is not AI Self reflection

`AiSelfReflectionEngine` answers a private question: “what stable behavior has this AI demonstrated about herself?” It can create `ai_self` memory and a small private reflection Thought.

Daily continuity answers a different relationship-facing question: “what from the last day or two is still naturally connected to today?”

Therefore v0.24 deliberately adds **no new model call**. A deterministic local engine derives the record.

## Daily record

Each local day has at most one row:

- `local_day` UNIQUE;
- fixed local-day time window;
- up to 2 shared Relationship moments;
- at most 1 carried unfinished thread;
- at most 1 companion-facing care/Thought;
- up to 2 coarse Awareness summaries;
- message / relationship-event counts;
- `quiet_day` marker;
- deterministic source fingerprint;
- optional `finalized_at`.

The current day can be updated as real local state changes. Yesterday is finalized on the next run and is immutable afterward.

## Unfinished-thread carry

An unresolved thread can bridge into a later day, but it must not be pasted into every daily row forever.

Selection rules:

1. a thread updated during the target day may appear again because it has real new progress;
2. otherwise a thread already present in either of the two previous daily rows is skipped;
3. only one carry thread is selected per day;
4. the original `unfinished_threads` table remains authoritative.

This affects only the continuity projection; proactive follow-up remains controlled by the existing follow-up engine and rhythm gates.

## Quiet days

No RelationshipEvent / carried thread / new companion-facing care means `quiet_day=1`.

A quiet day can still have normal messages. The prompt explicitly says:

- ordinary interaction does not need to be promoted into a relationship milestone;
- no interaction does not mean closeness decreased;
- the model must not manufacture “progress” to make every day eventful.

## Prompt boundary

`PromptBuilder` injects at most the latest 2 daily rows.

The continuity section tells the model that it is:

- derived from old durable truth;
- not a new fact source;
- not an AI diary;
- not something to recite line-by-line;
- subordinate to what the user says now.

Post-turn extraction separately states that the assistant merely recalling an old continuity item is not evidence that the event happened again. This reduces recursive memory/event duplication.

## Ownership / crash semantics

`DailyContinuityEngine` uses a local lease. Before committing, `upsertDailyContinuityIfBrainOwned()` checks `active_brain` and `transfer_lock` inside the same SQLite transaction that performs the upsert.

Consequences:

- standby device cannot author rows;
- transfer freeze blocks writes;
- retrying the same day cannot create duplicate rows;
- finalized yesterday cannot be rewritten by a late retry;
- the layer is best-effort and cannot block proactive heartbeat or Memory/AI-Self maintenance if it fails.

## Scheduling

Two existing durable paths refresh it:

- post-turn maintenance: force refresh after durable extraction;
- local proactive heartbeat: periodic refresh, rate-limited to roughly 24 minutes.

No new Android alarm/worker/scheduler was introduced in this milestone.

## Retention

Long-running maintenance prunes `daily_continuity` after roughly 180 days and caps it at 220 rows.

This is intentional. Multi-year facts and shared history remain in their canonical tables; daily continuity only bridges recent lived context.

## Phone / tablet transfer

`daily_continuity` participates in the existing full-state snapshot. A v16 snapshot has no rows and imports safely. A v17 snapshot transfers the rows exactly like other local companion state.

The target Active Brain may update the current day after takeover. Historical finalized rows remain stable.
