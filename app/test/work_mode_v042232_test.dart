import 'dart:async';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'dart:convert';
import 'dart:io';
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
        await CommissionSession.run(
          workspace: ws,
          goal: goal,
          client: client,
          db: db,
          config: config,
          cancel: GenerationCancellationToken(),
          progress: (_) {},
          previousTask: latest,
          onRecordCreated: (name) => latest = name,
        );
      }
      final rows = await ws.conversation(file);
      expect(rows.map((r) => r['goal']), ['原问题', '再查一个', '继续看看']);
      expect(rows.last['steps'], contains('正在整理结果'));
      expect(CommissionThread.history(rows).length, 6);
      expect(requests.last, contains('原回答'));
      expect(requests.last, isNot(contains('无关问题')));
      expect((await ws.conversations()).length, 2);
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
