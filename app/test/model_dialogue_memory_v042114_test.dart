import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_archive_worker.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_context.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_models.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_repository.dart';
import 'package:ai_companion_localfirst/core/memory/memory_revision.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_prompt.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit();
  late AppDatabase db;
  late ModelDialogueRepository repository;
  setUp(() async { db = await AppDatabase.createForTesting(databaseFactoryFfi); repository = ModelDialogueRepository(db); });
  tearDown(() async { await db.closeForTesting(); });

  Future<ModelDialogueRoom> create() => repository.create(title: '花园的两种想法', topic: '花园',
      participants: const {'deepseek': {'model': 'deepseek-test'}, 'gemini': {'model': 'gemini-test'}});
  Future<void> turn(ModelDialogueRoom room, {String user = '', String action = 'continue', String? memory}) async {
    expect(await db.tryAcquireLocalLease('chat_turn_lease', holdFor: const Duration(minutes: 3)), isTrue);
    final fence = await db.captureBrainWorkFence(leaseKey: 'chat_turn_lease');
    final ticket = await repository.begin(roomId: room.id, fence: fence!, userText: user, memoryContext: memory);
    expect(await repository.commit(ticket, ModelDialogueOutput('关于花园的看法', action), GenerationCancellationToken()), isTrue);
    await db.releaseLocalLease('chat_turn_lease');
  }
  Map<String, dynamic> result({bool remember = true}) => {'overview': '讨论花园布置',
    'deepseek_view': '留空盆', 'gemini_view': '多种花', 'common_ground': '',
    'open_questions': '尚未决定', 'user_quotes': <String>[], 'worth_remembering': remember};
  Future<List<Map<String, Object?>>> memories() async => (await db.database).query('memory_items');
  Future<ModelDialogueRoom> ended() async { final room = await create(); await turn(room); await turn(room); await repository.end(room.id); return room; }

  test('shared identity and relevant experiences are read without recall/evidence mutation', () async {
    await db.insertMemory(kind: 'ai_self', content: '我喜欢安静看花园', importance: .8);
    await db.insertMemory(kind: 'shared_experience', content: '一起在花园种过雏菊', importance: .8);
    final before = jsonEncode(await memories());
    final context = await ModelDialogueContext(db).build('花园');
    expect(context, contains('一起在花园种过雏菊')); expect(context, contains('我喜欢安静看花园'));
    expect(jsonEncode(await memories()), before);
    final room = await create(); await turn(room, memory: context);
    final saved = (await repository.roomById(room.id))!;
    final history = await repository.messagesForRoom(room.id);
    for (final speaker in modelDialogueSpeakers) {
      final prompt = jsonEncode(ModelDialoguePrompt.build(saved, history, speaker));
      expect(prompt, contains(context.split('\n').first));
      expect(prompt, contains('普通App的历史分工')); expect(prompt, contains('保留归属'));
    }
    expect(jsonEncode(await memories()), before);
  });

  test('pause does not queue; ending atomically queues once; retry cannot duplicate the experience', () async {
    final room = await create(); await turn(room, user: '我还没决定。'); await turn(room);
    expect(await db.getSetting('${ModelDialogueRepository.archivePrefix}${room.id}'), isNull);
    await repository.end(room.id);
    final job = await db.getSetting('${ModelDialogueRepository.archivePrefix}${room.id}');
    await repository.end(room.id); expect(await db.getSetting('${ModelDialogueRepository.archivePrefix}${room.id}'), job);
    var calls = 0;
    final worker = ModelDialogueArchiveWorker(db, generate: (r, m, fence) async { calls++; return result()..['user_quotes'] = ['我还没决定。']; });
    await worker.drainOne(); await worker.drainOne();
    expect(calls, 1); expect(await memories(), hasLength(1));
    final memory = (await memories()).single;
    expect(memory['source'], 'model_dialogue:${room.id}'); expect(memory['kind'], 'shared_experience');
    expect(memory['evidence_count'], 1); expect(memory['content'], contains('Gemini一侧的观点'));
    expect(memory['content'], contains('真实用户在本场的原话')); expect(memory['content'], contains('不代表永久偏好、现实事实'));
    expect(MemorySourceContext.format(memory['source_context_json'] as String), contains('模型对谈经历'));
    expect((await repository.roomById(room.id))!.archiveState, 'remembered');
    expect(await db.getSetting('${ModelDialogueRepository.archivePrefix}${room.id}'), isNull);
  });

  test('natural model ending queues; no valuable content archives without public memory', () async {
    final room = await create(); await turn(room); await turn(room, action: 'end');
    expect((await repository.roomById(room.id))!.archiveState, 'pending');
    await ModelDialogueArchiveWorker(db, generate: (r, m, f) async => result(remember: false)).drainOne();
    expect(await memories(), isEmpty); expect((await repository.roomById(room.id))!.archiveState, 'archived');
    expect((await repository.roomById(room.id))!.archiveSummary, contains('讨论花园布置'));
  });

  test('fabricated user quote fails closed and leaves a durable backoff job', () async {
    final room = await ended(); var calls = 0;
    final worker = ModelDialogueArchiveWorker(db, generate: (r, m, f) async { calls++; return result()..['user_quotes'] = ['用户根本没有说过']; });
    await worker.drainOne(); await worker.drainOne();
    expect(calls, 1); expect(await memories(), isEmpty);
    expect(await db.getSetting('${ModelDialogueRepository.archivePrefix}${room.id}'), contains('nextAttemptAt'));
    expect((await repository.roomById(room.id))!.archiveState, 'pending');
  });

  for (final change in ['delete', 'restore', 'chat']) {
    test('$change during summary rejects stale write and never recreates deleted work', () async {
      final room = await ended(); final entered = Completer<void>(); final release = Completer<void>();
      final worker = ModelDialogueArchiveWorker(db, generate: (r, m, f) async {
        entered.complete(); await release.future; return result();
      });
      final running = worker.drainOne(); await entered.future;
      if (change == 'delete') await repository.delete(room.id);
      if (change == 'restore') await db.importAll(Map<String, dynamic>.from(await db.exportAll()));
      if (change == 'chat') await db.tryAcquireLocalLease('chat_turn_lease', holdFor: const Duration(minutes: 3));
      release.complete(); await running;
      expect(await memories(), isEmpty);
      if (change == 'delete') {
        expect(await repository.roomById(room.id), isNull);
        expect(await db.getSetting('${ModelDialogueRepository.archivePrefix}${room.id}'), isNull);
      }
      if (change == 'chat') await db.releaseLocalLease('chat_turn_lease');
    });
  }

  test('a summary cannot invent a viewpoint for a participant who never spoke', () async {
    final room = await create(); await turn(room); await repository.end(room.id);
    await ModelDialogueArchiveWorker(db, generate: (r, m, f) async => result()).drainOne();
    expect(await memories(), isEmpty);
    expect((await repository.roomById(room.id))!.archiveState, 'pending');
    expect(await db.getSetting('${ModelDialogueRepository.archivePrefix}${room.id}'), isNotNull);
  });

  test('empty rooms and old ended trial rooms do not create retrospective memory jobs', () async {
    final empty = await create(); await repository.end(empty.id);
    expect((await repository.roomById(empty.id))!.archiveState, 'skipped');
    final old = await create(); final sql = await db.database;
    final data = Map<String, dynamic>.from(old.data)..remove('memory_policy');
    await db.setSetting('${ModelDialogueRepository.roomPrefix}${old.id}', jsonEncode(data));
    await repository.end(old.id);
    final jobs = await sql.query('settings', where: 'key LIKE ?', whereArgs: ['${ModelDialogueRepository.archivePrefix}%']);
    expect(jobs, isEmpty);
  });
}
