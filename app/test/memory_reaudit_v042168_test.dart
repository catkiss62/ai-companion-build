import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/relationship_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    await db.insertMemory(kind: 'preference', content: '用户喜欢安静地照料花草。',
      importance: .7, confidence: .9, subjectKey: 'user.hobby.gardening');
  });
  tearDown(() async => db.closeForTesting());

  test('source revocation blocks a stale retention update even when timestamps did not change', () async {
    final item = (await db.listMemories()).single;
    await (await db.database).update('memory_items', {'source_valid': 0},
      where: 'id = ?', whereArgs: [item.id]);
    expect(await db.updateMemoryRetentionIfUnchanged(id: item.id,
      expectedCheckedAt: item.retentionCheckedAt ?? item.updatedAt, expectedUpdatedAt: item.updatedAt,
      retentionScore: .01, checkedAt: DateTime.now(), status: 'archived'), isFalse);
    final row = (await (await db.database).query('memory_items', where: 'id = ?', whereArgs: [item.id])).single;
    expect(row['status'], 'active'); expect(row['source_valid'], 0);
  });

  test('a restored snapshot rejects old maintenance ownership and keeps its restored row intact', () async {
    final item = (await db.listMemories()).single;
    final fence = (await db.captureBrainWorkFence())!;
    final saved = await db.exportAll();
    await db.importAll(saved);
    expect(await db.updateMemoryRetentionIfUnchanged(id: item.id,
      expectedCheckedAt: item.retentionCheckedAt ?? item.updatedAt, expectedUpdatedAt: item.updatedAt,
      retentionScore: .01, checkedAt: DateTime.now(), status: 'archived', workFence: fence), isFalse);
    expect((await db.listMemories()).single.status, 'active');
  });

  test('topic backfill cannot write into a newer state epoch', () async {
    await (await db.database).update('memory_items', {'topic_key': ''});
    final fence = (await db.captureBrainWorkFence())!;
    await db.setSetting('runtime_state_epoch_v1', 'a-new-runtime-for-test');
    final result = await db.backfillPhase2BTopicKeys(workFence: fence);
    expect(result.memories, 0); expect(result.candidates, 0);
    expect((await db.listMemories()).single.topicKey, '');
  });

  test('reinforced events must be read again before their emotional effect is applied', () async {
    await db.addRelationshipEvent(kind: 'trust', summary: '一起确认了彼此愿意保留的相处方式。', intensity: .3);
    final old = (await db.pendingRelationshipEvents()).single;
    await (await db.database).update('relationship_events', {'intensity': .8}, where: 'id = ?', whereArgs: [old.id]);
    Future<bool> apply(RelationshipEvent event) => db.assimilateRelationshipEventAtomic(event: event,
      pulses: {DriveKey.values.first: .01}, baselineLearning: .02,
      thoughtDrive: DriveKey.values.first, thoughtText: '对这段相处的当前理解。', thoughtStrength: .1);
    expect(await apply(old), isFalse);
    final current = (await db.pendingRelationshipEvents()).single;
    expect(await apply(current), isTrue);
    expect(await apply(current), isFalse);
  });
}
