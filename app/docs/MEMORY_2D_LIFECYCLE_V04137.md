# Memory 2D lifecycle and recall value (v0.41.37)

## Why this exists

Memory importance and memory recall value are different. A project fact may be
important when answering a direct question while still being a poor topic for
the companion to raise on her own. Conversely, a finished shared experience
may no longer be actionable but may remain a natural reminiscence.

The v49 database therefore keeps three independent decisions:

| Dimension | Values | Meaning |
| --- | --- | --- |
| Fact state | `stable`, `ongoing`, `completed`, `cancelled`, `unknown` | What is true about the event or fact |
| Attention state | `active`, `snoozed`, `closed` | Whether it currently deserves follow-up attention |
| Recall policy | `contextual`, `reminiscence`, `identity`, `followup` | Which retrieval lane may use it |

`spontaneous_salience` is a separate 0–1 score. Only closed memories marked
`reminiscence` or `identity` with salience at least 0.68 can seed autonomous
memory reflection. Ordinary user-turn and immersive retrieval remain
contextual, so relevant work facts can still answer direct questions.

## Migration contract

- Schema 48 backups import unchanged raw messages, memories, evidence and IDs.
- New lifecycle columns are derived locally and carry their derivation source.
- A direct user reply attached to the exact proactive thread can repair an old
  thread outcome. “已经做好了” resolves it; “不做了” dismisses it.
- Completion closes only the exact thread/topic lane, settles related thoughts,
  discards pending self-review envelopes and converts ongoing/scheduled memory
  state to completed/cancelled. It does not delete history.
- “还没做好” and “以后再弄” never become completion.
- A user report that an App/model capability is complete remains user-provided
  evidence; migration does not claim independent system verification.
- Re-running upgrade/import is idempotent because only active threads and
  `legacy_unclassified` memories are reconciled.

## Frozen acceptance samples

| Input/evidence | Expected result |
| --- | --- |
| “已经做好了，你忘了吗” replying to a proactive thread | Exact thread `resolved`; associated ongoing memory `completed/closed/contextual`; related thought dormant |
| “还没做好” | Not completed; no false resolution |
| “以后再弄” | Deferred/snoozed; not completed or cancelled |
| “不做了” | Exact thread dismissed; ongoing memory cancelled and closed |
| Routine database maintenance, importance 0.95 | Contextual only; spontaneous salience 0 |
| “我们一起完成了 AI 的 Live2D 呆毛设计”, important shared event | Completed/closed and eligible for reminiscence |
| Model proposes `followup` without a live thread | Downgraded to contextual/snoozed |
| A memory is injected into a prompt | Recall cursor/count update, but retention does not increase |

## Non-goals

This increment does not add album multi-select labels, `album.send`, star-map
UI, Phase 3 interest-source work, or changes to persona/intimacy/desire rules.
