import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/memory_extractor.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'test-only'});
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    final now = DateTime.now();
    await db.insertMessage(ChatMessage(id: 'user', role: 'user',
      content: '今天看到了漂亮的落叶。', createdAt: now));
    await db.insertMessage(ChatMessage(id: 'assistant', role: 'assistant',
      content: '那个颜色很适合秋天。', createdAt: now));
    await db.enqueuePostTurnJob(userMessageId: 'user', assistantMessageId: 'assistant');
  });

  tearDown(() async => db.closeForTesting());

  Future<Map<String, Object?>> job() async =>
      (await (await db.database).query('post_turn_jobs')).single;

  for (final failure in ['length', 'malformed', 'empty']) {
    test('memory $failure JSON retries at most three times without committing a proposal', () async {
      final requests = <Map<String, dynamic>>[];
      final client = DeepSeekClient(client: MockClient((request) async {
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(jsonEncode({'choices': [{
          // A length-limited body may still happen to parse. It must not be
          // checkpointed merely because the JSON parser accepts it.
          'message': {'content': failure == 'length' ? '{}' : failure == 'empty' ? '' : '{'},
          'finish_reason': failure == 'length' ? 'length' : 'stop',
        }]}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }));
      final extractor = MemoryExtractor(db: db, client: client, desireEngine: DesireEngine(db));
      try {
        for (var attempt = 1; attempt <= 3; attempt++) {
          await extractor.drainPending(maxJobs: 1);
          final current = await job();
          expect(current['attempts'], attempt);
          expect(current['status'], attempt < 3 ? 'retry_wait' : 'failed');
          expect(current['result_json'], '');
          expect(current['model_completed_at'], isNull);
          expect(current['desire_applied_at'], isNull);
          if (attempt < 3) {
            await (await db.database).update('post_turn_jobs', {'next_retry_at': 0});
          }
        }
        await extractor.drainPending(maxJobs: 1);
        expect(requests, hasLength(3));
        expect(requests.every((r) => r['max_tokens'] == 4096), true);
        expect(requests.every((r) => (r['thinking'] as Map)['type'] == 'disabled'), true);
      } finally {
        client.close();
      }
    });
  }

  test('memory stable bad request is not retried', () async {
    var calls = 0;
    final client = DeepSeekClient(client: MockClient((request) async {
      calls++;
      return http.Response('{"error":{"message":"invalid model configuration"}}', 400);
    }));
    try {
      final extractor = MemoryExtractor(db: db, client: client, desireEngine: DesireEngine(db));
      await extractor.drainPending(maxJobs: 1);
      expect((await job())['status'], 'failed');
      await extractor.drainPending(maxJobs: 1);
      expect(calls, 1);
    } finally {
      client.close();
    }
  });

  test('JSON retry bound does not change the existing transient network policy', () async {
    await (await db.database).update('post_turn_jobs', {'attempts': 3});
    final client = DeepSeekClient(client: MockClient((request) async =>
      http.Response('{"error":{"message":"temporarily unavailable"}}', 503)));
    try {
      final extractor = MemoryExtractor(db: db, client: client, desireEngine: DesireEngine(db));
      await extractor.drainPending(maxJobs: 1);
      final current = await job();
      expect(current['attempts'], 4);
      expect(current['status'], 'retry_wait');
    } finally {
      client.close();
    }
  });
}
