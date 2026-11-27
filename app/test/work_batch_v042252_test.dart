import 'dart:convert';
import 'package:ai_companion_localfirst/core/agent/work_turn_details.dart';
import 'dart:io';
import 'package:ai_companion_localfirst/core/agent/work_text_reference.dart';
import 'package:ai_companion_localfirst/core/agent/commission_workspace.dart';
import 'package:ai_companion_localfirst/core/agent/workspace_archive.dart';
import 'package:ai_companion_localfirst/core/agent/work_quiz.dart';
import 'package:ai_companion_localfirst/core/agent/work_host_actions.dart';
import 'package:ai_companion_localfirst/core/agent/research_commission.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/phone/calendar_reminder_store.dart';
import 'package:ai_companion_localfirst/core/creative/creative_contract.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const id = '269254ed-86bc-4613-bffa-142a78ea5755';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  void mock(Future<dynamic> Function(MethodCall) fn) {
    messenger.setMockMethodCallHandler(CommissionWorkspace.channel, fn);
    addTearDown(
      () =>
          messenger.setMockMethodCallHandler(CommissionWorkspace.channel, null),
    );
  }

  Future<CommissionWorkspace> workspace() async {
    final dir = await Directory.systemTemp.createTemp('work496_');
    addTearDown(() => dir.delete(recursive: true));
    return CommissionWorkspace(directory: dir);
  }

  DeepSeekToolCall call(String name, Map args) =>
      DeepSeekToolCall(id: 't', name: name, arguments: jsonEncode(args));
  ResearchPlan plan([DeepSeekToolCall? c]) => (
    content: '交付',
    reasoning: '',
    finishReason: 'stop',
    toolCalls: [if (c != null) c],
  );

  for (final change in ['reschedule','cancel']) {
    test('same-order $change supersedes the creation receipt on resume',() async {
      final db=await AppDatabase.createForTesting(databaseFactoryFfi);
      addTearDown(db.closeForTesting); mock((_) async=>true);
      final goal='明天九点提醒我喝水，${change=='cancel'?'取消喝水提醒':'把喝水提醒改到十点'}';
      WorkHostActions host()=>WorkHostActions(db,'mixed','T',WorkHostActions.requested(goal),GenerationCancellationToken(),goal:goal);
      final day=DateTime.now().add(const Duration(days:2)).toIso8601String().substring(0,10);
      final h=host();
      final created=await h.execute({'action':'remind','text':'喝水','local_time':'${day}T09:00'});
      final initial=await db.getSetting(CalendarReminderStore.settingKey);
      final changed=await h.execute({'action':change,'target':'喝水',if(change=='reschedule')'local_time':'${day}T10:00'});
      expect(created['id'],changed['id']);
      final result=await ResearchCommission.run(goal:goal,context:[],workspace:await workspace(),host:host(),
        cancellation:GenerationCancellationToken(),progress:(_,__) {},plan:(_)async=>plan());
      expect(result['end'],'planner_finished');
      expect((await host().execute({'action':'remind','text':'喝水','local_time':'${day}T09:00'}))['reused'],true);
      final live=await CalendarReminderStore(db).load();
      if(change=='cancel') { expect(live,isEmpty); } else { expect(live.single.hour,10); }
      await db.setSetting(CalendarReminderStore.settingKey,initial!);
      await expectLater(host().verifyExisting(),throwsStateError);
    });
  }

  for(final resume in [false,true]) {
    test('separate cancellation receipts across restart $resume',() async {
      final db=await AppDatabase.createForTesting(databaseFactoryFfi);
      addTearDown(db.closeForTesting); mock((_)async=>true);
      WorkHostActions host(String order,String goal)=>WorkHostActions(db,order,'T',WorkHostActions.requested(goal),GenerationCancellationToken(),goal:goal);
      const create='明天九点提醒我喝水，十点提醒我取快递';
      final day=DateTime.now().add(const Duration(days:2)).toIso8601String().substring(0,10);
      final creator=host('initial',create);
      for(final (title,hour) in [('喝水','09'),('取快递','10')]){
        await creator.execute({'action':'remind','text':title,'local_time':'${day}T$hour:00'});
      }
      expect(await CalendarReminderStore(db).load(),hasLength(2));
      final task=resume?'取消喝水和取快递提醒':'取消喝水提醒，取消取快递提醒';
      final first=host('cancel-both',task);
      final a=await first.execute({'action':'cancel','target':'喝水'});
      final use=resume?host('cancel-both',task):first;
      if(resume) await use.verifyExisting();
      expect(use.confirmed, isNot(contains('cancel')));
      final replay=await use.execute({'action':'cancel','target':'喝水'});
      expect(replay['id'],a['id']); expect(replay['reused'],true);
      expect(use.confirmed,isNot(contains('cancel')));
      final b=await use.execute({'action':'cancel','target':'取快递'});
      final result=await ResearchCommission.run(goal:task,context:[],workspace:await workspace(),
        host:use, cancellation:GenerationCancellationToken(),progress:(_,__) {},plan:(_)async=>plan());
      expect(await CalendarReminderStore(db).load(),isEmpty);
      expect(b['id'],isNot(a['id'])); expect(b['reused'],false);
      expect(result['end'],'planner_finished');
    });
  }

  test(
    'compound reminders survive partial resume; named changes stay scoped',
    () async {
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      addTearDown(db.closeForTesting);
      mock((c) async => true);
      WorkHostActions host(String order, String goal) => WorkHostActions(
        db,
        order,
        'thread',
        WorkHostActions.requested(goal),
        GenerationCancellationToken(),
        goal: goal,
      );
      const goal = '明天九点提醒我喝水，十点提醒我取快递';
      final day = DateTime.now()
          .add(const Duration(days: 2))
          .toIso8601String()
          .substring(0, 10);
      final drink = {
        'action': 'remind',
        'text': '喝水',
        'local_time': '${day}T09:00',
      };
      final parcel = {
        'action': 'remind',
        'text': '取快递',
        'local_time': '${day}T10:00',
      };
      final one = host('one', goal);
      await one.execute(drink);
      expect(one.confirmed, isEmpty);
      final resumed = host('one', goal);
      await resumed.verifyExisting();
      expect(resumed.confirmed, isEmpty);
      expect((await resumed.execute(drink))['reused'], true);
      await expectLater(
        resumed.execute({...drink, 'local_time': '${day}T09:15'}),
        throwsFormatException,
      );
      await expectLater(host('protected','保留喝水提醒，取消取快递提醒')
          .execute({'action':'cancel'}), throwsFormatException);
      expect((await CalendarReminderStore(db).load()).single.title, '喝水');
      await resumed.execute(parcel);
      expect(resumed.confirmed, {'remind'});
      expect(await host('one', goal).verifyExisting(), hasLength(2));
      expect(WorkHostActions.requested('取消喝水提醒，等等，别取消了'), isEmpty);
      await expectLater(
        host('two', '取消喝水提醒').execute({'action': 'cancel', 'target': '取快递'}),
        throwsFormatException,
      );
      await expectLater(
        host('two', '取消跑步提醒').execute({'action': 'cancel'}),
        throwsFormatException,
      );
      await host(
        'two',
        '把喝水提醒改到明天十一点',
      ).execute({'action': 'reschedule', 'local_time': '${day}T11:00'});
      await host(
        'three',
        '取消喝水提醒',
      ).execute({'action': 'cancel', 'target': '喝水'});
      expect((await CalendarReminderStore(db).load()).single.title, '取快递');
    },
  );

  test(
    'offline rejects actual retrieval, ordinary research still sends',
    () async {
      for (final offline in [true, false]) {
        var httpCalls = 0, rounds = 0;
        final transport = MockClient((req) async {
          httpCalls++;
          return http.Response('{"items":[]}', 200);
        });
        await ResearchCommission.run(
          goal: offline ? '只根据附件整理，不要联网' : '搜开源项目',
          context: [],
          transport: transport,
          cancellation: GenerationCancellationToken(),
          progress: (_, __) {},
          plan: (_) async => plan(
            rounds++ == 0
                ? call(ResearchCommission.search, {'query': 'demo'})
                : null,
          ),
        );
        expect(httpCalls, offline ? 0 : 1);
      }
    },
  );

  test(
    'zero clicks for self-answer, exact limit retains official result, default and text-only captures',
    () async {
      final ws = await workspace();
      const png =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+i1JkAAAAASUVORK5CYII=';
      var clicks = 0, captures = 0, wall = false;
      mock((c) async {
        switch (c.method) {
          case 'workPageOpen':
          case 'workPageRead':
            return jsonEncode(
              clicks == 1
                  ? {'key': 'r', 'title': '正式结果', 'summary': '官网摘要'}
                  : {
                      'key': 'q',
                      'wall': wall,
                      'question': '第一题',
                      'controls': [
                        {'kind': 'button', 'name': 'A'},
                      ],
                    },
            );
          case 'workPageAct':
            clicks++;
            return 'ok';
          case 'workPageResult':
            captures++;
            return jsonEncode([png]);
          case 'workPageFrame':
            captures++;
            return png;
          case 'workQuizClose':
            return null;
          default:
            throw StateError(c.method);
        }
      });
      Future<Map> run(String goal, {String decision = '{"id":0}'}) =>
          WorkQuiz.run(
            uri: Uri.parse('https://example.org/quiz'),
            order: id,
            id: id,
            goal: goal,
            workspace: ws,
            cancel: GenerationCancellationToken(),
            answers: [],
            save: () async {},
            ask: (_) async => decision,
            vision: (_) async => '',
            progress: (_) {},
          );
      final handoff = await run('找个测试让我自己答，别替我答');
      expect(handoff['forUser'], true);
      expect(clicks, 0);
      expect(WorkQuiz.forUser('不用我答，你自己做'), false);
      for (final allowed in [false, true]) {
        clicks = 0;
        captures = 0;
        final result = await run(allowed ? '你来答一道题' : '你来答一道题，只告诉我文字结果');
        expect(result['title'], '正式结果');
        expect(result['summary'], '官网摘要');
        expect(clicks, 1);
        expect(captures, allowed ? 1 : 0);
        expect(result.containsKey('photos'), allowed);
      }
      clicks = 0;
      captures = 0;
      final textOnly = await run('做完这个测试，不要发最终结果截图');
      expect(textOnly['summary'], '官网摘要');
      expect(textOnly.containsKey('photos'), false);
      expect(captures, 0);
      clicks = 0;
      wall = true;
      expect((await run('不要截图 做测试'))['error'], isNotNull);
      expect(captures, 0);
      wall = false;
      expect(
        (await run(
          '只要文字结果',
          decision: '{"finish":"已完成","capture":true}',
        ))['photos'],
        isNull,
      );
      expect(captures, 0);
      expect(WorkQuiz.photosAllowed('不需要每题截图，最后结果截图'), true);
      expect(WorkQuiz.photosAllowed('不需要每题截图', finalResult: true), true);
    },
  );

  test('attachment scope and named report apply to planner input and resumed receipts', () async {
    final ws = await workspace();
    await ws.write('报告-无关.md', 'PRIVATE_WORKSPACE_MARKER');
    await ws.write('报告-周报.md', 'PRIVATE_DESTINATION_MARKER');
    const goal = '只根据这份附件，请更新并保存报告-周报.md';
    final receipts = <Map<String,Object?>>[];
    Future<Map> run(List<DeepSeekToolCall> ops, {List<Map> prior = const []}) {
      var round = 0;
      return ResearchCommission.run(goal: goal, context: [
        {'role':'user', 'content':'PRIVATE_WORKSPACE_MARKER'},
      ], workspace: ws,
        priorReports: prior, reference: WorkTextSnapshot('素材.txt', 'SELECTED_INPUT'),
        cancellation: GenerationCancellationToken(), progress: (_, __) {},
        onToolResult: receipts.add,
        plan: (messages) async {
          final visible = jsonEncode(messages);
          expect(visible, isNot(contains('PRIVATE_WORKSPACE_MARKER')));
          expect(visible, isNot(contains('PRIVATE_DESTINATION_MARKER')));
          return plan(round < ops.length ? ops[round++] : null);
        });
    }
    DeepSeekToolCall save(String title) => call('workspace_save',
        {'kind':'报告', 'title':title, 'body':'据附件更新'});
    await expectLater(run([
      call('workspace_read', {'name':'报告-无关.md'}), save('随笔'),
    ]), throwsStateError);
    expect(await ws.list(), isNot(contains('报告-随笔.md')));
    expect(await ws.read('报告-周报.md'), 'PRIVATE_DESTINATION_MARKER');
    await run([call('workspace_read', {'name':'报告-周报.md'}), save('周报')],
      prior: receipts.where((r) => r.containsKey('reportTarget')).toList());
    expect(await ws.read('报告-周报.md'), '据附件更新');
    expect(receipts.any((r) => r['saved'] == '报告-周报.md'), true);
  });

  for (final goal in ['生成并保存报告，文件名是报告-周报.md','创建报告-周报.md','请更新并保存报告-周报.md']) {
    test('named report must be written $goal',() async {
      final ws = await workspace();
      var round=0;
      final result=ResearchCommission.run(goal:goal,workspace:ws,context:[],
        cancellation:GenerationCancellationToken(),progress:(_,__) {},
        plan:(_) async => plan(round++ == 0 ? call('workspace_save',
          {'kind':'报告','title':'错名','body':'合成资料测试'}) : null));
      await expectLater(result,throwsStateError);
      expect(await ws.list(),isNot(contains('报告-错名.md')));
      expect(ResearchCommission.reportTargets(goal), {'报告-周报.md'});
    });
  }
  test('attachments used alongside web inputs',() {
    expect(ResearchCommission.offline('只根据附件写报告'),true);
    expect(ResearchCommission.offline('不要只根据附件，也不要联网'),true);
    expect(ResearchCommission.attachmentOnly('不要只根据附件，也不要联网'),false);
    expect(ResearchCommission.reportTargets('生成并保存报告，读取报告-资料.md做参考'),isEmpty);
    expect(ResearchCommission.reportTargets('把报告-甲.md另存为报告-乙.md'), {'报告-乙.md'});
    expect(ResearchCommission.offline('结合附件和网上资料写报告'),false);
    expect(ResearchCommission.offline('不要只根据附件，还要联网对照'),false);
  });

  test(
    'report write failure remains pending until a verified write succeeds',
    () async {
      final ws = await workspace();
      final original = '甲' * 16001;
      await ws.write('报告-原文.md', original);
      final failed = <Map<String, Object?>>[];
      var round = 0;
      Future<Map> run(List<Map> prior, List<DeepSeekToolCall> ops) {
        final activity = WorkTurnDetails();
        return ResearchCommission.run(
          goal: '修改报告并保存',
          context: [],
          workspace: ws,
          priorReports: prior,
          cancellation: GenerationCancellationToken(),
          progress: (_, __) {},
          onToolStart: activity.beginTool,
          onToolResult: (result) {
            expect(activity.receipts.last['state'], 'pending');
            activity.finishTool(result);
            failed.add(result);
          },
          plan: (_) async => plan(round < ops.length ? ops[round++] : null),
        );
      }

      final read = call('workspace_read', {'name': '报告-原文.md'});
      final bad = call('workspace_save', {
        'kind': '报告',
        'title': '原文',
        'body': '截断',
      });
      await expectLater(run([], [read, bad]), throwsStateError);
      expect(await ws.read('报告-原文.md'), original);
      final prior = failed.where((r) => r['reportTarget'] != null).toList();
      failed.clear();
      round = 0;
      await run(prior, [
        read,
        call('workspace_save', {
          'kind': '报告',
          'title': '原文',
          'body': '乙',
          'old_text': original,
        }),
      ]);
      expect(await ws.read('报告-原文.md'), '乙');
      final saved = failed.where((r) => r['saved'] != null).toList();
      round = 0;
      await run(saved, []);
    },
  );

  test(
    'external HTML edit survives resume and subsequent verified reuse',
    () async {
      final ws = await workspace();
      final candidate = await ws.savePage('原作', '<b>旧</b>', null);
      await ws.write(candidate, '手动修改');
      final events = <String?>[];
      var rounds = 0;
      final result = await ResearchCommission.run(
        goal: '做个网页',
        context: [],
        workspace: ws,
        candidateHtml: candidate,
        expectedDigest: CreativeContract.hash('<b>旧</b>'),
        onHtmlCandidate: (n) async => events.add(n),
        plan: (_) async => plan(
          rounds++ == 0
              ? call(ResearchCommission.deliverHtml, {
                  'title': '原作',
                  'html': '<b>新</b>',
                })
              : null,
        ),
        cancellation: GenerationCancellationToken(),
        progress: (_, __) {},
      );
      final copy = result['delivered_html'] as String;
      expect(events.first, isNull);
      expect(copy, isNot(candidate));
      expect(await ws.read(candidate), '手动修改');
      final page = await ws.readHtml(copy);
      final resumed = await ResearchCommission.run(
        goal: '做个网页',
        context: [],
        workspace: ws,
        candidateHtml: copy,
        expectedDigest: CreativeContract.hash(page),
        plan: (_) async => plan(),
        cancellation: GenerationCancellationToken(),
        progress: (_, __) {},
      );
      expect(resumed['delivered_html'], copy);
    },
  );

  test(
    'archive merge remaps incoming cards only and repeated import reuses files',
    () async {
      final source = await workspace(), target = await workspace();
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      messenger.setMockMethodCallHandler(
        paths,
        (_) async => source.directory!.path,
      );
      addTearDown(() => messenger.setMockMethodCallHandler(paths, null));
      final zip = File('${source.directory!.path}/copy.zip');
      mock((c) async {
        if (c.method == 'saveCollectedStickerZip') {
          await File(c.arguments['sourcePath'] as String).copy(zip.path);
          return {'verified': true};
        }
        if (c.method == 'openPlainBackup') return {'filePath': zip.path};
        throw StateError(c.method);
      });
      const page = '<i>源作品</i>';
      final name = await source.savePage('同名', page, null);
      await target.savePage('同名', '<b>本机</b>', null);
      final card = {'artifact': name, 'digest': CreativeContract.hash(page)};
      await source.mergeTurns('会话-$id.json', [
        {
          'id': id,
          'threadId': id,
          'goal': name,
          'htmlCandidate': name,
          'receipts': [card],
          'evidence': [card],
        },
      ]);
      for (var i = 0; i < 2; i++) {
        await WorkspaceArchive.export(source);
        await WorkspaceArchive.import(target);
        final row = (await target.conversation('会话-$id.json')).single;
        final actual = row['receipts'].first['artifact'] as String;
        expect(row['goal'], name);
        expect(row['htmlCandidate'], actual);
        expect(row['evidence'].first['artifact'], actual);
        expect(
          await target.readHtml(actual, expectedDigest: card['digest']),
          page,
        );
        expect(await target.readHtml(name), '<b>本机</b>');
        expect(
          (await target.list()).where((n) => n.endsWith('.html')),
          hasLength(2),
        );
      }
    },
  );
}
