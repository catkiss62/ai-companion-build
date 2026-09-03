import 'package:ai_companion_localfirst/core/presentation/generation_presentation_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('draft stays visible before durable assistant commit', () {
    expect(
      GenerationPresentationPolicy.showDraft(
        generationActive: true,
        assistantMessageId: 'assistant-1',
        committedMessageIds: const ['user-1'],
      ),
      isTrue,
    );
  });

  test('durable assistant atomically replaces transient draft', () {
    expect(
      GenerationPresentationPolicy.showDraft(
        generationActive: true,
        assistantMessageId: 'assistant-1',
        committedMessageIds: const ['user-1', 'assistant-1'],
      ),
      isFalse,
    );
  });

  test('inactive generation never renders a draft', () {
    expect(
      GenerationPresentationPolicy.showDraft(
        generationActive: false,
        assistantMessageId: null,
        committedMessageIds: const [],
      ),
      isFalse,
    );
  });

  test('durable answer waits for post-turn work before typewriter starts', () {
    expect(
      GenerationPresentationPolicy.typewriterPlaybackReady(
        animateRequested: true,
        generationActive: true,
      ),
      isFalse,
    );
    expect(
      GenerationPresentationPolicy.typewriterPlaybackReady(
        animateRequested: true,
        generationActive: false,
      ),
      isTrue,
    );
  });

  test('presentation cursor is not consumed before typewriter finishes', () {
    expect(
      GenerationPresentationPolicy.markPresentedOnDiscovery(
        typewriterEnabled: true,
      ),
      isFalse,
    );
    expect(
      GenerationPresentationPolicy.markPresentedOnDiscovery(
        typewriterEnabled: false,
      ),
      isTrue,
    );
  });
}
