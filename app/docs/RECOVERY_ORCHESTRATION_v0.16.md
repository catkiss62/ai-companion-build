# Recovery Orchestration · v0.16

## Goal

v0.16 does not add another AI feature. It makes existing durable work reliably **wakeable, observable and recoverable** after Activity/Service/FlutterEngine lifecycle changes.

## Ordering

Each background cycle uses this order:

1. verify Active Brain / transfer state;
2. acquire `recovery_orchestrator_lease_until`;
3. recover at most one due durable generation;
4. process at most two post-turn jobs;
5. if inner heartbeat is due, advance local inner state;
6. only when no unanswered generation blocks the user turn, allow proactive evaluation;
7. compute next wake as the minimum of queue-due and independent inner-heartbeat due time.

The outer lease is renewed between long phases. Generation and post-turn workers still keep their own stronger run-token ownership; the orchestrator lease controls high-level scheduling, not individual durable write ownership.

## Two clocks

- **Queue clock:** can be seconds/minutes because API/network retries need prompt recovery.
- **Inner-life heartbeat:** roughly 7–24 minutes, adapted from Desire/fatigue.

They must never be conflated. A 5-second generation retry must not produce 5-second Desire ticks.

## Native wake

`OverlayBubbleService.ACTION_WAKE_BRAIN` stores a pending reason and calls the background MethodChannel. If Dart is not ready, the reason remains pending.

Dart installs its command handler and then calls `backgroundDartReady`. Native only then exposes `backgroundBrainReady=true`. A 12-second ready watchdog rebuilds an Engine that exists at the Java/Kotlin level but never gets a functioning Dart command loop.

## Terminal generation failure

Only a failed generation attached to the newest user turn, with no newer user message and no committed assistant message, is considered a blocking terminal gap.

The user can:

- retry it;
- explicitly abandon only the missing AI reply while retaining the user message.

Both operations are Active-Brain and transfer-lock guarded.

## Diagnostics

System page shows scheduler state and queue state without exposing model reasoning. Diagnostic timestamps and errors are runtime metadata and are cleared/reset on cross-device snapshot import so the receiver never impersonates the sender's scheduler history.
