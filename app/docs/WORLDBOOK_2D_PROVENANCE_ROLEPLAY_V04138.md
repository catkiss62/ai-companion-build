# WorldBook 2D provenance and roleplay boundary (v0.41.38)

## Runtime truth

- A world-book document being created, edited, enabled or disabled is configuration, not a lived event. It must not create Memory, Thought, Relationship or an AI-visible statement that her personality changed.
- Every committed ordinary/proactive assistant message carries a bounded snapshot of the active world-book document IDs, entry types and `updated_at` versions. The snapshot is machine-only provenance.
- `knowledge` is retrieved data, `behavior` is an expression seed, and `roleplay` is a temporary execution context. These types never silently promote into one another.
- A response that consulted `knowledge` cannot become AI Self evidence. Ordinary Memory from that turn additionally needs an exact quote from the current real user message, so a character biography cannot be re-described as lived experience.

## Non-destructive migration

- Existing `builtin.worldbook.special.*` rows become `entry_type=roleplay`, keep their stable IDs and full prompt bodies, and remain manually activated.
- Existing ordinary personality, relationship-posture, daily-conversation and custom behavior rows remain behavior modules.
- Existing knowledge documents, Memory/evidence/message IDs and legacy special-style tables are not rewritten or deleted.
- Schema 49 backups receive empty provenance for historical messages. No historical source is guessed.

## Growth gates

- A behavior module may influence a real response, but module activation itself has zero evidence weight.
- User preference and relationship permission continue to require a verbatim real-user quote.
- Autonomous AI Self proposals must cite real committed assistant message IDs. Roleplay-sourced messages are rejected. A single response or single reflection can create no current fact.
- Candidate evidence must span at least three independent assistant messages and at least two time buckets. Stronger promotion additionally requires cross-day evidence.
- Disabling a module stops direct prompt injection. Source-linked weak observations can fade; already independent, cross-context behavior is not automatically erased.

## Roleplay boundary

- Activating a roleplay document opens one source-bound InteractionSession; activating another ends the old session. Disabling the active document ends its live state without creating a personality-change memory; reopening the same card reuses its bounded local continuity tail. Deleting the card ends the source session.
- Roleplay turns do not write ordinary Memory, Thought, unfinished Thread, Relationship growth or ordinary personality evidence. Their visible chat history and source-bound Session remain available for continuity.
- AI Self reflection does not run while a roleplay Session is active and excludes roleplay-sourced messages from later evidence.

## Fixed acceptance samples

1. Enabling a behavior document without a committed response creates no growth evidence.
2. One behavior-shaped response cannot become AI Self.
3. Three cited non-roleplay responses across independent time buckets may form an inference; cross-day evidence is required for a current fact.
4. User explicit preference still enters the existing ordinary learning lane and retains the eliciting world-book provenance through the assistant message.
5. Enabling a roleplay document opens a source-bound Session; switching/end closes it.
6. Roleplay output cannot create ordinary Memory/Thought/Thread/Relationship/AI Self.
7. Schema 49 import preserves old rows and assigns no invented historical provenance.
8. A leading `<em>平静</em>` is recovered as calm and removed from visible/TTS text; ordinary HTML emphasis elsewhere remains visible.
9. A knowledge-grounded answer cannot prove AI Self, and its ordinary Memory requires a verbatim current-user evidence quote.
10. Reopening one roleplay card can resume its own bounded tail; switching cards cannot read the previous card's roleplay turns.
