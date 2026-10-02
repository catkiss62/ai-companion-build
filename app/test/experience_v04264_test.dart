import 'dart:async';
import 'dart:convert';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/brain_work_fence.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_archive_worker.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_room_controller.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_room_repository.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_play_session_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_task_presentation.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_timed_play_task.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/memory/low_frequency_clarification.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/phone/reminder_timeliness.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late ImmersiveRoomRepository rooms;
  final at = DateTime(2026, 10, 2, 12);
  const channel = MethodChannel('ai_companion/system');
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async =>
            call.method == 'runtimeProcessEpoch' ? 'test-process' : null);
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    rooms = ImmersiveRoomRepository(db);
  });
  tearDown(() async {
    await db.closeForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<String> endedRoom() async {
    final room = await rooms.createRoom(title: '离线房间', openingScene: '海边', inheritCurrentChat: false);
    await rooms.addMessage(roomId: room.id, role: 'user', content: '保留这段原文');
    await rooms.endRoomLocally(room.id);
    return room.id;
  }
  Map<String, dynamic> archive() => {
    'archive_summary': '在虚构海边一起看星星。', 'scene_ledger': '虚构海边',
    'shared_memories': ['双方在房间里一起看过星星。'],
  };

  test('controller ends with no API key; room, original text and job are durable', () async {
    final room = await rooms.createRoom(title: '离线', openingScene: '', inheritCurrentChat: false);
    await rooms.addMessage(roomId: room.id, role: 'user', content: '不能丢失');
    final controller = ImmersiveRoomController(roomId: room.id, db: db);
    await controller.initialize();
    expect(await controller.endRoom(), isTrue);
    expect((await rooms.roomById(room.id))!.archivePending, isTrue);
    expect((await rooms.messagesForRoom(room.id)).single.content, '不能丢失');
    expect(await db.listMemories(), isEmpty);
    controller.dispose();
  });

  test('offline failure backs off, reopening retries once and never duplicates memories', () async {
    final id = await endedRoom();
    var calls = 0;
    final worker = ImmersiveArchiveWorker(db, generate: (room, messages, fence) async {
      calls++;
      if (calls == 1) throw const FormatException('offline');
      return archive();
    });
    await worker.drainOne(now: at);
    await worker.drainOne(now: at.add(const Duration(minutes: 1)));
    expect(calls, 1);
    expect((await rooms.roomById(id))!.isEnded, isTrue);
    expect((await rooms.messagesForRoom(id)).single.content, '保留这段原文');
    await worker.drainOne(now: at.add(const Duration(hours: 1)));
    expect(calls, 2);
    expect((await rooms.roomById(id))!.archivePending, isFalse);
    expect((await db.listMemories()).length, 1);
    await ImmersiveArchiveWorker(db, generate: (r, m, f) async { calls++; return archive(); }).drainOne();
    expect(calls, 2);
    expect((await db.listMemories()).length, 1);
  });

  test('summary and shared memories roll back together when a memory insert fails', () async {
    final id = await endedRoom();
    final sql = await db.database;
    await sql.execute("CREATE TRIGGER fail_archive BEFORE INSERT ON memory_items BEGIN SELECT RAISE(ABORT, 'failure'); END");
    await ImmersiveArchiveWorker(db, generate: (r, m, f) async => archive()).drainOne(now: at);
    expect((await rooms.roomById(id))!.rollingSummary, isEmpty);
    expect((await rooms.roomById(id))!.archivePending, isTrue);
    expect(await db.listMemories(), isEmpty);
    await sql.execute('DROP TRIGGER fail_archive');
    await ImmersiveArchiveWorker(db, generate: (r, m, f) async => archive())
        .drainOne(now: at.add(const Duration(hours: 1)));
    expect((await db.listMemories()).length, 1);
  });

  for (final intervention in ['delete', 'restore', 'standby']) {
    test('$intervention rejects the actual delayed archive and all shared memories', () async {
      final id = await endedRoom();
      final saved = await db.exportAll();
      final started = Completer<void>();
      final result = Completer<Map<String, dynamic>>();
      final worker = ImmersiveArchiveWorker(db, generate: (r, m, f) {
        started.complete(); return result.future;
      });
      final running = worker.drainOne(now: at);
      await started.future;
      if (intervention == 'delete') await rooms.deleteRoom(id);
      if (intervention == 'restore') await db.importAll(saved,
          runtimeSettingOverrides: {ImmersiveArchiveWorker.leaseKey: '0'});
      if (intervention == 'standby') await db.setSetting('active_brain', '0');
      result.complete(archive());
      await running;
      expect(await db.listMemories(), isEmpty);
      if (intervention == 'delete') {
        expect(await rooms.roomById(id), isNull);
        expect(await db.getSetting(ImmersiveRoomRepository.archiveKey(id)), isNull);
      } else {
        expect((await rooms.roomById(id))!.rollingSummary, isEmpty);
        expect((await rooms.roomById(id))!.archivePending, isTrue);
      }
    });
  }

  test('ended rooms cannot accept a late message or stale rolling summary', () async {
    final id = await endedRoom();
    await expectLater(rooms.addMessage(roomId: id, role: 'assistant', content: '迟到'),
        throwsA(isA<BrainWorkInvalidated>()));
    await rooms.saveRollingState(roomId: id, rollingSummary: '旧摘要', sceneLedger: '', summarizedMessageCount: 9);
    expect((await rooms.roomById(id))!.rollingSummary, isEmpty);
    expect((await rooms.messagesForRoom(id)).length, 1);
    await rooms.endRoomLocally(id);
    expect((await rooms.roomById(id))!.archivePending, isTrue);
  });

  test('concurrent workers call the provider only once', () async {
    await endedRoom();
    final started = Completer<void>();
    final result = Completer<Map<String, dynamic>>();
    var calls = 0;
    final worker = ImmersiveArchiveWorker(db, generate: (r, m, f) {
      calls++; started.complete(); return result.future;
    });
    final running = worker.drainOne();
    await started.future;
    await worker.drainOne();
    expect(calls, 1);
    result.complete(archive());
    await running;
  });

  test('game status reading never activates a staged task or consumes time', () async {
    final store = CedarToyActivityStore(db);
    final session = await store.recordGuide(gameId: 'white_room', guide: '单人游戏。start 开始；explore 探索。');
    final tasks = CedarTimedPlayTaskStore(db);
    await tasks.stage(turnId: 'turn', assistantId: 'reply', session: session, minutes: 20);
    final raw = await db.getSetting(CedarTimedPlayTaskStore.pendingKey);
    expect((await CedarTaskPresentation.load(db, session))!.label, contains('已登记'));
    expect(await tasks.active(), isNull);
    expect(await db.getSetting(CedarTimedPlayTaskStore.pendingKey), raw);
    await db.insertMessage(ChatMessage(id: 'reply', role: 'assistant', content: '好', createdAt: DateTime.now()));
    await tasks.activateCommitted();
    final active = (await tasks.active())!;
    final period = (await CedarPlaySessionStore(db).load())!;
    await CedarPlaySessionStore(db).save(period.tick(period.lastTickAt.add(const Duration(minutes: 2))));
    final before = await db.getSetting(CedarPlaySessionStore.key);
    final display = await CedarTaskPresentation.load(db, session);
    expect(display!.detail, contains('18分00秒'));
    expect(await db.getSetting(CedarPlaySessionStore.key), before);
    await db.setSetting(CedarPlaySessionStore.key, '');
    expect((await CedarTaskPresentation.load(db, session))!.label, '恢复中');
    expect((await tasks.active())!['id'], active['id']);
    await store.pause();
    expect(await tasks.active(), isNull);
    final paused = (await store.load())!;
    expect((await CedarTaskPresentation.load(db, paused))!.label, contains('已结束'));
    expect((await CedarTaskPresentation.load(db, paused))!.detail, isNot(contains('有效剩余')));
    await tasks.acknowledge(active['id'].toString());
    expect((await CedarTaskPresentation.load(db, paused))!.label, '上一时长任务已结束');
    await store.resume();
    await tasks.reconcile(DateTime.now());
    expect(await tasks.active(), isNull);
    expect(await CedarPlaySessionStore(db).load(), isNull);
  });

  test('manual pause cancels an uncommitted grant before a late reply commits', () async {
    final store = CedarToyActivityStore(db);
    final session = await store.recordGuide(gameId: 'white_room', guide: '单人游戏。start 开始；explore 探索。');
    final tasks = CedarTimedPlayTaskStore(db);
    await tasks.stage(turnId: 'late', assistantId: 'late-reply', session: session, minutes: 20);
    await store.pause();
    await db.insertMessage(ChatMessage(id: 'late-reply', role: 'assistant', content: '好', createdAt: DateTime.now()));
    await store.resume();
    await tasks.activateCommitted();
    expect(await tasks.active(), isNull);
    expect(await CedarPlaySessionStore(db).load(), isNull);
    expect(await db.getSetting(CedarTimedPlayTaskStore.pendingKey), isEmpty);
  });

  test('old reminder timing never means the task was completed or still actionable', () {
    final late = ReminderTimeliness(at.subtract(const Duration(days: 1)), at);
    expect(late.prompt, contains('往日未送达'));
    expect(late.prompt, contains('不能当作今天刚到点'));
    expect(late.prompt, contains('不知道事项是否仍有效或已经完成'));
    expect(ReminderTimeliness(at.add(const Duration(hours: 1)), at).future, isTrue);
    expect(ReminderTimeliness.label(at, at), contains('完成情况未知'));
  });

  Future<void> mixedLearning({String latestKind = 'direct_feedback'}) async {
    final sql = await db.database;
    await sql.insert('personality_learning_candidates', {
      'id': 'mixed', 'scope': 'relationship_permission', 'subject_key': 'relationship.communication',
      'proposition': '用户希望聊天时少解释直接说重点', 'context_key': 'ordinary',
      'status': 'forming', 'confidence': 0.55, 'support_count': 2, 'contradiction_count': 2,
      'support_score': 1.8, 'contradiction_score': 1.5,
      'first_observed_at': at.millisecondsSinceEpoch, 'last_observed_at': at.millisecondsSinceEpoch,
      'created_at': at.millisecondsSinceEpoch, 'updated_at': at.millisecondsSinceEpoch,
    });
    for (var i = 0; i < 4; i++) {
      await sql.insert('personality_learning_evidence', {
        'id': 'e$i', 'candidate_id': 'mixed', 'source_message_id': 'm$i',
        'evidence_kind': i == 3 ? latestKind : 'direct_feedback',
        'polarity': i.isEven ? 'support' : 'contradict',
        'evidence_text': i.isEven ? '聊天时少解释' : '聊天时说得太少',
        'confidence': 0.8, 'weight': 0.72, 'observed_at': at.millisecondsSinceEpoch + i,
      });
    }
  }

  test('rare relevant clarification changes no memory and silence never causes a repeat', () async {
    await mixedLearning();
    final policy = LowFrequencyClarification(db);
    expect(await policy.offer(query: '今天晚饭吃什么', now: at), isEmpty);
    expect(await db.getSetting(LowFrequencyClarification.stateKey), isNull);
    final offered = await policy.offer(query: '聊天时少解释', now: at);
    expect(offered, contains('可选的低频澄清'));
    expect(offered, contains('已有反向证据'));
    expect(await policy.offer(query: '聊天时少解释', now: at.add(const Duration(days: 1))), isEmpty);
    expect(await policy.offer(query: '聊天时少解释', now: at.add(const Duration(days: 90))), isEmpty);
    final candidate = (await db.personalityLearningCandidatesForExtraction(contextKey: 'ordinary')).single;
    expect(candidate.supportCount, 2);
    expect(candidate.contradictionCount, 2);
    expect(await db.listMemories(), isEmpty);
    final state = jsonDecode((await db.getSetting(LowFrequencyClarification.stateKey))!) as Map;
    expect(state['state'], 'offered_unconfirmed');
  });

  for (final kind in ['explicit_correction', 'boundary', 'explicit_preference']) {
    test('a current explicit $kind is respected without requesting reconfirmation', () async {
      await mixedLearning(latestKind: kind);
      expect(await LowFrequencyClarification(db).offer(query: '聊天时少解释', now: at), isEmpty);
    });
  }

  test('standby and disabled learning cannot offer or persist a clarification', () async {
    await mixedLearning();
    await db.setSetting('active_brain', '0');
    expect(await LowFrequencyClarification(db).offer(query: '聊天时少解释', now: at), isEmpty);
    await db.setSetting('active_brain', '1');
    await db.setSetting('personality_learning_enabled', '0');
    expect(await LowFrequencyClarification(db).offer(query: '聊天时少解释', now: at), isEmpty);
    expect(await db.getSetting(LowFrequencyClarification.stateKey), isNull);
  });
}
