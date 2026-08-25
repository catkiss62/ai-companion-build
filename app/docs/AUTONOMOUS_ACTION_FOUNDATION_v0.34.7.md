# v0.34.7 · Autonomous Action Foundation

## Scope

This release adds the durable common execution contract for later public-web,
screen-observation, and video-understanding Providers. It does not schedule a
real external Provider yet and therefore cannot claim that the companion has
searched, read, watched, or observed anything.

The only motivation source remains the existing chain:

```text
bounded real evidence
  → Perception / Somatic / Thought / AI Self
  → Desire
  → DesireIntent
  → Tool Gate
  → durable Action
  → real Outcome
  → light satisfy / feedback / refractory
```

Proactive contact remains a separate delivery Gate. A successful search may
eventually store a candidate while the companion stays silent.

## Durable run contract

Schema v24 adds `autonomous_action_runs`. A run stores only execution metadata:

- tool class, existing Intent action, Drive key and bounded score;
- provenance category and optional Thought identifier, never Thought text;
- hashed dedupe key;
- requested/running/terminal state, Gate reason and coarse Outcome;
- Active Brain generation/device ownership, run token and attempt;
- lock/interactive booleans, coarse latency bucket and result count;
- budget limit/remaining and duplicate count.

It never stores a query, URL, webpage body, screenshot content, account data,
notification/accessibility text, chat body, Thought body, or provider payload.

## Ownership and idempotency

- Request records are bound to the current state generation and device.
- Claim requires Active Brain, no transfer lock, matching generation/device,
  `requested` state, and a non-empty run token.
- Terminal commit requires the same run token and ownership epoch.
- Only `succeeded + candidate_stored/observation_stored + resultCount > 0`
  may invoke the Desire feedback callback.
- Action terminal state and Desire JSON are committed in one SQLite
  transaction. Failure, cancellation, no result, duplicate, stale writer, or
  recovery cannot generate satisfy.

## Tool Gate

The pure policy checks:

- Active Brain and transfer lock;
- concurrent durable generation;
- active dedupe key;
- Provider availability;
- live-screen lock/interactivity/sensitive-surface restrictions;
- the tool's independent rolling budget.

Locking the phone blocks only `screen_observation`. Quiet `public_web` work and
later candidate media analysis remain eligible. This preserves the agreed rule
that screen-off pauses looking at the current screen, not autonomous internet
work.

The first fixed budget is screen observation: at most six allowed requests in
a rolling hour. Public-web and video budgets remain explicitly unconfigured
until their Providers are designed, avoiding invented limits. Existing
proactive contact caps remain 2 per 2 hours and 8 per 24 hours under their own
delivery Gate.

## Redacted diagnostics

The report now contains `database.autonomousActions`:

- counts by terminal/running state and tool class;
- last tool class, state, Gate reason, Outcome, timestamps, latency bucket,
  result count, lock/interactivity, budget and dedupe count;
- screen-observation rolling budget;
- existing proactive-contact budget shown separately;
- explicit privacy markers proving content/query/URL/account fields are absent.

In v0.34.7 the phase is `foundation_not_scheduled`. A fresh install should show
zero action runs and a passing foundation check. Real request/success counters
begin only when the first Provider is connected in a later release.

## Automated validation

- pure Tool Gate tests cover ownership, transfer, generation, lock-screen,
  sensitive surface, Provider availability, dedupe, budget and latency buckets;
- static validator locks schema, run-token fencing, success-only Desire
  feedback, privacy markers, separate delivery Gate, APK identity, and the
  existing v0.34.6 lock-resume guardrail;
- the full historical validator, Flutter analyze/test, Kotlin pet tests, APK
  payload checks and draft Release workflow remain required.
