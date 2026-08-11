# Durable Chat Generation · v0.14

## Goal

A committed user message must never depend on the lifetime of one FlutterEngine for its assistant reply. Android may destroy an Activity, a foreground-service process may be reclaimed, an OEM may freeze an isolate, or a phone/tablet takeover may happen after the user turn has already been committed.

v0.14 makes the *conversation obligation* durable in SQLite before any DeepSeek request begins.

## State machine

`pending -> running -> completed`

Transient failures use `retry_wait -> running`. Ownership/transfer interruption returns the job to `pending`. Protocol/format failures that cannot be repaired by waiting become `failed`.

The user message and the initial `generation_jobs` row are created in one SQLite transaction. The assistant message, generation completion and post-turn memory queue row are also finalized in one SQLite transaction.

## Attempt ownership / run token

A job ID alone is not sufficient ownership.

A frozen old FlutterEngine can theoretically wake after its database lease has expired and after a newer engine has reclaimed the same job. To prevent that stale engine from checkpointing, failing, suspending or committing the new attempt, every claim receives a fresh `run_token`.

The current `run_token` is required by:

- partial reasoning/content checkpoints;
- attempt failure transitions;
- attempt suspension;
- final assistant commit.

A stale engine holding an old token receives zero affected rows and loses write authority. The chat lease still serializes normal engines; the run token is a second fence specifically for lease-expiry/process-freeze edge cases.

## Streaming checkpoints

Reasoning and visible content are periodically stored in `partial_reasoning` / `partial_content`. These are diagnostics/crash evidence only. They are **not** appended to chat history.

DeepSeek SSE does not provide a resume cursor, so a recovered attempt restarts generation from the same committed user turn and current durable context. Only one successfully committed final assistant message becomes history.

A stream that closes before a `[DONE]`/finish signal is treated as incomplete and retried. Partial text is never silently promoted to a completed assistant reply merely because the TCP stream ended.

## Retry policy

Transient network, credential/permission, rate-limit and server failures remain durable `retry_wait` work. Default `generation_max_attempts=0` means no attempt-count terminal limit for recoverable errors. Backoff grows from seconds to at most one hour between attempts.

This is deliberate: if the phone has no network for a night, the already-committed user turn should still be owed a reply when connectivity returns instead of becoming a permanent hole after three quick retries.

Non-recoverable request/format/state errors still fail instead of looping forever.

API keys are device-local and are not transferred. If a transferred pending job reaches a device without a key, the job is deferred without consuming a generation attempt. Saving a valid local API configuration wakes retryable jobs immediately.

## Single Active Brain / transfer

Generation recovery requires `brainWorkAllowed()` and the shared `chat_turn_lease`.

Before Nearby snapshot creation, `transfer_lock=1` blocks new brain work and the source waits for active writers, including `chat_turn_lease`, to leave. A running job that was interrupted before snapshot is imported as `pending` and its source `run_token` is cleared.

The receiver stays `active_brain=0` and transfer-frozen until takeover acknowledgement. Therefore an imported generation job cannot run before the new device actually becomes Active Brain.

## Post-turn memory

The final assistant message and a `post_turn_jobs` row are committed together when post-turn queuing is enabled. A crash immediately after visible assistant completion therefore cannot create a conversation turn that was never scheduled for local memory consolidation.

## Intentional trade-offs

Best-effort pre-generation Desire/perception pulses are not replayed after a process crash. Replaying them would risk double-applying emotion state. v0.14 prioritizes exactly-once visible conversation continuity and durable memory work over exact replay of small transient internal pulses.

The state transfer format is still a monolithic JSON snapshot. This is acceptable for the current prototype but must become table-streaming or SQLite-backup based before multi-year databases become very large.
