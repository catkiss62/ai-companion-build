import 'dart:async';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _BlockingClient extends http.BaseClient {
  final Completer<http.StreamedResponse> response =
      Completer<http.StreamedResponse>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => response.future;

  @override
  void close() {
    if (!response.isCompleted) {
      response.completeError(StateError('client_closed'));
    }
    super.close();
  }
}

void main() {
  test('late-night fatigue defers a committed unattended game', () {
    final decision = CedarContinuationGatePolicy.evaluate(
      now: DateTime(2026, 9, 15, 4, 40),
      storedFatigue: 0.74,
      curiosity: 0.16,
      reflection: 0.20,
      strongestGameThought: 0,
      activelyWatched: false,
    );

    expect(decision.allowed, isFalse);
    expect(decision.reason, 'rest_wins');
    expect(decision.delay, const Duration(minutes: 45));
    expect(decision.restScore, greaterThan(decision.playScore));
  });

  test('a genuinely strong game motive may beat rest competition', () {
    final decision = CedarContinuationGatePolicy.evaluate(
      now: DateTime(2026, 9, 15, 1, 0),
      storedFatigue: 0.60,
      curiosity: 0.82,
      reflection: 0.55,
      strongestGameThought: 0.95,
      activelyWatched: false,
    );

    expect(decision.allowed, isTrue);
    expect(decision.playScore, greaterThan(decision.restScore));
  });

  test('Cedar JSON cancellation closes a blocked planner immediately', () async {
    final token = GenerationCancellationToken();
    final blocker = _BlockingClient();
    final client = DeepSeekClient(jsonClientFactory: () => blocker);
    final request = CedarJsonDecisionExecutor(ai: client).decide(
      apiKey: 'test',
      endpoint: DeepSeekClient.defaultEndpoint,
      instruction: 'only json',
      cancellationToken: token,
    );

    await Future<void>.delayed(const Duration(milliseconds: 10));
    token.cancel();

    await expectLater(
      request.timeout(const Duration(seconds: 2)),
      throwsA(isA<GenerationCancelledByUserException>()),
    );
    client.close();
  });

  test('a provider timeout is not retried inside the same Cedar cycle', () async {
    var clientsCreated = 0;
    final client = DeepSeekClient(
      jsonClientFactory: () {
        clientsCreated++;
        return _BlockingClient();
      },
    );
    final token = GenerationCancellationToken();

    final request = CedarJsonDecisionExecutor(ai: client).decide(
      apiKey: 'test',
      endpoint: DeepSeekClient.defaultEndpoint,
      instruction: 'only json',
      cancellationToken: token,
      requestTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(request, throwsA(isA<TimeoutException>()));
    expect(clientsCreated, 1);
    expect(
      CedarJsonDecisionRetryPolicy.isRetryable(
        TimeoutException('provider stalled'),
      ),
      isFalse,
    );
    client.close();
  });

  test('execution identity survives state serialization for late-result fence', () {
    final execution = CedarGameExecution(
      id: 'exec-1',
      gameId: 'fishing',
      action: 'cast',
      startedAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final restored = CedarGameExecution.fromJson(execution.toJson());
    expect(restored.id, 'exec-1');
    expect(restored.gameId, 'fishing');
    expect(restored.action, 'cast');
  });
}
