import 'package:ai_companion_localfirst/core/presentation/generation_presentation_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('draft is visible while a generation has no durable assistant message', () {
    expect(
      GenerationPresentationPolicy.showDraft(
        generationActive: true,
        assistantMessageId: 'assistant-1',
        committedMessageIds: const ['user-1'],
      ),
      isTrue,
    );
  });

  test('durable commit atomically replaces the transient draft row', () {
    expect(
      GenerationPresentationPolicy.showDraft(
        generationActive: true,
        assistantMessageId: 'assistant-1',
        committedMessageIds: const ['user-1', 'assistant-1'],
      ),
      isFalse,
    );
  });

  test('inactive generation never leaves a transient draft row', () {
    expect(
      GenerationPresentationPolicy.showDraft(
        generationActive: false,
        assistantMessageId: null,
        committedMessageIds: const [],
      ),
      isFalse,
    );
  });
}
