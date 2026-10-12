import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/chat_api_provider.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/final_reply_failure_policy.dart';
import 'package:ai_companion_localfirst/core/ai/final_reply_route.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_delivery_budget.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_final_reply_retry.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

http.Response answer(String content, {bool terminal = true}) =>
    http.Response.bytes(utf8.encode(
      'data: ${jsonEncode({'choices': [{'delta': {'content': content}, if (terminal) 'finish_reason': 'stop'}]})}\n\n'
      '${terminal ? 'data: [DONE]\n\n' : ''}',
    ), 200, headers: {'content-type': 'text/event-stream; charset=utf-8'});

class _Reply {
  const _Reply(this.text, this.terminal, this.finishReason);
  final String text;
  final bool terminal;
  final String finishReason;
}

class _Harness {
  _Harness(Future<http.Response> Function(http.Request) handler) {
    client = DeepSeekClient(streamClientFactory: () => MockClient((request) {
      requests.add(jsonDecode(request.body) as Map<String, dynamic>);
      return handler(request);
    }));
  }

  late final DeepSeekClient client;
  final route = FinalReplyRoute(secondChannelEnabled: true);
  final requests = <Map<String, dynamic>>[];
  final fallbacks = <int>[];
  bool allowed = true;
  int delays = 0;

  Future<_Reply?> request({required bool secondChannel}) async {
    final content = StringBuffer();
    var terminal = false;
    var finish = '';
    await for (final delta in client.streamChat(
      apiKey: 'test', model: DeepSeekModelProfile.flash,
      effort: ReasoningEffort.high,
      messages: const [{'role': 'system', 'content': 'ONLY_SELECTED_NEW_SOURCE'}],
      endpoint: 'https://relay.invalid/v1/chat/completions',
      requestProvider: secondChannel ? ChatApiProvider.aiWangYouGemini : ChatApiProvider.deepSeek,
      modelName: secondChannel ? 'configured-gemini' : null,
      usageLane: secondChannel ? 'proactive_final_reply' : 'proactive',
      usageExecutionId: 'one-heartbeat',
    )) {
      content.write(delta.content);
      if (delta.done || delta.finishReason != null) terminal = true;
      if (delta.finishReason != null) finish = delta.finishReason!;
    }
    return _Reply(content.toString(), terminal, finish);
  }

  Future<ProactiveReplyResult<_Reply>?> generate({
    bool configured = true,
    Future<bool> Function()? boundary,
    Future<_Reply?> Function({required bool secondChannel})? requestOverride,
    Future<void> Function()? onDelay,
    Future<void> Function()? afterFallbackNotice,
  }) => ProactiveFinalReplyRetry.generate<_Reply>(
    route: route,
    secondChannelConfigured: configured,
    canContinue: boundary ?? () async => allowed,
    request: requestOverride ?? request,
    validateSecondChannel: (candidate) {
      final failure = FinalReplyFailurePolicy.incompleteResponseFailure(
        sawTerminalSignal: candidate.terminal,
        finishReason: candidate.finishReason,
        content: candidate.text,
      );
      if (failure != null) throw failure;
      if (candidate.text.isEmpty) throw const EmptyFinalReplyException();
    },
    onFallback: (attempts, failures) async {
      fallbacks.add(attempts);
      expect(failures, isNotEmpty);
      await afterFallbackNotice?.call();
    },
    wait: (_) async { delays++; await onDelay?.call(); },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final harnesses = <_Harness>[];
  _Harness harness(Future<http.Response> Function(http.Request) handler) {
    final value = _Harness(handler);
    harnesses.add(value);
    return value;
  }
  tearDown(() {
    for (final item in harnesses) { item.client.close(); }
    harnesses.clear();
  });

  test('first success needs one request; WAIT remains a successful decision', () async {
    final h = harness((_) async => answer('WAIT'));
    final result = (await h.generate())!;
    expect(result.candidate.text, 'WAIT');
    expect(result.usedSecondChannel, isTrue);
    expect(result.secondChannelAttempts, 1);
    expect(result.failures, isEmpty);
    expect(h.requests, hasLength(1));
    expect(h.fallbacks, isEmpty);
    expect(h.delays, 0);
  });

  for (final status in [400, 401, 403, 429, 500]) {
    test('HTTP $status retries once in the same channel before success', () async {
      var calls = 0;
      final h = harness((_) async => ++calls == 1
          ? http.Response('provider request failed', status) : answer('完整的新话题'));
      final result = (await h.generate())!;
      expect(result.candidate.text, '完整的新话题');
      expect(result.secondChannelAttempts, 2);
      expect(result.failures, hasLength(1));
      expect(h.requests.map((r) => r['model']), ['configured-gemini', 'configured-gemini']);
      expect(h.requests.first['messages'], h.requests.last['messages']);
      expect(h.fallbacks, isEmpty);
      expect(h.delays, 1);
      expect(h.route.useSecondChannel, isTrue);
      expect(h.requests.every((r) => !r.containsKey('max_tokens')), isTrue);
    });
  }

  test('two failures invoke one fallback; semantic repair keeps that route', () async {
    var calls = 0;
    final h = harness((_) async => ++calls <= 2
        ? http.Response('provider request failed', 400) : answer('兜底完整正文'));
    final result = (await h.generate())!;
    expect(result.usedSecondChannel, isFalse);
    expect(result.secondChannelAttempts, 2);
    expect(result.failures, hasLength(2));
    expect(h.fallbacks, [2]);
    await h.generate();
    expect(h.requests.map((r) => r['model']), [
      'configured-gemini', 'configured-gemini',
      DeepSeekModelProfile.flash.apiName, DeepSeekModelProfile.flash.apiName,
    ]);
    expect(h.fallbacks, [2]);
  });

  test('successful retry leaves semantic correction in the second channel', () async {
    var calls = 0;
    final h = harness((_) async => ++calls == 1
        ? http.Response('late', 503) : answer('完整正文'));
    await h.generate();
    final correction = (await h.generate())!;
    expect(correction.secondChannelAttempts, 1);
    expect(h.requests.map((r) => r['model']), List.filled(3, 'configured-gemini'));
    expect(h.fallbacks, isEmpty);
  });

  for (final broken in {
    'empty': answer(''),
    'missing terminal': answer('不可见的半句', terminal: false),
    'unclosed quote': answer('「未闭合'),
  }.entries) {
    test('${broken.key} stream is discarded before retry', () async {
      var calls = 0;
      final h = harness((_) async => ++calls == 1 ? broken.value : answer('完整正文'));
      final result = (await h.generate())!;
      expect(result.candidate.text, '完整正文');
      expect(result.secondChannelAttempts, 2);
      expect(result.failures, hasLength(1));
      expect(h.fallbacks, isEmpty);
    });
  }

  test('missing local key opens no second-channel request', () async {
    final h = harness((_) async => answer('兜底正文'));
    final result = (await h.generate(configured: false))!;
    expect(result.secondChannelAttempts, 0);
    expect(result.usedSecondChannel, isFalse);
    expect(h.requests.single['model'], DeepSeekModelProfile.flash.apiName);
    expect(h.fallbacks, [0]);
    expect(h.delays, 0);
  });

  for (final interruption in [
    const GenerationCancelledByUserException(),
    const GenerationSuspendedByRuntimeGateException(),
  ]) {
    test('$interruption never retries or falls back', () async {
      var calls = 0;
      final h = harness((_) async => answer('unused'));
      await expectLater(h.generate(requestOverride: ({required bool secondChannel}) async {
        calls++;
        throw interruption;
      }), throwsA(same(interruption)));
      expect(calls, 1);
      expect(h.delays, 0);
      expect(h.fallbacks, isEmpty);
      expect(h.route.useSecondChannel, isTrue);
    });
  }

  test('lost lease during stream returns no candidate and no retry', () async {
    final h = harness((_) async => answer('unused'));
    var calls = 0;
    expect(await h.generate(requestOverride: ({required bool secondChannel}) async {
      calls++;
      return null;
    }), isNull);
    expect(calls, 1);
    expect(h.fallbacks, isEmpty);
    expect(h.delays, 0);
  });

  test('runtime changed during retry delay starts no second request', () async {
    final h = harness((_) async => http.Response('late', 500));
    expect(await h.generate(onDelay: () async { h.allowed = false; }), isNull);
    expect(h.requests, hasLength(1));
    expect(h.fallbacks, isEmpty);
    expect(h.route.useSecondChannel, isTrue);
  });

  test('fallback failure propagates without recursively repeating requests', () async {
    final h = harness((_) async => http.Response('still unavailable', 503));
    await expectLater(h.generate(), throwsA(isA<DeepSeekException>()));
    expect(h.requests, hasLength(3));
    expect(h.fallbacks, [2]);
    expect(h.delays, 1);
  });

  test('runtime changed after fallback notice never starts DeepSeek', () async {
    final h = harness((_) async => http.Response('late', 500));
    expect(await h.generate(afterFallbackNotice: () async { h.allowed = false; }), isNull);
    expect(h.requests, hasLength(2));
    expect(h.fallbacks, [2]);
  });

  test('successful but stale response is discarded', () async {
    late _Harness h;
    h = harness((_) async { h.allowed = false; return answer('过期正文'); });
    expect(await h.generate(), isNull);
    expect(h.requests, hasLength(1));
    expect(h.fallbacks, isEmpty);
  });

  test('retry buffers never commit or spend quota; final candidate commits once', () async {
    final db = await AppDatabase.createForTesting(databaseFactoryFfi);
    addTearDown(db.closeForTesting);
    final sql = await db.database;
    final at = DateTime(2026, 10, 12, 12);
    var calls = 0;
    final h = harness((_) async {
      expect(await sql.query('messages'), isEmpty);
      expect(await sql.query('proactive_history'), isEmpty);
      return ++calls == 1 ? answer('废弃片段', terminal: false) : answer('最终正文');
    });
    final result = (await h.generate())!;
    expect((await ProactiveDeliveryBudget.read(sql, at)).used, 0);
    expect(await db.commitProactiveMessageIfCurrent(
      message: ChatMessage(id: 'one-outbound', role: 'assistant',
        content: result.candidate.text, createdAt: at, isProactive: true),
      evaluationStartedAt: at, deliveryAt: at,
      proactiveTriggerReason: 'curiosity:new-source', enforceProactiveBudget: true,
    ), isNull);
    expect((await sql.query('messages')).single['content'], '最终正文');
    expect(await sql.query('proactive_history'), hasLength(1));
    expect((await ProactiveDeliveryBudget.read(sql, at)).used, 1);
  });

  test('real lease replacement between attempts stops before retry and delivery', () async {
    final db = await AppDatabase.createForTesting(databaseFactoryFfi);
    addTearDown(db.closeForTesting);
    expect(await db.tryAcquireProactiveLease(), isTrue);
    final fence = (await db.captureBrainWorkFence(leaseKey: 'proactive_lease_until'))!;
    final h = harness((_) async => http.Response('late', 500));
    expect(await h.generate(
      boundary: () => db.brainWorkFenceCurrent(fence),
      onDelay: () async { await db.setSetting('proactive_lease_until', 'another-owner|9999999999999'); },
    ), isNull);
    expect(h.requests, hasLength(1));
    expect(h.fallbacks, isEmpty);
    expect(await (await db.database).query('messages'), isEmpty);
    expect(await (await db.database).query('proactive_history'), isEmpty);
  });

  test('expired unreplaced lease cannot be revived by a delayed stream', () async {
    final db = await AppDatabase.createForTesting(databaseFactoryFfi);
    addTearDown(db.closeForTesting);
    expect(await db.tryAcquireProactiveLease(), isTrue);
    final fence = (await db.captureBrainWorkFence(leaseKey: 'proactive_lease_until'))!;
    final h = harness((_) async => answer('unused'));
    var calls = 0;
    final expired = '${fence.leaseToken}|${DateTime.now().millisecondsSinceEpoch - 1}';
    expect(await h.generate(
      boundary: () => db.brainWorkFenceCurrent(fence),
      requestOverride: ({required bool secondChannel}) async {
        calls++;
        await db.setSetting('proactive_lease_until', expired);
        expect(await db.renewLocalLease('proactive_lease_until',
          holdFor: const Duration(minutes: 5), workFence: fence), isFalse);
        return const _Reply('已经失去租约的完整正文', true, 'stop');
      },
    ), isNull);
    expect(calls, 1);
    expect(h.fallbacks, isEmpty);
    expect(h.delays, 0);
    expect(await db.getSetting('proactive_lease_until'), expired);
    final sql = await db.database;
    expect(await sql.query('messages'), isEmpty);
    expect(await sql.query('proactive_history'), isEmpty);
  });

  test('old stream cannot renew a replacement lease on the same database', () async {
    final db = await AppDatabase.createForTesting(databaseFactoryFfi);
    addTearDown(db.closeForTesting);
    expect(await db.tryAcquireProactiveLease(), isTrue);
    final oldFence = (await db.captureBrainWorkFence(leaseKey: 'proactive_lease_until'))!;
    await db.setSetting('proactive_lease_until',
      '${oldFence.leaseToken}|${DateTime.now().millisecondsSinceEpoch - 1}');
    // TTL expiry does not release this isolate's logical ownership. Model a
    // cancelled/released request whose delayed stream resumes after a new
    // request has acquired a fresh lease on the same database instance.
    expect(await db.tryAcquireProactiveLease(), isFalse);
    await db.releaseLocalLease('proactive_lease_until');
    expect(await db.tryAcquireProactiveLease(), isTrue);
    final replacement = await db.getSetting('proactive_lease_until');
    final newFence = (await db.captureBrainWorkFence(leaseKey: 'proactive_lease_until'))!;
    expect(newFence.leaseToken, isNot(oldFence.leaseToken));
    expect(await db.renewLocalLease('proactive_lease_until',
      holdFor: const Duration(minutes: 5), workFence: oldFence), isFalse);
    expect(await db.getSetting('proactive_lease_until'), replacement);
    expect(await db.renewLocalLease('proactive_lease_until',
      holdFor: const Duration(minutes: 5), workFence: newFence), isTrue);
    expect(await db.brainWorkFenceCurrent(newFence), isTrue);
  });
}
