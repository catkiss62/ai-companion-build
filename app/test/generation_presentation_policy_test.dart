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

  test('TTS-only notifications never request a chat scroll', () {
    expect(
      GenerationPresentationPolicy.shouldFollowChatNotification(
        followLatest: true,
        generationActive: false,
        generationEnded: false,
        streamChanged: false,
        discoveredUser: false,
        discoveredAssistant: false,
      ),
      isFalse,
    );
  });

  test('a newly committed user message always returns chat to the bottom', () {
    expect(
      GenerationPresentationPolicy.shouldFollowChatNotification(
        followLatest: false,
        generationActive: true,
        generationEnded: false,
        streamChanged: false,
        discoveredUser: true,
        discoveredAssistant: false,
      ),
      isTrue,
    );
  });

  test('real stream and commit transitions still follow latest', () {
    expect(
      GenerationPresentationPolicy.shouldFollowChatNotification(
        followLatest: true,
        generationActive: true,
        generationEnded: false,
        streamChanged: true,
        discoveredUser: false,
        discoveredAssistant: false,
      ),
      isTrue,
    );
    expect(
      GenerationPresentationPolicy.shouldFollowChatNotification(
        followLatest: true,
        generationActive: false,
        generationEnded: false,
        streamChanged: false,
        discoveredUser: false,
        discoveredAssistant: true,
      ),
      isTrue,
    );
  });
}
