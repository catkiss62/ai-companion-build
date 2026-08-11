# Thought Lifecycle · v0.9

## States

- `active`: ordinary flit capable of influencing intent.
- `fixation`: repeatedly reinforced/high-strength thought.
- `acted`: the thought produced an outbound proactive action and is waiting for feedback.
- `residual`: partial satisfaction or unanswered residue. It does not immediately drive another outbound action.
- `dormant`: background trace retained locally rather than deleted.

## Transitions

`flit -> fixation`: repeated feeding (`fed_count`) or high strength.

`fixation/active -> acted`: a proactive message is actually sent from that thought.

`acted -> residual`: user responds, or the response window expires.

`residual -> dormant`: residual strength decays below the background threshold.

`residual/dormant -> active`: bounded low-frequency resurfacing. A thought can only be resurfaced a limited number of times without new evidence.

A newly repeated real experience can directly re-feed an older dormant thought and make it active again.

## Satisfaction

Sending a message releases only part of the originating Drive tension. A later user response resolves `proactive_feedback` and applies stronger thought satisfaction based on reply latency/length. The model never sees the numeric learning profile unless developer diagnostics explicitly show it.

## Anti-spam behavior

An `acted` thought waits for a response window and cannot immediately compete as a fresh outbound intent. If ignored, it becomes residual first. Busy state remains a soft gate multiplier rather than a mute switch.
