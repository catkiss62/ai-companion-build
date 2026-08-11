# Long-running hygiene · v0.11

## Goals

The companion is expected to live on one local database for months or years. v0.11 bounds operational noise without treating relationship history as disposable cache.

## Never auto-delete

- raw `messages`;
- active/durable `memory_items` solely because the database is old;
- relationship events;
- AI Self;
- reference documents/persona source text;
- six-layer rule content.

Memory fading remains its own semantic mechanism: weak memories may become archived, not hard-deleted.

## Stale unfinished topics

`unfinished_threads` may become `retired` when they have no new evidence for a long period. Retention depends on importance:

- low importance: eligible after about 14 days;
- medium: about 45 days;
- high: about 120 days;
- importance >= 0.92: no automatic retirement.

Retirement clears deferred follow-up state and moves active Thoughts with the same `topic_key` to dormant. The historical thread row remains inspectable.

## One-shot deferred follow-up

A `deferred` response may schedule `followup_due_at` 6–72 hours later. When due:

1. one moderate Duty Thought is seeded;
2. `followup_seeded_at` prevents repeated heartbeat reinforcement;
3. `followup_count` is incremented only if a proactive message is actually sent;
4. default `max_deferred_followups=1` prevents reminder loops.

A real user conversation touching the topic cancels the old schedule. Resolved/dismissed topics clear it completely.

## Durable post-turn jobs

`post_turn_jobs` makes memory extraction recoverable. A job references already-committed user/assistant message IDs. A failed job keeps a compact error and retries later, up to a bounded attempt count. Background heartbeat can drain this queue even when no new chat arrives.

The queue does not run while `transfer_lock=1` or the device is not Active Brain.

## Concurrency

v0.11 treats the full app, floating chat and background FlutterEngine as independent writers:

- leases use owner tokens (`token|expires_at`), compare ownership on release, and refuse same-isolate re-acquisition while an older task still logically owns the lease;
- long chat/proactive streams renew their token before TTL expiry; if ownership has already moved, generation is cancelled rather than writing with stale authority;
- chat turns use `chat_turn_lease`;
- post-turn extraction, relationship assimilation, memory maintenance, thought consolidation and AI Self reflection each have dedicated leases;
- Desire JSON uses an atomic SQLite transaction for read/modify/write;
- proactive message eligibility and message INSERT share a final SQLite transaction so live user chat wins the race cleanly;
- receiver-side import also freezes and drains old writers before replacing local state.

## Diagnostics pruning

The maintenance engine can cap/age out operational diagnostics such as lifecycle events, proactive feedback/history, perception snapshots, device events and completed post-turn jobs. The goal is bounded operational metadata, not relationship amnesia.
