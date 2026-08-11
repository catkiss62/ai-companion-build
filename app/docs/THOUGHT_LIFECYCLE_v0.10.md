# Thought Lifecycle · v0.10

## Stable topics

A Thought may carry a stable `topic_key`. The same key is reused by related unfinished threads, proactive feedback and meaningful relationship events. This lets wording evolve without creating a new durable Thought every turn.

Text-only merging remains deliberately conservative. Exact topic keys are the preferred semantic identity.

## Lifecycle

`active/flit -> fixation -> acted -> residual -> dormant -> resurfaced`

The v0.10 response loop refines the `acted -> residual` phase:

1. A proactive message is sent and linked to its source Thought/topic/thread.
2. The first real user reply immediately releases the waiting state (`response_received`).
3. The post-turn experience extractor classifies the semantic result:
   - `engaged`: continue discussing; partial satisfaction.
   - `acknowledged`: message received, topic still has residue.
   - `deferred`: keep the topic but snooze it locally for several hours.
   - `resolved`: strongly satisfy it; usually resolve its unfinished thread.
   - `dismissed`: sink/snooze the Thought and dismiss the linked thread.
   - `redirected`: keep a trace but lower near-term pressure.
4. Resurfacing remains bounded and respects `snoozed_until`.

## Long-term consolidation

`ThoughtConsolidationEngine` runs locally at most once per six hours by default.

- same drive + same nonempty `topic_key`: merge;
- no topic key: merge only at very high lexical similarity;
- different drives never merge automatically;
- proactive feedback and lifecycle audit rows are reassigned to the surviving Thought;
- merged history is counted in `merged_count`.

Every ordinary user sentence is no longer automatically promoted to a durable Thought. Meaningful themes are promoted by the structured experience extractor or real local events. This is the main protection against a Thought pool that grows without bound over months or years.
