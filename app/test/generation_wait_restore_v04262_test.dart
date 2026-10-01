import 'dart:async';
import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/chat_api_provider.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/generation_lease_guard.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _SseClient extends http.BaseClient {
  _SseClient(this.frames, {this.status = 200});
  final Stream<List<int>> frames;
  final int status;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(frames, status);
  @override
  void close() { closed = true; }
}

Stream<List<int>> _keepalives() => Stream.periodic(
    const Duration(milliseconds: 5),
    (i) => utf8.encode(i.isEven ? ': keepalive\n\n' :
        'data: {"choices":[{"delta":{}}]}\n\n'));

Stream<DeepSeekDelta> _reply(DeepSeekClient client,
    {GenerationCancellationToken? cancellation, int timeoutMs = 50}) =>
    client.streamChat(apiKey: 'test', model: DeepSeekModelProfile.flash,
      effort: ReasoningEffort.high,
      requestProvider: ChatApiProvider.aiWangYouGemini,
      messages: const [{'role': 'user', 'content': '去玩20分钟'}],
      cancellationToken: cancellation,
      requestTimeout: Duration(milliseconds: timeoutMs));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('empty SSE keepalives cannot extend a silent final reply forever', () async {
    final transport = _SseClient(_keepalives());
    final client = DeepSeekClient(streamClientFactory: () => transport);
    await expectLater(_reply(client).drain<void>(), throwsA(isA<TimeoutException>()));
    expect(transport.closed, isTrue);
    client.close();
  });

  test('real reasoning/text deltas keep a slow valid reply alive', () async {
    final frames = Stream.periodic(const Duration(milliseconds: 15),
        (i) => utf8.encode(i < 8
          ? 'data: {"choices":[{"delta":{"content":"字"}}]}\n\n'
          : 'data: [DONE]\n\n')).take(9);
    final transport = _SseClient(frames);
    final client = DeepSeekClient(streamClientFactory: () => transport);
    final result = await _reply(client, timeoutMs: 100).toList();
    expect(result.map((r) => r.content).join(), '字' * 8);
    expect(result.last.done, isTrue);
    expect(transport.closed, isTrue);
    client.close();
  });

  test('an error response body also has a deadline', () async {
    final transport = _SseClient(_keepalives(), status: 502);
    final client = DeepSeekClient(streamClientFactory: () => transport);
    await expectLater(_reply(client).drain<void>(), throwsA(isA<TimeoutException>()));
    expect(transport.closed, isTrue);
    client.close();
  });

  test('Stop during keepalive waiting still cancels rather than timing out', () async {
    final transport = _SseClient(_keepalives());
    final client = DeepSeekClient(streamClientFactory: () => transport);
    final token = GenerationCancellationToken();
    final result = _reply(client, cancellation: token, timeoutMs: 300).drain<void>();
    final assertion = expectLater(result,
        throwsA(isA<GenerationCancelledByUserException>()));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    token.cancel();
    await assertion;
    expect(transport.closed, isTrue);
    client.close();
  });

  group('real SQLite generation fence', () {
    late AppDatabase db;
    setUp(() async { db = await AppDatabase.createForTesting(databaseFactoryFfi); });
    tearDown(() async { await db.closeForTesting(); });

    Future<GenerationLeaseGuard> guard() async {
      await db.tryAcquireLocalLease('chat_turn_lease');
      final pending = await db.createGenerationTurn(
        user: ChatMessage(id: 'user', role: 'user', content: '去玩20分钟',
            createdAt: DateTime.now()),
        assistantMessageId: 'assistant', model: 'deepseek-flash', reasoningEffort: 'high');
      return GenerationLeaseGuard(db, (await db.claimGenerationJob(pending.id))!);
    }

    test('silent wait renews without any network output', () async {
      final fence = await guard();
      final at = DateTime.now();
      expect(await fence.check(now: at), GenerationFenceState.current);
      // Simulate an almost-expired lease while this attempt is still owner.
      await db.renewLocalLease('chat_turn_lease', holdFor: const Duration(milliseconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(await db.isLocalLeaseHeld('chat_turn_lease'), isFalse);
      expect(await fence.check(now: at.add(const Duration(seconds: 11))),
          GenerationFenceState.current);
      expect(await db.isLocalLeaseHeld('chat_turn_lease'), isTrue);
      expect((await db.generationJobById(fence.job.id))!.status, 'running');
    });

    test('restore invalidates ownership without cancelling the user turn', () async {
      final fence = await guard();
      final backup = await db.exportAll();
      await db.importAll(backup, runtimeSettingOverrides: {'chat_turn_lease': '0'});
      expect(await fence.check(), GenerationFenceState.ownershipLost);
      expect((await db.generationJobById(fence.job.id))!.status, 'pending');
      expect(await db.messageById('user'), isNotNull);
    });

    test('manual Stop remains distinct from loss of ownership', () async {
      final fence = await guard();
      await db.cancelGenerationJobByUser(fence.job.id);
      expect(await fence.check(), GenerationFenceState.cancelled);
      expect((await db.generationJobById(fence.job.id))!.status, 'cancelled_by_user');
    });
  });

  group('batched restore', () {
    late AppDatabase db;
    setUp(() async { db = await AppDatabase.createForTesting(databaseFactoryFfi); });
    tearDown(() async { await db.closeForTesting(); });

    Future<Map<String, dynamic>> largeBackup() async {
      final backup = await db.exportAll();
      final tables = backup['tables'] as Map;
      tables['desire_events'] = List.generate(40000, (i) => {
        'id': 'event-$i', 'event_kind': 'test', 'drive_key': 'play',
        'source_key': 'test', 'delta': .1, 'value_after': .5,
        'baseline_after': .3, 'created_at': i,
      });
      return backup;
    }

    test('40000 rows restore completely across batch boundaries', () async {
      final backup = await largeBackup();
      await db.importAll(backup);
      final sql = await db.database;
      expect((await sql.rawQuery('SELECT COUNT(*) AS n FROM desire_events')).single['n'], 40000);
      expect((await sql.query('desire_events', where: 'id = ?',
          whereArgs: ['event-39999'])).single['created_at'], 39999);
    });

    test('late invalid row rolls back every previous batch and table deletion', () async {
      await db.setSetting('original', '保留🙂');
      final backup = await largeBackup();
      final tables = backup['tables'] as Map;
      (tables['settings'] as List).add({'key': 'bad', 'unknown_column': 1});
      await expectLater(db.importAll(backup), throwsA(isA<DatabaseException>()));
      expect(await db.getSetting('original'), '保留🙂');
      final sql = await db.database;
      expect((await sql.rawQuery('SELECT COUNT(*) AS n FROM desire_events')).single['n'], 0);
    });
  });
}
