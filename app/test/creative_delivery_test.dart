import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/chat_api_provider.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/creative/creative_contract.dart';
import 'package:ai_companion_localfirst/core/creative/creative_delivery.dart';
import 'package:ai_companion_localfirst/core/creative/creative_store.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';

http.Response answer([String text = '小灯做好了，点一下就能亮起来。']) => http.Response(
  'data: ${jsonEncode({'choices': [{'delta': {'content': text}, 'finish_reason': 'stop'}]})}\n\n'
  'data: [DONE]\n\n', 200, headers: {'content-type': 'text/event-stream; charset=utf-8'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late CreativeStore store;
  late String id;
  var clock = DateTime.now();
  var calls = 0;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    store = CreativeStore(db); clock = DateTime.now(); calls = 0;
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'test-deepseek'});
    await SecureConfig.instance.writeChatProvider(ChatApiProvider.aiWangYouGemini);
    await SecureConfig.instance.writeAiWangYouApiKey('test-final');
    await SecureConfig.instance.writeAiWangYouEndpoint('https://writer.invalid/v1/chat/completions');
    await SecureConfig.instance.writeAiWangYouModel('custom-final-writer');
    final work = await store.commission(deepThinking: true, requestId: 'request', messageId: 'commission',
      brief: '做一个点灯作品', requestQuote: '做一个点灯作品', latestText: '做一个点灯作品');
    id = work['id'] as String;
    const html = '<button>PRIVATE_SOURCE_NOT_FOR_FINAL_WRITER</button>';
    final hash = CreativeContract.hash(html);
    await store.write(work, {...work, 'title': '小灯', 'intro': '点一下亮起来', 'status': 'ready',
      'current': hash, 'versions': [hash], 'completion_message_id': CreativeContract.completionMessageId(id, 'request', hash)},
      extra: {'${CreativeContract.sourcePrefix}$hash': html,
        CreativeDelivery.key(id): jsonEncode(CreativeDelivery.pending(work, hash, {'checks': [1]}, clock.millisecondsSinceEpoch))});
    final sql = await db.database;
    await sql.insert('messages', {'id': 'user-one', 'role': 'user', 'content': '随便聊聊', 'created_at': 1});
    await db.setSetting('deep_thinking_enabled', '0');
  });
  tearDown(() async { await db.closeForTesting(); });
  CreativeDelivery runner(Future<http.Response> Function(http.Request) handler) =>
      CreativeDelivery(db, now: () => clock, clientFactory: (abort) => DeepSeekClient(abortWhen: abort,
        streamClientFactory: () => MockClient((request) async { calls++; return handler(request); })));
  Future<List<Map<String, Object?>>> delivered() async => (await db.database).query('messages',
      where: "proactive_intent = 'creative_ready'");
  Future<Map<String, dynamic>> notice() => CreativeDelivery(db).read(id);
  Future<void> tick(CreativeDelivery runtime) async { clock = clock.add(const Duration(minutes: 5)); await runtime.runOnce(); }

  test('one direct second-channel body, no planner, real card identity and no proactive quota', () async {
    final runtime = runner((request) async {
      expect(request.url.host, 'writer.invalid');
      expect(request.headers['Authorization'], 'Bearer test-final');
      final body = jsonDecode(request.body) as Map;
      expect(body['model'], 'custom-final-writer');
      expect(body.containsKey('tools'), false);
      expect(request.body, contains('已完成作品的交付正文'));
      expect(request.body, contains('小灯'));
      expect(request.body, isNot(contains('PRIVATE_SOURCE_NOT_FOR_FINAL_WRITER')));
      return answer();
    });
    await runtime.runOnce(); await runtime.runOnce();
    final messages = await delivered();
    expect(calls, 1); expect(messages, hasLength(1));
    expect(messages.single['id'], (await store.get(id))['completion_message_id']);
    expect(messages.single['content'], '小灯做好了，点一下就能亮起来。');
    expect((await notice())['status'], 'delivered');
    final deliveredId = messages.single['id'] as String;
    expect((await store.forMessage(deliveredId)).single['card_kind'], 'delivered');
    expect((await db.getSetting('${CreativeContract.receiptPrefix}$deliveredId'))!.length, lessThan(1000));
    final sql = await db.database;
    expect(await sql.query('messages', where: "role='user'"), hasLength(1));
    expect(await sql.query('proactive_history'), isEmpty);
  });

  test('chat lease defers all paid generation until idle', () async {
    final runtime = runner((_) async => answer());
    await db.tryAcquireLocalLease('chat_turn_lease');
    await runtime.runOnce(); expect(calls, 0);
    await db.releaseLocalLease('chat_turn_lease');
    await runtime.runOnce(); expect(calls, 1); expect(await delivered(), hasLength(1));
  });

  test('durable chat job also defers generation without needing a live lease', () async {
    final sql = await db.database;
    await sql.insert('generation_jobs', {'id': 'pending-chat', 'user_message_id': 'user-one',
      'assistant_message_id': 'future-assistant', 'model': 'deepseek-flash', 'status': 'pending', 'created_at': 1, 'updated_at': 1});
    await runner((_) async => answer()).runOnce();
    expect(calls, 0); expect(await delivered(), isEmpty);
  });

  test('checkpointed body survives a restart and commits once without another API request', () async {
    await runner((_) async {
      await db.tryAcquireLocalLease('chat_turn_lease');
      return answer();
    }).runOnce();
    expect((await notice())['phase'], 'generated');
    expect(await delivered(), isEmpty);
    await db.releaseLocalLease('chat_turn_lease');
    final restarted = runner((_) async { fail('checkpoint must avoid another request'); });
    await restarted.runOnce(); await restarted.runOnce();
    expect(await delivered(), hasLength(1)); expect(calls, 1);
  });

  test('two engines share one delivery lease and one receipt', () async {
    final started = Completer<void>(); final release = Completer<void>();
    final first = runner((_) async { started.complete(); await release.future; return answer(); });
    final running = first.runOnce(); await started.future;
    await runner((_) async { fail('parallel sender obtained the live lease'); }).runOnce();
    release.complete(); await running;
    expect(calls, 1); expect(await delivered(), hasLength(1));
  });

  for (final change in ['delete', 'import', 'revision', 'stop']) {
    test('$change during generation rejects old completion', () async {
      await runner((_) async {
        if (change == 'delete') await store.delete(id);
        if (change == 'stop') await store.stop(id);
        if (change == 'import') {
          final backup = await db.exportAll();
          await db.importAll(Map<String, dynamic>.from(backup));
        }
        if (change == 'revision') await store.commission(deepThinking: true, requestId: 'new-request',
          messageId: 'new-message', workId: id, brief: '改成蓝色', requestQuote: '改成蓝色', latestText: '改成蓝色');
        return answer('不应该发送的旧正文');
      }).runOnce();
      expect(await delivered(), isEmpty);
      if (change == 'import') expect((await notice())['status'], 'cancelled');
    });
  }

  test('new user turn preempts stale wording, then generates after conversation settles', () async {
    final runtime = runner((_) async {
      if (calls == 1) {
        await (await db.database).insert('messages', {'id': 'user-two', 'role': 'user', 'content': '新话题', 'created_at': 2});
        return answer('旧上下文正文');
      }
      return answer('新上下文中的完成提示');
    });
    await runtime.runOnce();
    expect(await delivered(), isEmpty);
    expect((await notice())['preempt'], 'user_chat');
    await tick(runtime);
    expect((await delivered()).single['content'], '新上下文中的完成提示');
    expect(calls, 2);
  });

  test('finite failed retries never fabricate speech or unpublish the work; manual retry is ungated', () async {
    await SecureConfig.instance.writeChatProvider(ChatApiProvider.deepSeek);
    final runtime = runner((_) async => http.Response('unavailable', 503));
    for (var i = 0; i < 5; i++) { await tick(runtime); }
    expect(calls, CreativeDelivery.maxAttempts);
    expect((await notice())['status'], 'paused');
    expect((await store.get(id))['status'], 'ready'); expect(await delivered(), isEmpty);
    await CreativeDelivery(db).retry(id);
    await runner((_) async => answer()).runOnce();
    expect(await delivered(), hasLength(1));
  });

  test('second-channel transport failure may use existing DeepSeek fallback, with no planning tools', () async {
    await runner((request) async {
      if (request.url.host == 'writer.invalid') return http.Response('unavailable', 503);
      expect(request.headers['Authorization'], 'Bearer test-deepseek');
      expect((jsonDecode(request.body) as Map).containsKey('tools'), false);
      return answer();
    }).runOnce();
    expect(calls, 2); expect(await delivered(), hasLength(1));
    expect((await notice())['provider_failure'], isNotEmpty);
  });

  test('pre-upgrade ready works receive no retroactive completion spam', () async {
    await db.setSetting(CreativeDelivery.key(id), '');
    await runner((_) async => answer()).runOnce();
    expect(calls, 0); expect(await delivered(), isEmpty);
    expect(await store.chatContext(), contains('ready'));
  });
}
