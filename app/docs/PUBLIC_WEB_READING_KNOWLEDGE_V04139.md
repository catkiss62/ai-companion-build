# Public Web Reading, Knowledge and Lifecycle — v0.41.39

Status: frozen contract; implemented locally on 2026-09-05, CI pending.

## Purpose

Replace the snippet-only public-web path with a truthful reading path while preserving the existing autonomy gate:

`Desire → Thought → Intent → Gate → Search → Extract → Summarize → Appraise → Projection`

Search discovers a URL. It is not evidence that the page was read. A browser visit is only created after a successful extract and a usable summary.

## Provider contract

1. Tavily Search remains the primary discovery provider and Wikimedia remains the empty-result fallback.
2. Tavily Extract receives URLs returned by Search and reuses the existing Tavily API key. No URL allowlist or new credential is required.
3. All readable extracted text is passed through Agnes. Oversized pages must be chunked and merged; silently reading only the opening snippet is forbidden.
4. Agnes receives public page content and public metadata only. It must not receive chat history, Memory, AI Self, relationship data, private phone content or credentials.
5. Agnes returns two projections:
   - a concise reader summary suitable for the simulated browser;
   - structured key points, uncertainties and topic tags suitable for the main-model appraisal.
6. DeepSeek appraises the summarized page against the actual search purpose. It returns semantic validity, interest value, learning value, share value and a short reason. A deterministic local policy validates and bounds this output.
7. Search, Extract, Agnes and DeepSeek each keep their own terminal status. One stage must not claim another stage succeeded.

## Semantic states

| State | Meaning | Browser | Knowledge | Share |
|---|---|---:|---:|---:|
| `valid` | Readable page and meaningfully related to the search purpose | yes | score-gated | score-gated |
| `history_only` | Valid and truthful, but not useful enough to learn or share | yes | no | no |
| `mismatch` | Page content does not match the query or selected result | no | no | no |
| `garbled` | Extracted/summary content is semantically broken | no | no | no |
| `unreadable` | Extract failed or no usable body exists | no | no | no |
| `unsafe` | Local safety policy rejects the content | no | no | no |
| `legacy_unverified` | Imported pre-v0.41.39 snippet-only record | visible with label | no | no |

“Boring” is not an error. A readable but low-value page remains a real browser visit.

## Persistence contract

Schema 51 is a non-destructive upgrade from schema 50.

- Existing candidate and browser IDs remain unchanged.
- Existing snippet-only rows become `legacy_unverified`; their old summaries remain visible but are excluded from prompt/share/knowledge queries.
- Verified candidates store reader summary, key points, uncertainties, topic tags, read time, semantic state, appraisal scores/reason and content fingerprint. Raw page bodies are not persisted.
- A source-backed knowledge projection keeps candidate ID, URL/domain, summary/key points, read time and lifecycle state. It is retrieval data, not Memory, AI Self, relationship evidence or model-weight training.
- Browser rows describe what was actually read. Knowledge rows describe what may be useful later. Share lifecycle describes whether the assistant wants to tell the user. They remain independently queryable.
- User deletion hides the browser row and transactionally revokes candidate, knowledge and unacted Thought use. A minimal fingerprint tombstone remains for bounded rediscovery suppression.

## Interest boundary

Topic tags and repeated verified browser events form an interface for Phase 3A. v0.41.39 must not mature or consume permanent `ai_interest` records from a single page. Existing Desire/Thought/Intent/Gate logic remains authoritative for autonomous actions.

## Budget contract

- Autonomous discovery default: at most 6 discovery runs in a rolling 24-hour window. This is an app-side run budget, not a promise about Tavily's provider-side credit accounting.
- Adaptive ceiling: 8 only when recent runs produced distinct, semantically valid results and a current curiosity drive still bids.
- Explicit user search and share-time re-extract use separate bounded budgets.
- Same-topic cooldown, URL/fingerprint deduplication and one external action per heartbeat remain in force.

## Share freshness

Before a candidate is actually shared, the original URL must be re-extracted. DeepSeek receives current source content/summary and decides how to express it. A stale summary alone cannot produce an operational claim that the page was just checked.

## Narrow companion fixes

### Roleplay

Permanent identity and growth remain isolated, but an enabled roleplay card has explicit scene-local authority over identity, species, body and personality. The model must know that it is in roleplay and answer scene-local identity questions from the active card. Ending the session restores the normal whale identity.

### Image save

Natural save-image requests must route to the image tool. Tavily image candidates are not accepted by position alone. Qwen must inspect actual pixels and return whether the image matches the requested subject/style; mismatch, logo-only, tiny placeholder and unsafe images are rejected before album persistence.

### Album time

Album list/detail views show the persisted creation/save time using the device-local display timezone. No synthetic time is generated.

## Acceptance samples

1. Tavily returns a valid landscape page; Extract and Agnes succeed; browser history shows a readable summary and URL/time; low learning/share scores do not remove the visit.
2. Tavily returns an unrelated logo page for an anime-image request; Qwen describes it but reports request mismatch; no album row/file is committed.
3. Extract fails; no browser/knowledge/share success is recorded, and the terminal reason names Extract.
4. Agnes fails after Extract; no “read successfully” browser entry is created, and original search snippets are not promoted.
5. DeepSeek returns malformed JSON; local validation produces a conservative history-only or rejection result without crashing or fabricating scores.
6. Schema 50 fixture upgrades to 51 with old IDs intact and old web rows labelled `legacy_unverified`.
7. User deletes one browser item; it disappears from the phone and its candidate/knowledge/unacted Thought cannot be retrieved, while the fingerprint tombstone blocks immediate rediscovery.
8. Active slime roleplay answers that it is a slime in the current scene; ending roleplay restores normal identity; neither turn creates normal growth evidence.
9. “存一张二次元图” deterministically reaches image search/save; a visually matching illustration saves; a news logo is rejected.
10. Album list/detail displays the persisted timestamp and survives snapshot export/import unchanged.

## Explicit exclusions

No `album.send`, mature-interest activation, complete user-style imitation, MCP management, code Harness, raw page archive, private-content summarization or main-branch merge is part of v0.41.39.
