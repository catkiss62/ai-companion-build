import 'dart:async';

import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/reasoning_translation.dart';
import 'package:ai_companion_localfirst/widgets/reasoning_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTranslationGateway implements ReasoningTranslationGateway {
  _FakeTranslationGateway({
    this.result = '这是一段忠实的中文翻译。',
    this.failure,
  });

  final String result;
  final Object? failure;
  int calls = 0;
  String lastSource = '';
  bool closed = false;

  @override
  Future<String> translate(
    String reasoning, {
    required GenerationCancellationToken cancellationToken,
  }) async {
    calls++;
    lastSource = reasoning;
    if (failure != null) throw failure!;
    return result;
  }

  @override
  void close() => closed = true;
}

class _PendingTranslationGateway implements ReasoningTranslationGateway {
  final started = Completer<void>();
  GenerationCancellationToken? token;
  bool closed = false;

  @override
  Future<String> translate(
    String reasoning, {
    required GenerationCancellationToken cancellationToken,
  }) async {
    token = cancellationToken;
    started.complete();
    await cancellationToken.whenCancelled;
    cancellationToken.throwIfCancelled();
    return '';
  }

  @override
  void close() => closed = true;
}

class _FlakyTranslationGateway implements ReasoningTranslationGateway {
  int calls = 0;

  @override
  Future<String> translate(
    String reasoning, {
    required GenerationCancellationToken cancellationToken,
  }) async {
    calls++;
    if (calls == 1) throw StateError('temporary failure');
    return '重试后的中文翻译。';
  }

  @override
  void close() {}
}

const englishReasoning =
    'I should inspect what he really meant and decide why this makes me feel unexpectedly shy.';

void main() {
  test('translation request sends only the source and a fixed tool contract', () {
    final messages =
        DeepSeekReasoningTranslationGateway.requestMessages(englishReasoning);
    expect(messages, hasLength(2));
    expect(messages.first['role'], 'system');
    expect(messages.first['content'], contains('不解释、总结、润色、补写'));
    expect(messages.last, {'role': 'user', 'content': englishReasoning});
    final serialized = messages.first['content'] as String;
    expect(serialized, isNot(contains('长期记忆')));
    expect(serialized, isNot(contains('关系历史')));
  });

  test('translation is manual, cached for the page lifetime and toggleable', () async {
    final gateway = _FakeTranslationGateway();
    final coordinator = ReasoningTranslationCoordinator(gateway: gateway);

    expect(coordinator.entryFor('m1').phase, ReasoningTranslationPhase.idle);
    await coordinator.translate(messageId: 'm1', reasoning: englishReasoning);
    expect(gateway.calls, 1);
    expect(gateway.lastSource, englishReasoning);
    expect(
      coordinator.entryFor('m1').phase,
      ReasoningTranslationPhase.translated,
    );
    expect(coordinator.entryFor('m1').visible, isTrue);

    await coordinator.translate(messageId: 'm1', reasoning: englishReasoning);
    expect(gateway.calls, 1);
    expect(coordinator.entryFor('m1').visible, isFalse);
    await coordinator.translate(messageId: 'm1', reasoning: englishReasoning);
    expect(gateway.calls, 1);
    expect(coordinator.entryFor('m1').visible, isTrue);

    coordinator.dispose();
    expect(gateway.closed, isTrue);
  });

  test('Chinese-first reasoning never starts a translation request', () async {
    final gateway = _FakeTranslationGateway();
    final coordinator = ReasoningTranslationCoordinator(gateway: gateway);
    await coordinator.translate(
      messageId: 'm1',
      reasoning: '先看他这句话为什么突然让我有点害羞，再决定怎么说。',
    );
    expect(gateway.calls, 0);
    expect(coordinator.entryFor('m1').phase, ReasoningTranslationPhase.idle);
    coordinator.dispose();
  });

  test('a failed translation can be retried without touching the source',
      () async {
    final gateway = _FlakyTranslationGateway();
    final coordinator = ReasoningTranslationCoordinator(gateway: gateway);
    await coordinator.translate(messageId: 'm1', reasoning: englishReasoning);
    expect(coordinator.entryFor('m1').phase, ReasoningTranslationPhase.failed);
    await coordinator.translate(messageId: 'm1', reasoning: englishReasoning);
    expect(gateway.calls, 2);
    expect(
      coordinator.entryFor('m1').translation,
      '重试后的中文翻译。',
    );
    coordinator.dispose();
  });

  test('disposing a page cancels an unfinished translation', () async {
    final gateway = _PendingTranslationGateway();
    final coordinator = ReasoningTranslationCoordinator(gateway: gateway);
    unawaited(
      coordinator.translate(messageId: 'm1', reasoning: englishReasoning),
    );
    await gateway.started.future;
    expect(gateway.token?.isCancelled, isFalse);
    coordinator.dispose();
    expect(gateway.token?.isCancelled, isTrue);
    expect(gateway.closed, isTrue);
  });

  testWidgets('reasoning panel shows an underlined purple manual link',
      (tester) async {
    final gateway = _FakeTranslationGateway();
    final coordinator = ReasoningTranslationCoordinator(gateway: gateway);
    addTearDown(coordinator.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReasoningPanel(
            reasoning: englishReasoning,
            messageId: 'm1',
            translationCoordinator: coordinator,
          ),
        ),
      ),
    );

    await tester.tap(find.text('🧠 思考'));
    await tester.pumpAndSettle();
    final link = tester.widget<Text>(find.text('翻译成中文'));
    expect(link.style?.color, const Color(0xFF8B5CF6));
    expect(link.style?.decoration, TextDecoration.underline);

    await tester.tap(find.text('翻译成中文'));
    await tester.pumpAndSettle();
    expect(find.text('这是一段忠实的中文翻译。'), findsOneWidget);
    expect(find.text('隐藏翻译'), findsOneWidget);
  });
}
