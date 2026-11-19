import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/core/grounding/prompt_history_policy.dart';
import '../lib/core/models/chat_message.dart';
import '../lib/core/models/memory_item.dart';
import '../lib/core/memory/turn_recall_trace.dart';

void main() {
  test('midnight and attribution survive without changing raw dialogue', () {
    final history = [
      ChatMessage(
        id: 'a',
        role: 'assistant',
        content: '你早点睡吧',
        createdAt: DateTime(2026, 11, 17, 23, 59),
      ),
      ChatMessage(
        id: 'u',
        role: 'user',
        content: '我今天准备睡了',
        createdAt: DateTime(2026, 11, 18, 0, 1),
      ),
    ];
    final evidence = PromptHistoryPolicy.formContextTranscript(history);
    expect(evidence, contains('1 助手 2026-11-17T23:59'));
    expect(evidence, contains('2 用户 2026-11-18T00:01'));
    expect(PromptHistoryPolicy.userTurnHistory(history).last, {
      'role': 'user',
      'content': '我今天准备睡了',
    });
  });

  test(
    'ranked and actually submitted are distinct, dates and excerpt bounds survive export',
    () {
      final trace = TurnRecallTrace();
      expect(trace.snapshot([], 'first')['ranked_status'], 'not_triggered');
      trace.ranked([]);
      expect(trace.snapshot([], 'third')['ranked_status'], 'no_hit');
      final item = MemoryItem(
        id: 'one',
        kind: 'event',
        content: '私人合成样本',
        importance: .8,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        sourceContextJson: '{"assistant":{"message_id":"a","created_at":123}}',
      );
      trace.ranked([item]);
      final longText = '鲸' * 1500;
      trace.section('memory', longText, TurnRecallTrace.provenance(item));
      trace.section('dated_history', '未送出的历史');
      final snapshot = trace.snapshot([
        {'role': 'system', 'content': longText},
        {'role': 'user', 'content': '未送出的历史'},
      ], 'second');
      final sections = snapshot['request_sections'] as List;
      expect(sections.first['excerpt_truncated'], isTrue);
      expect(sections.first['last_evidence_at_ms'], isNull);
      expect(sections.first['source_turn'].first['said_at_ms'], 123);
      expect(sections.last['status'], 'absent_from_final_request');
      expect(snapshot['channel'], 'second');
    },
  );

  test(
    'five committed turns, regenerated turn replacement and rollback',
    () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await db.execute(
        'CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT)',
      );
      Future<void> record(DatabaseExecutor txn, int i, int revision) =>
          TurnRecallTrace.record(
            txn,
            {'channel': 'third'},
            turn: 'u$i',
            reply: 'a$i',
            revision: revision,
            at: i,
            model: 'model',
          );
      for (var i = 0; i < 7; i++) {
        await db.transaction((txn) => record(txn, i, 1));
      }
      await db.transaction((txn) => record(txn, 6, 2));
      await expectLater(
        db.transaction((txn) async {
          await record(txn, 9, 1);
          throw StateError('cancelled');
        }),
        throwsStateError,
      );
      final rows = await TurnRecallTrace.read(db);
      expect(rows.map((r) => r['turn']), ['u6', 'u5', 'u4', 'u3', 'u2']);
      expect(rows.first['revision'], 2);
      expect(jsonEncode(rows), isNot(contains('u9')));
    },
  );
}
