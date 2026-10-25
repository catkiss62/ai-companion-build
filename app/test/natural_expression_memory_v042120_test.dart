import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/spoken_dialogue_default_migration.dart';
import 'package:ai_companion_localfirst/core/memory/background_recall_store.dart';
import 'package:ai_companion_localfirst/core/memory/memory_grounding_policy.dart';
import 'package:ai_companion_localfirst/core/memory/self_understanding_policy.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/memory_item.dart';
import 'package:ai_companion_localfirst/core/reference/world_book_spoken_dialogue_v042108.dart';
import 'package:ai_companion_localfirst/core/reference/world_book_spoken_dialogue_v042120.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_engine.dart';
import 'package:ai_companion_localfirst/core/wishes/companion_wish.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late BackgroundRecallStore store;
  late DateTime now;
  var seedSequence = 0;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    store = BackgroundRecallStore(db);
    now = DateTime.now();
    seedSequence = 0;
  });
  tearDown(() async => db.closeForTesting());

  Future<void> seed(String id, {String topic = '', bool roleplay = false}) async {
    final at = now.subtract(const Duration(days: 30)).add(Duration(minutes: seedSequence++));
    await db.insertMessage(ChatMessage(id: 'u:$id', role: 'user',
      content: '我们一起讨论了$id的新发现', createdAt: at, deviceId: 'test'));
    await db.insertMessage(ChatMessage(id: 'a:$id', role: 'assistant',
      content: '「这次$id的发现让我很意外」', createdAt: at.add(const Duration(seconds: 1)),
      deviceId: 'test'));
    await (await db.database).insert('memory_items', {
      'id': id, 'kind': 'shared_experience', 'content': '用户与AI共同讨论了$id，发现了一个不同的理解。',
      'importance': .7, 'confidence': .9, 'source': 'conversation_turn:a:$id',
      'status': 'active', 'semantic_type': 'shared_experience',
      'subject_key': 'shared.$id', 'topic_key': topic.isEmpty ? id : topic,
      'source_user_message_id': 'u:$id', 'source_assistant_message_id': 'a:$id',
      'created_at': at.millisecondsSinceEpoch, 'updated_at': at.millisecondsSinceEpoch,
      'first_observed_at': at.millisecondsSinceEpoch, 'last_evidence_at': at.millisecondsSinceEpoch,
      'evidence_time_known': 1, 'source_valid': 1, 'fact_state': 'completed',
      'attention_state': 'closed', 'retention_score': .8,
    });
    if (roleplay) await (await db.database).update('messages', {
      'worldbook_context_json': jsonEncode({'v': 1,
        'roleplay_session_id': 'room', 'sources': []}),
    }, where: 'id = ?', whereArgs: ['a:$id']);
  }
  Future<List<Map<String, dynamic>>> entries() async => BackgroundRecallStore.records(
    BackgroundRecallStore.decode(await db.getSetting(BackgroundRecallStore.stateKey) ?? '')['entries']);
  ChatMessage reply(String id) => ChatMessage(id: id, role: 'assistant',
    content: '「嗯，我也想到一点新的东西」', createdAt: DateTime.now(), deviceId: 'test', isProactive: true);

  test('passive preparation keeps messages, thoughts and memory evidence unchanged', () async {
    await seed('old-one'); await seed('old-two');
    final sql = await db.database;
    final before = await sql.query('memory_items');
    final thoughts = await sql.query('thoughts');
    await store.prepare(now: now);
    expect((await entries()).length, 2);
    expect(await sql.query('memory_items'), before);
    expect(await sql.query('thoughts'), thoughts);
    expect((await sql.query('messages')).length, 4);
    final raw = await db.getSetting(BackgroundRecallStore.stateKey) ?? '';
    expect(raw, isNot(contains('发现了一个不同的理解')));
  });

  test('stopped attempt does not consume; successful proactive commit consumes once', () async {
    await seed('old'); await store.prepare(now: now);
    final first = (await store.select(now: now))!;
    expect((await store.select(now: now))!.item.id, first.item.id);
    final message = reply('commit');
    final blocked = await db.commitProactiveMessageIfCurrent(message: message,
      evaluationStartedAt: now, backgroundRecall: first);
    expect(blocked, isNull);
    expect(await entries(), isEmpty);
    expect(await store.select(now: now), isNull);
    expect(BackgroundRecallStore.decode(await db.getSetting(BackgroundRecallStore.stateKey) ?? '')['receipts'], isNotEmpty);
  });

  test('ordinary durable commit consumes only after winning generation ownership', () async {
    await seed('ordinary'); await store.prepare(now: now);
    final selected = (await store.select(now: now))!;
    final user = ChatMessage(id: 'current-user', role: 'user', content: '嗯', createdAt: DateTime.now(), deviceId: 'test');
    final job = await db.createGenerationTurn(user: user, assistantMessageId: 'ordinary-reply',
      model: 'test-model', reasoningEffort: 'low');
    final running = (await db.claimGenerationJob(job.id))!;
    final assistant = ChatMessage(id: 'ordinary-reply', role: 'assistant', content: '「嗯」',
      createdAt: DateTime.now(), deviceId: 'test');
    expect(await db.completeGenerationJobIfCurrent(jobId: job.id, runToken: 'wrong',
      assistant: assistant, backgroundRecall: selected), false);
    expect((await entries()).length, 1);
    expect(await db.completeGenerationJobIfCurrent(jobId: job.id, runToken: running.runToken,
      assistant: assistant, backgroundRecall: selected), true);
    expect(await entries(), isEmpty);
  });

  for (final change in ['memory-edit', 'source-delete', 'source-edit', 'identity', 'reset', 'disabled']) {
    test('in-flight recalled source is rejected after $change', () async {
      await seed('old'); await store.prepare(now: now);
      final selection = (await store.select(now: now))!;
      final sql = await db.database;
      if (change == 'memory-edit') await sql.update('memory_items', {'content': '后来纠正的另一件事'}, where: 'id = ?', whereArgs: ['old']);
      if (change == 'source-delete') await sql.delete('messages', where: 'id = ?', whereArgs: ['a:old']);
      if (change == 'source-edit') await sql.update('messages', {'content': '重生成的新内容'}, where: 'id = ?', whereArgs: ['a:old']);
      if (change == 'identity') await db.setSetting('runtime_state_epoch_v1', 'changed');
      if (change == 'reset') await db.setSetting('conversation_context_reset_count', '999');
      if (change == 'disabled') await db.setSetting('ai_self_reflection_enabled', '0');
      expect(await selection.matches(sql, DateTime.now()), false);
      expect(await db.commitProactiveMessageIfCurrent(message: reply('must-not-commit'),
        evaluationStartedAt: now, backgroundRecall: selection), 'background_recall_changed');
      expect(await db.messageById('must-not-commit'), isNull);
    });
  }

  test('daily batch expires and seven day cooldown does not reinforce an event', () async {
    // The unchanged one-hour check must stay within a local calendar day.
    now = DateTime(2026, 10, 15, 12);
    await seed('old'); await store.prepare(now: now);
    final raw = await db.getSetting(BackgroundRecallStore.stateKey);
    await store.prepare(now: now.add(const Duration(hours: 1)));
    expect(await db.getSetting(BackgroundRecallStore.stateKey), raw);
    expect(await store.select(now: now.add(const Duration(hours: 25))), isNull);
    await store.prepare(now: now.add(const Duration(days: 2)));
    expect(await entries(), isEmpty);
    await store.prepare(now: now.add(const Duration(days: 8)));
    expect((await entries()).length, 1);
    expect((await db.memoryById('old'))!.recallCount, 0);
  });

  test('crossing local midnight refreshes the batch while preserving cooldown', () async {
    now = DateTime(2026, 10, 15, 23, 30);
    await seed('old'); await store.prepare(now: now);
    final before = BackgroundRecallStore.decode(await db.getSetting(BackgroundRecallStore.stateKey) ?? '');
    await store.prepare(now: now.add(const Duration(hours: 1)));
    final after = BackgroundRecallStore.decode(await db.getSetting(BackgroundRecallStore.stateKey) ?? '');
    expect(after['day'], isNot(before['day']));
    expect(await entries(), isEmpty);
    expect((await db.memoryById('old'))!.recallCount, 0);
  });

  test('same theme does not occupy both background slots', () async {
    await seed('one', topic: 'same'); await seed('two', topic: 'same');
    await seed('different', topic: 'different');
    await store.prepare(now: now);
    expect((await entries()).map((e) => e['topic']).toSet(), {'same', 'different'});
  });

  test('archived or invalid memories never enter background context', () async {
    await seed('archived'); await seed('invalid');
    final sql = await db.database;
    await sql.update('memory_items', {'status': 'archived'}, where: 'id = ?', whereArgs: ['archived']);
    await sql.update('memory_items', {'source_valid': 0}, where: 'id = ?', whereArgs: ['invalid']);
    await store.prepare(now: now);
    expect(await entries(), isEmpty);
  });

  test('roleplay evidence cannot be used as a real remembered experience', () async {
    await seed('fiction', roleplay: true);
    await store.prepare(now: now);
    expect(await entries(), isEmpty);
  });

  test('restoring a backup invalidates prepared and in-flight recall', () async {
    await seed('old'); await store.prepare(now: now);
    final selection = (await store.select(now: now))!;
    final backup = await db.exportAll();
    await db.importAll(backup);
    expect(await store.select(now: now), isNull);
    expect(await selection.matches(await db.database, DateTime.now()), false);
  });

  test('malformed optional context never prevents ordinary generation', () async {
    await db.setSetting(BackgroundRecallStore.stateKey, 'invalid JSON');
    expect(await store.select(now: now), isNull);
    await db.setSetting(BackgroundRecallStore.stateKey, jsonEncode({'expires': 'bad'}));
    expect(await store.select(now: now), isNull);
  });

  test('expression observations are contextual without weakening stable identity', () {
    MemoryItem memory(String subject) => MemoryItem(id: subject, kind: 'ai_self',
      content: '已记录的自我资料', subjectKey: subject, importance: .8, createdAt: now,
      updatedAt: now, factState: 'stable');
    final expression = memory('ai.self.communication_style');
    final identity = memory('ai.self.identity');
    expect(SelfUnderstandingPolicy.isExpressionObservation(expression), true);
    expect(MemoryGroundingPolicy.formatForPrompt(expression), contains('contextual_self_observation'));
    expect(MemoryGroundingPolicy.formatForPrompt(expression), isNot(contains('stable_fact')));
    expect(MemoryGroundingPolicy.formatForPrompt(identity), contains('stable_fact'));
    expect(MemoryGroundingPolicy.recalledThoughtText(expression), contains('可修订的旧理解'));
  });

  test('spoken migration updates an imported exact default and preserves custom edits/settings', () async {
    final sql = await db.database;
    await sql.insert('reference_documents', {'id': 'reviewed', 'name': '角色表达自然化',
      'entry_type': 'behavior', 'kind': 'character', 'raw_content': worldBookSpokenDialogueV042108,
      'enabled': 0, 'priority': 77, 'created_at': 1, 'updated_at': 1});
    await sql.insert('reference_documents', {'id': 'custom', 'name': '角色表达自然化',
      'entry_type': 'behavior', 'kind': 'character', 'raw_content': '我自己写的规则',
      'created_at': 1, 'updated_at': 1});
    await db.setSetting(spokenDialogueDefaultMarkerV042120, '0');
    await migrateSpokenDialogueDefaultV042120(sql);
    final updated = (await sql.query('reference_documents', where: 'id = ?', whereArgs: ['reviewed'])).single;
    expect(updated['raw_content'], worldBookSpokenDialogueV042120);
    expect(updated['enabled'], 0); expect(updated['priority'], 77);
    expect((await sql.query('reference_documents', where: 'id = ?', whereArgs: ['custom'])).single['raw_content'], '我自己写的规则');
    await sql.update('reference_documents', {'raw_content': '升级后修改'}, where: 'id = ?', whereArgs: ['reviewed']);
    await migrateSpokenDialogueDefaultV042120(sql);
    expect((await sql.query('reference_documents', where: 'id = ?', whereArgs: ['reviewed'])).single['raw_content'], '升级后修改');
  });

  test('approved installed heading and older example variant upgrades in place', () async {
    final sql = await db.database;
    final installed = worldBookSpokenDialogueV042108
      .replaceFirst('# 对白', '## 对白')
      .replaceFirst('那我就勉为其难', '那本鱼就勉为其难');
    await sql.insert('reference_documents', {'id': 'installed-variant',
      'name': '角色表达自然化', 'entry_type': 'behavior', 'kind': 'character',
      'raw_content': installed, 'priority': 1000, 'created_at': 1, 'updated_at': 1});
    await db.setSetting(spokenDialogueDefaultMarkerV042120, '0');
    await migrateSpokenDialogueDefaultV042120(sql);
    final row = (await sql.query('reference_documents', where: 'id = ?',
      whereArgs: ['installed-variant'])).single;
    expect(row['raw_content'], worldBookSpokenDialogueV042120);
    expect(row['id'], 'installed-variant'); expect(row['priority'], 1000);
  });

  test('new wish diagnostics distinguish missing and invalid proposal without altering saved wishes', () {
    for (final entry in <String, Object?>{'not_proposed': null, 'invalid_format': 'bad',
      'invalid_fields': {'goal': '太短', 'route': 'user'}}.entries) {
      final diagnostic = <String, Object?>{};
      expect(WishPolicy.apply(wishes: [], payload: {'new_wish': entry.value},
        evidence: const <WishEvidence>[], catalogIds: {}, now: now,
        canGenerate: true, proposalDiagnostic: diagnostic), isEmpty);
      expect(diagnostic['reason'], entry.key);
    }
  });
}
