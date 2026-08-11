# v0.17 · Proactive Experience Layer

## 1. Why this layer exists

Before v0.17, proactive contact already had Desire/Thought causes, a gate, topic continuity and response-outcome learning. The user-facing result was still too uniform: one outbound message looked much like another regardless of whether the underlying cause was longing, curiosity, an unfinished thread or a low-pressure thought.

v0.17 separates three concepts that must not be collapsed:

1. **Desire/Thought cause** — why she wants contact.
2. **Proactive intent** — what kind of social act the outbound message is.
3. **Delivery style** — how strongly that act should interrupt right now.

The model writes the final wording, but it does not decide these structural labels. Classification remains local and deterministic so memory, notification behavior and adaptation cannot drift merely because a model described itself differently.

## 2. Intent mapping

Current mapping:

| Drive / state | Proactive intent |
|---|---|
| attachment | `miss_you` |
| curiosity | `curiosity` |
| reflection | `share_thought` |
| duty | `followup` |
| social | `social_share` |
| libido | `intimacy_invitation` |
| stress | `emotional_reach` |
| fatigue | `gentle_ping` |
| linked unfinished thread | `followup` |

A linked unfinished thread wins over drive classification because the actionable social meaning is “continue that thread.”

`intimacy_invitation` is still an invitation. It does not itself establish an Intimacy Session, and the prompt explicitly avoids forcing an ordinary chat directly into a full adult scene.

## 3. Delivery selection

`quiet` is selected when device context says the user is busy or intent/topic history suggests low-pressure contact. This is presentation, not censorship of the drive.

`warm` is used for `miss_you`, `intimacy_invitation` and `emotional_reach` when no low-pressure condition is active.

Everything else defaults to `normal`.

Android notification routing follows the style:

- `quiet` → low-importance `companion_messages_gentle` channel;
- `normal` / `warm` → ordinary companion-message channel.

## 4. Intent-aware adaptation

`ProactiveRhythmEngine` now combines:

- global response history;
- current topic history;
- current intent-class history.

A few deferred/no-response outcomes for `followup`, for example, can make future follow-ups softer without teaching the entire companion that all proactive contact is unwelcome. `dismissed` has the strongest positive threshold adjustment; `engaged/resolved` gently reduces it.

The adjustment is intentionally small and clamped. This is still companionship, not optimization for engagement metrics.

## 5. Notification privacy

The privacy setting controls notification presentation only:

### Smart

- ordinary proactive body may be shown;
- `intimacy_invitation` uses a neutral preview;
- any proactive message produced while an intimacy-type Session is active also uses a neutral preview.

### Full

Always use the actual outbound text in the notification.

### Private

Always use an intent-specific neutral preview.

The real SQLite message stays untouched in all modes.

## 6. Inline reply path

Path:

```text
Android notification RemoteInput
        ↓
CompanionReplyReceiver
        ↓
OverlayBubbleService
        ↓
ai_companion/background_commands
        ↓
BackgroundChatCommandServer.notificationReply
        ↓
ChatController.sendText(requestedMessageId: stableReplyId)
        ↓
createGenerationTurn transaction
        ↓
DurableGeneration + Memory + Relationship + Desire
```

The receiver is deliberately thin. It never writes the companion brain directly.

### Idempotency

A quick reply is assigned a stable user-message ID before the service handoff. `ChatController` checks whether that ID already exists. If native service intent redelivery or MethodChannel retry happens after SQLite already committed the user turn, the command reloads/recovery-schedules rather than inserting another message.

### Short contention recovery

If the persistent controller is temporarily busy, the native queue retries with bounded delays. Failure is written as a native device event rather than silently disappearing.

## 7. Migration behavior

Schema v13 adds intent/delivery metadata. Old feedback is backfilled conservatively from:

1. linked unfinished thread;
2. originating Thought drive;
3. `gentle_ping` fallback.

Existing proactive messages inherit their feedback category when available. Old imported state packages run the same reconstruction after all message/thought/feedback tables have been restored.

## 8. Deliberate boundaries

- No per-intent user toggle matrix yet. The first goal is natural differentiated behavior, not turning the relationship into a notification rules dashboard.
- No new role/persona behavior is tied to intent categories.
- Notification reply still depends on the existing persistent companion Service architecture; Android/OEM real-device behavior remains a later APK checkpoint.
- TTS reads the actual companion message, not a privacy-sanitized notification preview.
