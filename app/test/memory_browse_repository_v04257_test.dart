import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/memory/memory_browse_repository.dart';
import 'package:ai_companion_localfirst/core/models/memory_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late MemoryBrowseRepository browser;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    browser = MemoryBrowseRepository(db);
  });
  tearDown(() => db.closeForTesting());

  Future<MemoryItem> insert({
    required String id,
    String content = '存储的原始记忆',
    String kind = 'shared_experience',
    String status = 'active',
    String topic = 'shared.trip',
    String subject = '',
    int createdAt = 1000,
    int updatedAt = 2000,
    double importance = 0.5,
    Map<String, Object?> extra = const {},
  }) async {
    final database = await db.database;
    final row = <String, Object?>{
      'id': id,
      'kind': kind,
      'content': content,
      'status': status,
      'topic_key': topic,
      'subject_key': subject,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'importance': importance,
      ...extra,
    };
    await database.insert('memory_items', row);
    return MemoryItem.fromDb(
      (await database.query(
        'memory_items',
        where: 'id = ?',
        whereArgs: [id],
      )).single,
    );
  }

  Future<Map<String, List<Map<String, Object?>>>> storedState() async {
    final database = await db.database;
    final state = <String, List<Map<String, Object?>>>{};
    for (final table in [
      'memory_items',
      'memory_evidence',
      'memory_retrieval_audit',
      'thought_lifecycle_events',
      'maintenance_runs',
      'settings',
    ]) {
      state[table] = await database.query(table, orderBy: 'rowid');
    }
    return state;
  }

  test(
    'all active memories exceed 300 and remain ordered across equal-time pages',
    () async {
      final database = await db.database;
      final batch = database.batch();
      for (var index = 639; index >= 0; index--) {
        batch.insert('memory_items', {
          'id': 'm${index.toString().padLeft(4, '0')}',
          'kind': 'shared_experience',
          'content': '原文 $index',
          'created_at': 1000 + index ~/ 17,
          'updated_at': 9000 - index,
          'importance': (index % 10) / 10,
        });
      }
      await batch.commit(noResult: true);
      await insert(id: 'archived', status: 'archived');
      await insert(id: 'superseded', status: 'superseded');
      await db.setSetting(
        'remembered_user_facts_v1',
        '{"fact":"中午一点吃饭，仅记住事项中保存"}',
      );

      final active = await browser.allActive();
      expect(active, hasLength(640));
      expect(active.map((item) => item.id).toSet(), hasLength(640));
      expect(active.map((item) => item.id), [
        for (var index = 0; index < 640; index++)
          'm${index.toString().padLeft(4, '0')}',
      ]);
      expect(
        active.map((item) => item.content),
        isNot(contains('中午一点吃饭，仅记住事项中保存')),
      );
      expect(() => active.clear(), throwsUnsupportedError);
    },
  );

  test('same topic uses exact stored key across categories and omits self or inactive records', () async {
    final seed = await insert(id: 'seed');
    for (var index = 0; index < 8; index++) {
      await insert(
        id: 'related$index',
        kind: index.isEven ? 'user_profile' : 'shared_experience',
        importance: index >= 6 ? 0.9 : 0.5,
        updatedAt: index == 6 ? 3000 : 2000,
      );
    }
    await insert(id: 'same_kind_other_topic', topic: 'shared.music');
    await insert(id: 'topic_prefix', topic: 'shared.trip.next');
    await insert(id: 'archived', status: 'archived');
    await insert(id: 'superseded', status: 'superseded');

    final related = await browser.sameTopic(seed);
    expect(related.map((item) => item.id), [
      'related6',
      'related7',
      'related0',
      'related1',
      'related2',
      'related3',
    ]);
    expect(related.any((item) => item.kind != seed.kind), true);
    expect((await browser.sameTopic(seed, limit: 2)).map((item) => item.id), [
      'related6',
      'related7',
    ]);
    expect(await browser.sameTopic(seed, limit: 0), isEmpty);
  });

  test('empty topics do not derive associations; literal topic keys use SQL parameters', () async {
    final empty = await insert(
      id: 'empty',
      topic: '',
      subject: 'shared.trip.a',
    );
    final spaces = await insert(id: 'spaces', topic: '   ');
    await insert(id: 'another_empty', topic: '');
    await insert(id: 'subject_derived', topic: 'shared.trip');
    expect(await browser.sameTopic(empty), isEmpty);
    expect(await browser.sameTopic(spaces), isEmpty);

    final literal = await insert(
      id: 'literal_seed',
      topic: "shared.trip' OR 1=1--",
    );
    await insert(id: 'literal_match', topic: literal.topicKey);
    expect((await browser.sameTopic(literal)).map((item) => item.id), [
      'literal_match',
    ]);
    expect(
      (await browser.allActive())
          .firstWhere((item) => item.id == 'empty')
          .topicKey,
      isEmpty,
    );
  });

  test('browsing and manual search preserve raw text and every memory or audit state', () async {
    const raw = '  原文\n\t「曾经的旅行」😀 </script>\\n\u0000尾部  ';
    final seed = await insert(
      id: 'seed',
      content: raw,
      extra: {
        'confidence': 0.83,
        'tags': '旅行|回忆',
        'pinned': 1,
        'recall_count': 17,
        'last_recalled_at': 1234,
        'expression_count': 3,
        'last_expressed_at': 1456,
        'retention_score': 0.64,
        'retention_checked_at': 1789,
        'attention_state': 'snoozed',
        'recall_policy': 'contextual',
        'spontaneous_salience': 0.22,
        'fact_version': 4,
        'evidence_count': 2,
        'lifecycle_source': 'manual_override',
        'lifecycle_updated_at': 1999,
      },
    );
    await insert(id: 'related');
    await insert(
      id: 'without_topic',
      topic: '',
      subject: 'shared.trip.unfilled',
    );
    final database = await db.database;
    await database.insert('memory_evidence', {
      'id': 'proof',
      'memory_id': seed.id,
      'source': 'conversation_turn:test',
      'evidence_text': raw,
      'observed_at': 1000,
    });
    await database.insert('memory_retrieval_audit', {
      'id': 'prior_ai_recall',
      'created_at': 1200,
      'retrieval_mode': 'conversation',
      'query_token_count': 2,
      'candidate_count': 2,
      'direct_count': 1,
      'blocked_no_direct_count': 0,
      'blocked_cooldown_count': 1,
      'selected_count': 1,
      'pinned_selected_count': 1,
      'shared_selected_count': 1,
    });
    await db.setSetting('remembered_user_facts_v1', '{"fact":"中午一点吃饭"}');
    final before = await storedState();

    // Reject even an attempted write that would otherwise leave the same value.
    // Browsing must not invoke recall, topic backfill, or audit insertion.
    for (final table in before.keys) {
      for (final operation in ['INSERT', 'UPDATE', 'DELETE']) {
        await database.execute(
          'CREATE TEMP TRIGGER browse_guard_${table}_$operation '
          'BEFORE $operation ON $table BEGIN '
          "SELECT RAISE(ABORT, 'browsing attempted a write'); END",
        );
      }
    }

    for (var repeat = 0; repeat < 3; repeat++) {
      final items = await browser.allActive();
      final browsed = items.firstWhere((item) => item.id == seed.id);
      expect(browsed.content, raw);
      expect(browsed.recallCount, 17);
      final related = await browser.sameTopic(browsed);
      expect(related.single.id, 'related');
      expect((await browser.sameTopic(related.single)).single.content, raw);
      final manuallySearched = await db.listMemories(query: '原文');
      expect(manuallySearched.single.content, raw);
    }
    expect(await storedState(), before);
  });
}
