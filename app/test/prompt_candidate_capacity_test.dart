import 'dart:convert';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/memory/memory_brain.dart';
import 'package:ai_companion_localfirst/core/reference/reference_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  final now = DateTime(2026, 10, 12).millisecondsSinceEpoch;

  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    final sql = await db.database;
    await sql.delete('unfinished_threads');
    await sql.delete('reference_documents');
  });
  tearDown(() async { await db.closeForTesting(); });

  Map<String, Object?> thread(String id, {
    String title = '彗星观测',
    String status = 'active',
    double importance = .5,
    int? updatedAt,
  }) => {
    'id': id, 'title': title, 'detail': '', 'topic_key': '',
    'status': status, 'importance': importance,
    'created_at': now, 'updated_at': updatedAt ?? now,
  };

  Map<String, Object?> behavior(String id, {
    bool enabled = true,
    String scope = 'all',
    String mode = 'always',
    bool manual = false,
    int probability = 100,
    int priority = 1000,
    int? updatedAt,
    String name = '彗星话题',
    String? content,
  }) => {
    'id': id, 'name': name, 'kind': 'character',
    'raw_content': content ?? '模块正文 $id', 'aliases': '',
    'enabled': enabled ? 1 : 0, 'entry_type': 'behavior',
    'activation_mode': mode, 'manual_active': manual ? 1 : 0,
    'activation_probability': probability, 'priority': priority,
    'scope': scope, 'created_at': now, 'updated_at': updatedAt ?? now,
  };

  for (final unrelated in [12, 70]) {
    test('MemoryBrain recalls named thread beyond $unrelated unrelated threads', () async {
      final sql = await db.database;
      final batch = sql.batch();
      for (var i = 0; i < unrelated; i++) {
        batch.insert('unfinished_threads', thread('other$i',
          title: '园艺花盆$i', importance: .9));
      }
      batch.insert('unfinished_threads', thread('wanted', importance: .1));
      await batch.commit(noResult: true);
      final before = await sql.query('unfinished_threads',
        where: 'id = ?', whereArgs: ['wanted']);

      final context = await MemoryBrain(db).buildContext('彗星观测');
      expect(context.threads.map((item) => item.id), ['wanted']);
      expect(await sql.query('unfinished_threads',
        where: 'id = ?', whereArgs: ['wanted']), before);
    });
  }

  test('thread relevance, active status, order, result cap and empty caller remain intact', () async {
    final sql = await db.database;
    final batch = sql.batch();
    batch.insert('unfinished_threads', thread('resolved',
      status: 'resolved', importance: 1));
    batch.insert('unfinished_threads', thread('high_old',
      importance: .9, updatedAt: now - 1));
    batch.insert('unfinished_threads', thread('high_new', importance: .9));
    batch.insert('unfinished_threads', thread('middle', importance: .7));
    batch.insert('unfinished_threads', thread('fourth', importance: .6));
    batch.insert('unfinished_threads', thread('unrelated',
      title: '园艺花盆', importance: 1));
    await batch.commit(noResult: true);

    expect((await db.relevantActiveUnfinishedThreads('彗星观测'))
      .map((item) => item.id), ['high_new', 'high_old', 'middle']);
    expect(await db.relevantActiveUnfinishedThreads('棒球比赛'), isEmpty);
    expect(await db.relevantActiveUnfinishedThreads('？？？'), isEmpty);
    expect(await db.relevantActiveUnfinishedThreads('彗星观测', limit: 0), isEmpty);
    expect((await db.relevantActiveUnfinishedThreads(''))
      .map((item) => item.id), ['unrelated', 'high_new', 'high_old']);
    expect((await MemoryBrain(db).buildContext('')).threads, isEmpty);
  });

  test('161st behavior remains selectable behind disabled high-priority modules', () async {
    final sql = await db.database;
    final batch = sql.batch();
    for (var i = 0; i < 160; i++) {
      batch.insert('reference_documents', behavior('disabled$i', enabled: false));
    }
    batch.insert('reference_documents', behavior('wanted', priority: 100));
    await batch.commit(noResult: true);

    final bundle = await ReferenceLibrary(db).behaviorForPrompt(
      query: '彗星', turnKey: 'turn', scope: 'chat');
    expect(bundle.documents.map((item) => item.id), ['wanted']);
    expect(bundle.prompt, contains('模块正文 wanted'));
    expect(bundle.prompt, isNot(contains('模块正文 disabled')));
  });

  test('metadata pages preserve scope, activation and probability before the 10-item cap', () async {
    final sql = await db.database;
    final batch = sql.batch();
    for (var i = 0; i < 160; i++) {
      batch.insert('reference_documents', behavior('ineligible$i',
        scope: i % 4 == 0 ? 'immersive' : 'all',
        mode: i % 4 == 1 ? 'keyword' : i % 4 == 2 ? 'manual' : 'always',
        name: i % 4 == 1 ? '棒球比赛' : '彗星话题',
        probability: i % 4 == 3 ? 0 : 100));
    }
    batch.insert('reference_documents', behavior('wanted', priority: 100,
      scope: 'chat|proactive', mode: 'keyword'));
    await batch.commit(noResult: true);
    final metadata = await db.worldBookBehaviorMetadataPage();
    expect(metadata, hasLength(64));
    expect(metadata.every((item) => item.rawContent.isEmpty), isTrue);

    final bundle = await ReferenceLibrary(db).behaviorForPrompt(
      query: '彗星', turnKey: 'turn', scope: 'chat');
    expect(bundle.documents.map((item) => item.id), ['wanted']);
    expect(bundle.documents.single.rawContent, '模块正文 wanted');
    expect(bundle.prompt, isNot(contains('模块正文 ineligible')));
  });

  test('behavior ordering and probability evaluation stop at the original selected limit', () async {
    final sql = await db.database;
    final batch = sql.batch();
    batch.insert('reference_documents', behavior('scope_skip',
      scope: 'immersive', probability: 50, updatedAt: now + 3));
    batch.insert('reference_documents', behavior('probability_skip',
      probability: 50, updatedAt: now + 2));
    for (var i = 0; i < 10; i++) {
      batch.insert('reference_documents', behavior('selected$i',
        priority: 800, updatedAt: now - i));
    }
    batch.insert('reference_documents', behavior('after_limit',
      probability: 50, priority: 100));
    await batch.commit(noResult: true);
    final previous = jsonEncode({'turn': 'old', 'active': true});
    for (final id in ['scope_skip', 'probability_skip', 'after_limit']) {
      await db.setSetting('worldbook_activation_$id', previous);
    }

    final bundle = await ReferenceLibrary(db).behaviorForPrompt(
      query: '彗星', turnKey: 'new-turn', scope: 'chat');
    expect(bundle.documents.map((item) => item.id),
      List.generate(10, (i) => 'selected$i'));
    expect(await db.getSetting('worldbook_activation_scope_skip'), previous);
    expect(await db.getSetting('worldbook_activation_after_limit'), previous);
    final evaluated = jsonDecode(
      (await db.getSetting('worldbook_activation_probability_skip'))!) as Map;
    expect(evaluated['turn'], isNot('old'));
    expect(evaluated['active'], isFalse);
  });

  test('selected body budget and library master switch are unchanged', () async {
    final sql = await db.database;
    final body = '${List.filled(worldBookCategoryPromptLimit, '文').join()}超出尾部';
    await sql.insert('reference_documents', behavior('long', content: body));
    final library = ReferenceLibrary(db);
    final bundle = await library.behaviorForPrompt(
      query: '彗星', turnKey: 'turn', scope: 'chat');
    expect(bundle.documents.single.rawContent, body);
    expect(bundle.prompt, isNot(contains('超出尾部')));
    await db.setSetting('reference_library_enabled', '0');
    final disabled = await library.behaviorForPrompt(
      query: '彗星', turnKey: 'next', scope: 'chat');
    expect(disabled.documents, isEmpty);
    expect(disabled.prompt, isEmpty);
  });
}
