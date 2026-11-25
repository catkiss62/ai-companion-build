import 'dart:async';
import 'package:ai_companion_localfirst/core/agent/work_app_reader.dart';
import 'package:ai_companion_localfirst/core/agent/research_commission.dart';
import 'package:ai_companion_localfirst/core/creative/creative_contract.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:ai_companion_localfirst/core/agent/work_text_reference.dart';
import 'package:ai_companion_localfirst/core/agent/commission_session.dart';
import 'package:ai_companion_localfirst/core/agent/commission_thread.dart';
import 'package:ai_companion_localfirst/core/agent/commission_workspace.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/features/chat/work_conversation.dart';
import 'package:ai_companion_localfirst/features/chat/work_mode_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('work app reads visible published bytes, pinned pages and the last actual game receipt', () async {
    final db = await AppDatabase.createForTesting(databaseFactoryFfi);
    addTearDown(db.closeForTesting);
    final reader = WorkAppReader(db, SecureConfig.forTesting(const FlutterSecureStorage()));
    final token = GenerationCancellationToken();
    final html = 'a' * 4199 + '🐳<p>真实正文</p>';
    final version = CreativeContract.hash(html);
    Future<void> save(String id, {bool hidden = false}) async {
      await db.setSetting('${CreativeContract.metaPrefix}$id', jsonEncode({'id': id, 'current': version,
        'title': id, 'updated': 1, 'status': 'ready', if (hidden) 'origin': 'autonomous'}));
    }
    await save('work'); await save('private', hidden: true);
    await db.setSetting('${CreativeContract.sourcePrefix}$version', html);
    final list = await reader.read({'section': 'works'}, token);
    expect((list['items'] as List).single['id'], 'work');
    final first = await reader.read({'section': 'source', 'id': 'work'}, token);
    final rest = await reader.read({'section': 'source', 'id': 'work', 'version': version,
        'offset': first['next_offset']}, token);
    expect('${first['html']}${rest['html']}', html);
    await expectLater(reader.read({'section':'source','id':'private'}, token), throwsFormatException);
    await expectLater(reader.read({'section':'source','id':'work','version':'old','offset':10}, token), throwsFormatException);
    final original = await reader.read({'section':'original','id':'missing'}, token);
    expect(original['error'], 'album_item_unavailable');
    final session = jsonEncode({'id':'s1','game_id':'garden','last_outcome':'本轮收获两朵花','updated_at':123456});
    await db.setSetting(CedarToyActivityStore.sessionSettingKey, session);
    final game = await reader.read({'section':'game'}, token);
    expect(game['last_outcome'], '本轮收获两朵花');
    expect(game['source_kind'], contains('本机'));
    expect(await db.getSetting(CedarToyActivityStore.sessionSettingKey), session);
    final help = await reader.read({'section':'help'}, token);
    expect(help['registered_only'], contains('理解视频片段'));
  });

  test('model draft is staged and only a separate user apply invokes the write channel', () async {
    final token = GenerationCancellationToken();
    var round = 0;
    String? proposal;
    final snapshot = WorkTextSnapshot('1.txt', '原文');
    final report = await ResearchCommission.run(goal: '在末尾加上123', context: [], reference: snapshot,
      cancellation: token, progress: (_, __) {}, proposeEdit: (value) => proposal = value,
      plan: (_) async => (content:'待预览', reasoning:'', finishReason:'stop',
        toolCalls: round++ == 0 ? [DeepSeekToolCall(id:'edit',name:WorkTextReference.editToolName,
          arguments:jsonEncode({'text':'原文\n123'}))] : <DeepSeekToolCall>[]));
    expect(proposal, '原文\n123');
    expect((report['evidence'] as List).single['display'], contains('等待'));
    expect(jsonEncode(report), isNot(contains('原文')));
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(CommissionWorkspace.channel, (call) async {
      expect(call.method, 'workReferenceApply');
      expect(call.arguments['expected'], snapshot.digest);
      expect(call.arguments['key'], 'selected');
      expect(call.arguments['text'], proposal);
      throw PlatformException(code: 'reference_write', message: '文件已变化');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(CommissionWorkspace.channel, null));
    await expectLater(const WorkTextReference('selected','1.txt').apply(snapshot.digest, proposal!),
      throwsA(isA<PlatformException>()));
  });

  test('a selected reference rereads edits; revoked and removed grants cannot reuse old bytes', () async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var body = '第一版', valid = true;
    messenger.setMockMethodCallHandler(CommissionWorkspace.channel, (call) async {
      if (call.method == 'workReferenceChoose') return {'key': 'opaque', 'name': '清单.txt'};
      expect(call.arguments['key'], 'opaque');
      if (call.method == 'workReferenceForget') {
        valid = false;
        return null;
      }
      if (!valid) throw PlatformException(code: 'unavailable');
      return {'name': '清单.txt', 'text': body};
    });
    addTearDown(() => messenger.setMockMethodCallHandler(CommissionWorkspace.channel, null));
    final ref = (await WorkTextReference.choose())!;
    final before = await ref.read();
    body = '第二版';
    final after = await ref.read();
    expect(after.text, '第二版');
    expect(after.digest, isNot(before.digest));
    expect(after.receipt.values, isNot(contains(body)));
    valid = false;
    await expectLater(ref.read(), throwsA(isA<PlatformException>()));
    valid = true;
    await ref.forget();
    await expectLater(ref.read(), throwsA(isA<PlatformException>()));
  });

  test(
    'a +475 task can be resumed twice in order without copying another thread',
    () async {
      final dir = await Directory.systemTemp.createTemp();
      addTearDown(() => dir.delete(recursive: true));
      final ws = CommissionWorkspace(directory: dir);
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      addTearDown(db.closeForTesting);
      FlutterSecureStorage.setMockInitialValues({
        'deepseek_api_key': 'fixture',
      });
      final config = SecureConfig.forTesting(const FlutterSecureStorage());
      const id = '00000000-0000-0000-0000-000000000001';
      const file = '任务-$id.json';
      await ws.write(
        file,
        jsonEncode({
          'id': id,
          'goal': '原问题',
          'answer': '原回答',
          'state': 'completed',
          'at': 1,
        }),
      );
      const other = '00000000-0000-0000-0000-000000000002';
      await ws.write(
        '任务-$other.json',
        jsonEncode({'id': other, 'goal': '无关问题', 'state': 'stopped', 'at': 2}),
      );
      final requests = <String>[];
      final client = DeepSeekClient(
        streamClientFactory: () => MockClient((r) async {
          requests.add(r.body);
          return http.Response(
            'data: {"choices":[{"delta":{"content":"工作结果"},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n',
            200,
            headers: {'content-type': 'text/event-stream; charset=utf-8'},
          );
        }),
      );
      addTearDown(client.close);
      var latest = file;
      for (final goal in ['再查一个', '继续看看']) {
        await ws.write('报告-$goal.md', goal);
        await CommissionSession.run(
          workspace: ws,
          goal: goal,
          client: client,
          db: db,
          config: config,
          cancel: GenerationCancellationToken(),
          progress: (_) {},
          reference: goal == '再查一个' ? WorkTextSnapshot('清单.md', 'snapshot-fixture-441') : null,
          previousTask: latest,
          onRecordCreated: (name) => latest = name,
        );
      }
      final rows = await ws.conversation(file);
      expect(rows.map((r) => r['goal']), ['原问题', '再查一个', '继续看看']);
      expect(rows.last['steps'], contains('正在整理结果'));
      expect(CommissionThread.history(rows).length, 6);
      // Real serialized requests preserve the previous transcript when the
      // workspace catalog changes. The final composition shares the front.
      List messages(int n) => jsonDecode(requests[n])['messages'] as List;
      final first = messages(0), finalReply = messages(1), follow = messages(2);
      expect(requests.length, 4);
      expect(requests.take(2).every((r) => r.contains('snapshot-fixture-441')), isTrue);
      expect(requests.skip(2).every((r) => !r.contains('snapshot-fixture-441')), isTrue);
      expect(rows[1]['text_reference']['name'], '清单.md');
      expect(jsonEncode(rows), isNot(contains('snapshot-fixture-441')));
      expect(rows.last.containsKey('text_reference'), isFalse);
      expect(finalReply.take(first.length).toList(), first);
      final catalog = first.indexWhere((m) => m['content'].contains('工作区文件索引'));
      expect(catalog, greaterThan(1));
      expect(follow.take(catalog).toList(), first.take(catalog).toList());
      expect(first[catalog - 1]['content'], '再查一个');
      expect(follow[follow.length - 1]['content'], contains('报告-继续看看.md'));
      expect(rows.last['endedAt'], isA<int>());
      expect(rows.last['elapsedMs'], greaterThanOrEqualTo(0));
      expect(requests.last, contains('原回答'));
      expect(requests.last, isNot(contains('无关问题')));
      expect((await ws.conversations()).length, 2);
      List names(String request) => (jsonDecode(request)['tools'] as List)
          .map((t) => t['function']['name']).toList();
      expect(names(requests.first), contains('work_history_search'));
      requests.clear();
      await CommissionSession.run(
        workspace: ws, goal: '新任务', client: client, db: db, config: config,
        cancel: GenerationCancellationToken(), progress: (_) {},
      );
      expect(names(requests.first), isNot(contains('work_history_search')));
      expect(names(requests.first), contains('github_read_readme'));

    },
  );

  test(
    'work history tool feeds a prior source to the planner and final route only inside its thread',
    () async {
      final dir = await Directory.systemTemp.createTemp();
      addTearDown(() => dir.delete(recursive: true));
      final ws = CommissionWorkspace(directory: dir);
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      addTearDown(db.closeForTesting);
      FlutterSecureStorage.setMockInitialValues({
        'deepseek_api_key': 'fixture',
      });
      final config = SecureConfig.forTesting(const FlutterSecureStorage());
      String id(int n) =>
          '00000000-0000-0000-0000-${n.toString().padLeft(12, '0')}';
      for (int n = 1; n <= 13; n++) {
        await ws.write(
          '任务-${id(n)}.json',
          jsonEncode({
            'id': id(n),
            'threadId': n == 13 ? id(13) : id(1),
            'state': 'completed',
            'goal': '问题 $n',
            'answer': n == 1
                ? '离线口令 ALPHA'
                : n == 13
                ? '离线口令 PRIVATE'
                : '普通交付',
          }),
        );
      }
      final requests = <String>[];
      final client = DeepSeekClient(
        streamClientFactory: () => MockClient((r) async {
          requests.add(r.body);
          final first = requests.length == 1;
          final delta = first
              ? {
                  'tool_calls': [
                    {
                      'index': 0,
                      'id': 'lookup',
                      'type': 'function',
                      'function': {
                        'name': 'work_history_search',
                        'arguments': '{"query":"离线口令"}',
                      },
                    },
                  ],
                }
              : {'content': '已找到'};
          final event = {
            'choices': [
              {'delta': delta, 'finish_reason': first ? 'tool_calls' : 'stop'},
            ],
          };
          return http.Response(
            'data: ${jsonEncode(event)}\n\ndata: [DONE]\n\n',
            200,
            headers: {'content-type': 'text/event-stream; charset=utf-8'},
          );
        }),
      );
      addTearDown(client.close);
      await CommissionSession.run(
        workspace: ws,
        goal: '早先的离线口令是什么',
        client: client,
        db: db,
        config: config,
        cancel: GenerationCancellationToken(),
        progress: (_) {},
        previousTask: '任务-${id(12)}.json',
      );
      expect(requests.length, 3);
      expect(requests.first, isNot(contains('ALPHA')));
      expect(requests[1], contains('ALPHA'));
      expect(requests.last, contains('ALPHA'));
      expect(requests.join(), isNot(contains('PRIVATE')));
      final newest = (await ws.conversation('任务-${id(1)}.json')).last;
      expect(newest['evidence'], isEmpty);
      expect((newest['receipts'] as List).single['excerpts'], 1);
    },
  );

  test(
    'a rate-limited work request yields to chat and stopping it preserves the chat reply',
    () async {
      final dir = await Directory.systemTemp.createTemp();
      addTearDown(() => dir.delete(recursive: true));
      final workspace = CommissionWorkspace(directory: dir);
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      addTearDown(db.closeForTesting);
      FlutterSecureStorage.setMockInitialValues({
        'deepseek_api_key': 'fixture',
      });
      final config = SecureConfig.forTesting(const FlutterSecureStorage());
      final limited = Completer<void>(),
          finishChat = Completer<void>(),
          chatStarted = Completer<void>();
      final token = GenerationCancellationToken();
      var workRequests = 0;
      final work = DeepSeekClient(
        streamClientFactory: () => MockClient((r) async {
          expect(r.headers['Authorization'], 'Bearer fixture');
          workRequests++;
          return http.Response('too many requests', 429);
        }),
      );
      final chat = DeepSeekClient(
        streamClientFactory: () => MockClient((r) async {
          expect(r.headers['Authorization'], 'Bearer fixture');
          chatStarted.complete();
          await finishChat.future;
          return http.Response(
            'data: {"choices":[{"delta":{"content":"hello"},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n',
            200,
          );
        }),
      );
      addTearDown(work.close);
      addTearDown(chat.close);
      final pending = CommissionSession.run(
        workspace: workspace,
        goal: '读工作记录',
        client: work,
        db: db,
        config: config,
        cancel: token,
        chatBusy: () => !finishChat.isCompleted,
        progress: (s) {
          if (s.contains('限流') && !limited.isCompleted) limited.complete();
        },
      );
      final stopped = expectLater(
        pending,
        throwsA(isA<GenerationCancelledByUserException>()),
      );
      await limited.future.timeout(const Duration(seconds: 8));
      final reply = chat
          .streamChat(
            apiKey: 'fixture',
            model: DeepSeekModelProfile.flash,
            effort: ReasoningEffort.high,
            messages: [
              {'role': 'user', 'content': '普通聊天'},
            ],
          )
          .map((d) => d.content)
          .join();
      await chatStarted.future;
      await Future<void>.delayed(const Duration(milliseconds: 1150));
      expect(workRequests, 1);
      token.cancel();
      await stopped;
      finishChat.complete();
      expect(await reply, 'hello');
      final record = jsonDecode(
        await workspace.read((await workspace.list()).single),
      );
      expect(record['state'], 'stopped');
    },
  );

  testWidgets(
    'floating whale passes outside taps through and snaps to either edge',
    (tester) async {
      var chats = 0, opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: TextButton(
                    onPressed: () => chats++,
                    child: const Text('普通聊天'),
                  ),
                ),
                WorkOrb(
                  phase: WorkPhase.tool,
                  open: false,
                  toggle: () => opens++,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('普通聊天'));
      await tester.pump();
      expect(chats, 1);
      final orb = find.byTooltip('打开工作窗口');
      await tester.tap(orb);
      expect(opens, 1);
      final initial = tester.getCenter(orb);
      await tester.drag(orb, Offset(-initial.dx, 80));
      await tester.pump();
      expect(tester.getCenter(orb).dx, lessThan(50));
      final icon = tester.widget<Image>(
        find.descendant(of: orb, matching: find.byType(Image)),
      );
      expect((icon.image as AssetImage).assetName, endsWith('twist.webp'));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
