import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/memory_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  final recent = DateTime(2026, 10, 10).millisecondsSinceEpoch;
  final old = DateTime(2025, 1, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
  });
  tearDown(() async { await db.closeForTesting(); });

  Map<String, Object?> row(String id, {
    String content = '蓝色贝壳',
    String status = 'active',
    String semantic = 'current_fact',
    String? subject,
    double importance = .9,
    double retention = 1,
    int? updatedAt,
  }) => {
    'id': id, 'kind': 'user_profile', 'content': content,
    'importance': importance, 'confidence': .8,
    'source': 'capacity_test', 'status': status, 'semantic_type': semantic,
    'subject_key': subject ?? id, 'topic_key': '', 'tags': '',
    'retention_score': retention,
    'created_at': old, 'updated_at': updatedAt ?? recent,
  };

  Future<void> insert(Map<String, Object?> value) async {
    await (await db.database).insert('memory_items', value);
  }

  Future<List<MemoryItem>> recall(String lane, String query, {int limit = 3}) =>
      switch (lane) {
        'extraction' => db.memoryCandidatesForExtraction(query, limit: limit),
        'inference' => db.relevantMemoryInferences(query, limit: limit),
        _ => db.relevantHistoricalMemories(query, limit: limit),
      };

  for (final lane in ['extraction', 'inference', 'history']) {
    test('$lane finds old low-priority evidence beyond the previous global cap', () async {
      final status = lane == 'history' ? 'superseded' : 'active';
      final semantic = lane == 'inference' ? 'inference' : 'current_fact';
      final count = switch (lane) {
        'extraction' => 230,
        'inference' => 130,
        _ => 150,
      };
      final database = await db.database;
      final batch = database.batch();
      for (var i = 0; i < count; i++) {
        batch.insert('memory_items', row('unrelated$i',
          content: '园艺花盆编号$i', status: status, semantic: semantic));
      }
      batch.insert('memory_items', row('old_match', status: status,
        semantic: semantic, importance: .1, updatedAt: old));
      await batch.commit(noResult: true);
      final before = await database.query('memory_items',
        where: 'id = ?', whereArgs: ['old_match']);

      expect((await recall(lane, '蓝色贝壳')).map((m) => m.id), ['old_match']);
      expect(await recall(lane, '棒球比赛'), isEmpty);
      expect(await recall(lane, ''), isEmpty);
      expect(await database.query('memory_items',
        where: 'id = ?', whereArgs: ['old_match']), before);
    });
  }

  test('status, semantic type, retention and historical subject filters remain intact', () async {
    await insert(row('active_fact'));
    await insert(row('active_inference', semantic: 'inference'));
    await insert(row('faded_inference', semantic: 'inference', retention: .17));
    await insert(row('archived_fact', status: 'archived'));
    await insert(row('archived_inference', status: 'archived', semantic: 'inference'));
    await insert(row('historical_fact', status: 'superseded'));
    await insert(row('historical_empty_subject', status: 'superseded', subject: ''));
    await insert(row('historical_inference', status: 'superseded', semantic: 'inference'));

    expect((await recall('extraction', '蓝色贝壳', limit: 20)).map((m) => m.id).toSet(),
      {'active_fact', 'active_inference', 'faded_inference'});
    expect((await recall('inference', '蓝色贝壳', limit: 20)).map((m) => m.id),
      ['active_inference']);
    expect((await recall('history', '蓝色贝壳', limit: 20)).map((m) => m.id),
      ['historical_fact']);
  });

  test('caller output limits and scoring order stay separate from candidate capacity', () async {
    for (final lane in ['extraction', 'inference', 'history']) {
      final status = lane == 'history' ? 'superseded' : 'active';
      final semantic = lane == 'history' ? 'current_fact' : 'inference';
      await insert(row('${lane}_low', content: '${lane}_cue', status: status,
        semantic: semantic, importance: .1));
      await insert(row('${lane}_high', content: '${lane}_cue', status: status,
        semantic: semantic, importance: .9));
      expect((await recall(lane, '${lane}_cue', limit: 1)).map((m) => m.id),
        ['${lane}_high']);
      expect(await recall(lane, '${lane}_cue', limit: 0), isEmpty);
    }
  });

  test('literal SQL wildcard characters cannot introduce unrelated candidates', () async {
    for (final lane in ['extraction', 'inference', 'history']) {
      final status = lane == 'history' ? 'superseded' : 'active';
      final semantic = lane == 'inference' ? 'inference' : 'current_fact';
      await insert(row('${lane}_literal', content: '${lane}_device_key',
        status: status, semantic: semantic));
      await insert(row('${lane}_wildcard', content: '${lane}xdevicexkey',
        status: status, semantic: semantic));
      expect((await recall(lane, '${lane}_device_key')).map((m) => m.id),
        ['${lane}_literal']);
    }
  });
}
