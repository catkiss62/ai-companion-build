# Long-term Memory Consolidation / Conflict Semantics · v0.22

## Goal

Keep the companion's local memory useful after months/years without destructive summarization or cloud/vector dependencies.

## Truth semantics

`memory_items.semantic_type`:

- `current_fact`: confirmed current profile/preference/AI-Self truth;
- `inference`: tentative interpretation;
- `shared_experience`: durable event-like shared experience.

A `current_fact` that is replaced remains in `memory_items` as `status=superseded`. This is the historical-fact layer. `superseded_by` links the old row forward and `fact_version` gives same-subject versions a monotonic local number.

## Evidence chain

`memory_evidence` stores later supporting wording without creating a new top-level memory row:

- `memory_id`
- `source`
- `evidence_text`
- `confidence`
- `relation` (`created`, `reinforced`, `replaced`, `manual_edit`)
- `observed_at`

`UNIQUE(memory_id, source, evidence_text)` fences durable post-turn retries.

## Extractor contract

The post-turn extractor sees only a bounded set of relevant existing memories and can emit:

- `append`: new independent memory;
- `reinforce`: same meaning / new evidence, with `target_id`;
- `replace`: confirmed same-subject truth changed, with `target_id` + stable `subject_key`.

SQLite remains authoritative:

- confidence below 0.68 cannot become an automatic current fact;
- inference never auto-replaces a current fact;
- shared experience never enters profile replacement semantics;
- same-subject pinned rows block automatic replacement;
- invalid reinforce targets must match kind plus subject or sufficient local wording overlap.

## Retrieval

Normal stable profile / preference / AI Self queries select active `current_fact` only.

Topic retrieval is split into:

1. confirmed facts + shared experiences;
2. at most three relevant active inferences, explicitly labeled uncertain;
3. at most three relevant superseded current facts, explicitly labeled historical.

Historical/inference retrieval does not silently strengthen the row's recall score.

## Self-drive and AI Self

Self-drive memory seeding excludes inference so a tentative guess cannot become an inner Thought phrased as established truth.

AI Self reflection uses the same `append/reinforce/replace` semantics and sees ids/evidence/PINNED state for existing AI Self facts.

## Retention

Confirmed memories keep the existing long half-lives. Repeated evidence increases durability modestly. Inferences use a shorter semantic multiplier and a 75-day minimum archive age, so weak guesses do not occupy the active truth layer forever.

## Migration / transfer

v14 -> v15 adds columns and `memory_evidence` without deleting rows. Old `shared_experience` rows are explicitly classified; other old active/superseded memories default to `current_fact`. First/last evidence timestamps are backfilled from existing created/updated timestamps.

v14 state packages import into v15 with the same defaults. v15 exports/imports include `memory_evidence` and remain full-state transactional.
