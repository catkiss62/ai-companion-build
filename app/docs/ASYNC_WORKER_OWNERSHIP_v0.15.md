# v0.15 Async Worker Ownership

## Threat model

The app can have a full-app FlutterEngine, a headless foreground-service engine and Android/native callbacks. An engine can be suspended long enough for a SQLite lease TTL to expire, while another engine reclaims the work. The old engine may later resume.

A lease alone is therefore not enough for critical multi-step work.

## Ownership tiers

### Tier A · durable attempt token

Used by `post_turn_jobs`.

Each claimed attempt gets a new `run_token`. Checkpoint/fail/done operations require `status=running AND run_token=?`. A reclaimed attempt invalidates the old token.

### Tier B · atomic exactly-once marker

Used for effects that must not be replayed from a cached post-turn proposal:

- post-turn Desire pulses (`desire_applied_at`)
- post-turn Thought evidence (`post_turn_evidence` lifecycle record)
- proactive Thought response outcome (response-message-keyed Thought mutation + lifecycle record)
- proactive unfinished-thread outcome (`proactive_outcome_message_id`)
- Relationship assimilation (`internalized_at`)
- Deferred follow-up seed (`followup_run_token` + `followup_seeded_at`)

The effect and marker are committed in the same SQLite transaction.

### Tier C · optimistic maintenance

Used when stale work should simply be skipped:

- memory fading compares retention/source timestamp
- unfinished-thread retirement compares `updated_at`
- Thought lifecycle compares `updated_at`
- Thought consolidation revalidates all candidates before merge

### Tier D · lease + repeated ownership checks

Used for low-stakes autonomous work such as Self Drive / AI Self maintenance. These paths repeatedly verify Active Brain and lease ownership around meaningful writes. AI Self additionally uses stable run-slot source IDs to make replay less harmful.

## Summary consolidation

Summary generation uses `conversation_summary_lease_until`. SQLite also enforces a unique `(from_at,to_at)` range. The unique range is the final safety net if an old model request resumes after its lease was reclaimed.

## Transfer

`transfer_lock=1` prevents new autonomous work. Transfer waits for all known writer leases, including summary consolidation, before exporting/importing. Runtime lease settings are cleared in the imported snapshot and the receiver stays standby until Active Brain takeover is acknowledged.
