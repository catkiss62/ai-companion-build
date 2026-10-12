import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/creative/creative_contract.dart';
import 'package:ai_companion_localfirst/core/creative/creative_play.dart';
import 'package:ai_companion_localfirst/core/creative/creative_store.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/generation_job.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late CreativePlay play;
  var captureSequence = 0;

  setUp(() async {
    captureSequence = 0;
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    final store = CreativeStore(db);
    final work = await store.commission(
      deepThinking: true, requestId: 'commission', messageId: 'commission-card',
      brief: '制作卡片', requestQuote: '制作卡片', latestText: '制作卡片',
    );
    const html = '<p>作品卡片</p>';
    final version = CreativeContract.hash(html);
    await store.write(work, {...work, 'status': 'ready', 'current': version,
      'versions': [version]}, extra: {'${CreativeContract.sourcePrefix}$version': html});
    play = CreativePlay(db, work['id'] as String);
    await play.open();
  });
  tearDown(() async => db.closeForTesting());

  Future<GenerationJob> send(String id, {
    String generationStatus = 'completed',
    String? postTurnStatus,
    int? capturedAt,
  }) async {
    final snapshot = await play.captureSnapshot(observation: {'text': 'page:$id'});
    // Deterministic ordering, independent of how fast SQLite runs the test.
    snapshot.data['captured_at'] = capturedAt ?? ++captureSequence;
    final job = await db.createGenerationTurn(
      user: ChatMessage(id: id, role: 'user', content: '看看这一页', createdAt: DateTime.now()),
      assistantMessageId: 'a:$id', model: 'deepseek-flash', reasoningEffort: 'high',
      creativeContext: snapshot.data, creativeFence: snapshot.fence,
    );
    // Simulate provider/queue progression without making a network request.
    await (await db.database).update('generation_jobs', {'status': generationStatus},
      where: 'id = ?', whereArgs: [job.id]);
    if (generationStatus == 'completed') {
      await db.insertMessage(ChatMessage(id: 'a:$id', role: 'assistant',
        content: '看到了这一页。', createdAt: DateTime.now()));
    }
    if (postTurnStatus != null) {
      await db.enqueuePostTurnJob(userMessageId: id, assistantMessageId: 'a:$id');
      await (await db.database).update('post_turn_jobs', {'status': postTurnStatus},
        where: 'user_message_id = ?', whereArgs: [id]);
    }
    return job;
  }

  Future<Set<String>> retainedUsers() async {
    final rows = await (await db.database).query('settings', columns: ['key'],
      where: 'key LIKE ?', whereArgs: ['${CreativeContract.chatPrefix}%']);
    return rows.map((row) => (row['key'] as String)
      .substring(CreativeContract.chatPrefix.length)).toSet();
  }

  test('delayed memory work keeps its message snapshots across overflow and restore, then releases them', () async {
    const states = ['pending', 'running', 'retry_wait', 'failed'];
    final protected = <String>{};
    for (final state in states) {
      final id = 'maintenance-$state';
      protected.add(id);
      await send(id, postTurnStatus: state);
    }
    for (var i = 0; i < 12; i++) {
      await send('history-$i');
    }
    expect(await retainedUsers(), containsAll(protected));
    // Eight unreferenced historical snapshots plus the turn currently being
    // created are retained; unfinished maintenance is additional dependency data.
    expect((await retainedUsers()).difference(protected), hasLength(9));

    await db.importAll(Map<String, dynamic>.from(await db.exportAll()));
    expect(await retainedUsers(), containsAll(protected));
    for (final id in protected) {
      expect(await CreativePlay.chatContext(db, userMessageId: id), contains('page:$id'));
    }

    await (await db.database).update('post_turn_jobs', {'status': 'done'});
    await play.open();
    await send('after-maintenance');
    final remaining = await retainedUsers();
    expect(remaining.intersection(protected), isEmpty);
    expect(remaining, hasLength(9));
    expect(remaining, contains('after-maintenance'));
  });

  test('failed reply and current old-timestamp turn stay retained until cancellation', () async {
    final failed = await send('failed-reply', generationStatus: 'failed');
    for (var i = 0; i < 12; i++) {
      await send('history-$i');
    }
    expect(await retainedUsers(), contains('failed-reply'));
    final current = await send('clock-regressed', generationStatus: 'pending', capturedAt: 0);
    final retained = await retainedUsers();
    expect(retained, containsAll(['failed-reply', 'clock-regressed']));
    expect(retained.difference({'failed-reply', 'clock-regressed'}), hasLength(8));
    expect(await db.messageById('clock-regressed'), isNotNull);

    expect(await db.cancelGenerationJobByUser(current.id), isTrue);
    expect(await db.abandonFailedGenerationJob(failed.id), isTrue);
    await send('after-cancellation');
    final remaining = await retainedUsers();
    expect(remaining, isNot(contains('failed-reply')));
    expect(remaining, isNot(contains('clock-regressed')));
    expect(remaining, hasLength(9));
  });

  test('blocking reply states reject a new turn before pruning any snapshot', () async {
    for (var i = 0; i < 10; i++) {
      await send('history-$i');
    }
    final active = await send('active-reply', generationStatus: 'pending', capturedAt: 0);
    final retained = await retainedUsers();
    for (final state in ['pending', 'running', 'retry_wait', 'awaiting_confirmation']) {
      await (await db.database).update('generation_jobs', {'status': state},
        where: 'id = ?', whereArgs: [active.id]);
      await expectLater(send('blocked-$state'), throwsStateError);
      expect(await retainedUsers(), unorderedEquals(retained));
      expect(await db.messageById('blocked-$state'), isNull);
    }
    expect(await CreativePlay.chatContext(db, userMessageId: 'active-reply'),
      contains('page:active-reply'));
  });
}
