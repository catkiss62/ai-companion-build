import 'dart:convert';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/integration/moe_shadow_coordinator.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async { db = await AppDatabase.createForTesting(databaseFactoryFfi); });
  tearDown(() async { await db.closeForTesting(); });
  final oldTime = DateTime(2020, 1, 1);

  Future<Map<String, dynamic>> scanState() async =>
    Map<String, dynamic>.from(jsonDecode((await db.getSetting(MoeShadowCoordinator.scanKey))!) as Map);

  Future<void> restoreWithoutCounter() async {
    final archive = jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;
    final tables = archive['tables'] as Map<String, dynamic>;
    (tables['settings'] as List).removeWhere((row) =>
      (row as Map)['key'] == ConversationSourceStore.sequenceKey);
    await db.importAll(archive);
  }

  Future<ConversationSourceStamp> insertOrdinary(String id) async {
    await db.insertMessage(ChatMessage(id: id, role: 'assistant', content: '真实主动回复 $id',
      isProactive: true, createdAt: oldTime, emotionKey: 'playful'));
    return (await ConversationSourceStore.captureMessage(await db.database, id))!;
  }

  test('imported Moe scan high-water survives deletion of the highest source and a missing counter', () async {
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    await insertOrdinary('old-accepted');
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    final before = await scanState();
    final consumed = before['after_seq'] as int;
    expect(consumed, greaterThan(0));
    expect((await (await db.database).query('moe_events')).single['idempotency_key'],
      'turn:old-accepted');

    // Model a state package whose old source was pruned, without inventing
    // a new cursor. The saved cursor and accepted event are both real.
    await (await db.database).delete('messages');
    await restoreWithoutCounter();
    expect(await scanState(), before);
    final inserted = await insertOrdinary('after-import');
    expect(inserted.ingestSeq, greaterThan(consumed));
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    expect((await (await db.database).query('moe_events'))
      .map((row) => row['idempotency_key']).toSet(),
      {'turn:old-accepted', 'turn:after-import'});
  });

  test('unfinished legacy migration ceiling also bounds new source numbers after import', () async {
    final sql = await db.database;
    await sql.transaction((txn) async {
      for (var i = 0; i <= MoeShadowCoordinator.pageSize; i++) {
        await ConversationSourceStore.insertMessage(txn, ChatMessage(id: 'old-system-$i',
          role: 'system', content: '旧排除材料', isProactive: true, createdAt: oldTime).toDb());
      }
    });
    await db.setSetting('moe_shadow_reconciled_at', '${DateTime(2021, 1, 1).millisecondsSinceEpoch}');
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    final before = await scanState();
    final ceiling = before['legacy_ceiling'] as int;
    expect(before['after_seq'], lessThan(ceiling), reason: 'the real bounded migration still has an old row');

    await sql.delete('messages');
    await restoreWithoutCounter();
    expect(await scanState(), before);
    final inserted = await insertOrdinary('new-backdated');
    expect(inserted.ingestSeq, greaterThan(ceiling),
      reason: 'exceeding only after_seq would misclassify a new backdated source as historical coverage');
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    expect((await (await db.database).query('moe_events')).single['idempotency_key'],
      'turn:new-backdated');
  });
}
