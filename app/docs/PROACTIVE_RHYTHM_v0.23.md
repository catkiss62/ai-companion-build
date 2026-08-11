# v0.23 · Proactive Rhythm Learning / Local Feedback

## Goal

Let proactive contact gradually adapt to the real relationship without teaching the companion to become silent after a few missed messages.

## Two feedback dimensions

Proactive outcomes now separate **timing fit** from **topic fit**.

- `timing_fit`: was this a suitable moment to contact the user?
- `topic_fit`: was the subject / approach welcome?

`deferred` is strong timing caution but almost neutral topic evidence. `dismissed` / `redirected` primarily affect topic fit unless the model explicitly sees timing language. `no_response` is deliberately only weak timing evidence and zero topic evidence.

## Local context

Each proactive feedback row stores only coarse local context:

- daypart: late night / morning / afternoon / evening;
- coarse activity category from the existing Awareness layer;
- bounded busy score.

No raw package name, notification text or Accessibility text is added to proactive learning.

## Bounded learning

The profile uses recent bounded samples, neutral priors and a 45-day half-life. Hour, activity, topic and intent adjustments are independently clamped before a final bounded threshold adjustment. A short negative streak therefore cannot make a large personality change.

The adaptation switch changes only learned rhythm. User responses still bind to proactive messages so Thought lifecycle, unfinished-thread continuation and post-turn relationship semantics remain intact.

## Anti-silence / anti-spam

- no-response is weak timing evidence, not topic rejection;
- learned caution has a hard ceiling;
- after a long quiet interval the gate receives a small recovery relief;
- busy state remains a soft multiplier rather than a mute switch;
- hard spam ceilings prevent more than 2 proactive sends in 2 hours or 8 in 24 hours.

## Device continuity

The extra fields live in SQLite `proactive_feedback`, are exported/imported with the existing full local state and therefore move with the same phone/tablet Active Brain state. Only the Active Brain evaluates/sends proactive contact.

## Database

Schema **v16** adds to `proactive_feedback`:

- `context_hour_bucket`
- `context_activity`
- `context_busy`
- `timing_fit`
- `topic_fit`

v15 rows receive neutral context defaults. Existing proactive history and relationship data are preserved.
