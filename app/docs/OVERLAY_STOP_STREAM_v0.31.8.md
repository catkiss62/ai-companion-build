# Overlay Stop & Live Stream · v0.31.8+50

## Purpose

The native Android WindowManager chat panel previously disabled its nearby send
button while a turn was running. Its header “■” action only called
`stopSpeech()`, so it could never cancel DeepSeek generation. The full Flutter
chat already had a durable true-cancellation path in v0.31.7; this version makes
the overlay use that same owner and database fence.

## Interaction

- Idle composer: the nearby button says “发送”.
- Active generation: the same button says “停止” and remains tappable.
- Cancellation in progress: it briefly says “停止中” and rejects duplicate taps.
- The old header action is renamed “停语音” so its scope is no longer ambiguous.
- The optimistic user message remains visible. A cancelled turn does not leave
  a partial assistant bubble.

## Cancellation path

```text
native overlay 停止
  -> MethodChannel cancelGeneration
  -> persistent headless ChatController.cancelCurrentGeneration
  -> close current DeepSeek stream + stop TTS queue
  -> SQLite generation job = cancelled_by_user
  -> run-token/ownership fence rejects late deltas and recovery
```

A small overlay send epoch also covers a tap that arrives while the background
controller is still warming: a cancelled native request cannot proceed into a
new send after initialization finishes.

## Real live reasoning/content

The headless controller already receives provider-native
`reasoning_content` and `content` deltas. While the native panel is open it
polls a read-only generation snapshot every 140 ms and renders one transient
assistant bubble:

- actual reasoning is automatically expanded as “思考中”;
- actual answer text grows in the same bubble;
- no synthetic chain-of-thought or guessed text is generated;
- TTS continues to read answer content only;
- the transient bubble is replaced by committed SQLite history on completion,
  and removed on cancellation.

Polling only runs while the overlay panel is expanded and owns an active send.
It does not change WindowManager touch recovery, Accessibility, proactive
messaging, Prompt, Desire, Memory, behavior rules, or the Meju A2 native stack.

## Data and version boundaries

- App: v0.31.8+50
- SQLite schema: 20 (unchanged)
- No migration and no new permission
- No persisted partial assistant message
- Existing completed reasoning remains available through the overlay’s normal
  expandable “思考” control

## Device acceptance

1. Send from the overlay and tap the same nearby button during reasoning.
2. Repeat after answer text and auto TTS have started.
3. Collapse/reopen the overlay; the cancelled reply must not return.
4. Verify the user message remains and the next turn can be sent.
5. Let one turn finish and verify live reasoning/content becomes the normal
   committed message.

## Automated validation

- GitHub Actions run #18 (ID 31818910082): SUCCESS.
- Passed the v0.31.8 contract validator and every existing source/regression validator.
- Passed Flutter analyze and all Flutter tests, including the new snapshot tests.
- Built the release APK, compiling the native WindowManager/Kotlin changes.
- Verified the frozen Meju A2 native payload byte-for-byte and uploaded APK + SHA.
- Earlier runs #15-#17 stopped before compilation/APK: one new-validator wording mismatch and two historical whole-file Overlay hashes. Those hashes were replaced with explicit HyperOS input-recovery contract guards; the guards were not removed.
