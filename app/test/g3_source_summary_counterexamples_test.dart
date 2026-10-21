import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/creative/creative_store.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/database/conversation_summary_store.dart';
import 'package:ai_companion_localfirst/core/memory/memory_grounding_policy.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/memory_item.dart';
import 'package:ai_companion_localfirst/core/models/world_book_turn_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Independent state-machine counterexamples. These use the real database and
/// public writers; later summary cases exercise accepted source batches rather
/// than deriving expected answers from the implementation's ledger JSON.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  Directory? persistedFiles;
  setUp(() async { db = await AppDatabase.createForTesting(databaseFactoryFfi); });
  tearDown(() async {
    await db.closeForTesting();
    if (persistedFiles != null) {
      await persistedFiles!.delete(recursive: true);
      persistedFiles = null;
    }
  });

  String roleplay() => const WorldBookTurnContext(roleplaySessionId: 'fiction').encode();
  ChatMessage message(String id, int at, {String role = 'user',
    String text = '普通来源', String context = '', bool proactive = false}) =>
      ChatMessage(id: id, role: role, content: text,
        createdAt: DateTime.fromMillisecondsSinceEpoch(at),
        worldBookContextJson: context, isProactive: proactive);
  Future<ConversationSourceStamp> stamp(String id) async =>
    (await ConversationSourceStore.captureMessage(await db.database, id))!;
  Future<QualifiedConversationSource> qualified(String id) async =>
    (await ConversationSourceStore.qualifyMessage(await db.database, id))!;
  Future<bool> remember(String source, {DateTime? observedAt}) => db.insertMemory(
    kind: 'user_profile', content: '用户的书桌是橡木做的', importance: .8,
    confidence: .95, source: source, subjectKey: 'user.desk.material',
    temporalScope: 'stable', sourceObservedAt: observedAt);
  Future<MemoryItem> onlyMemory() async => MemoryItem.fromDb(
    (await (await db.database).query('memory_items')).single);
  Future<void> ordinaryBatch(String prefix, int count, {int at = 1000}) async {
    for (var i = 0; i < count; i++) {
      await db.insertMessage(message('$prefix-$i', at + i,
        text: '$prefix 第 $i 条真实普通材料'));
    }
  }
  Future<ConversationSummaryWork?> prepareSummary({int scanLimit = 256,
      int minimumMessages = 14}) async => db.prepareConversationSummary(
    workFence: (await db.captureBrainWorkFence(settingKeys: const [
      'conversation_context_reset_at', 'conversation_context_reset_count']))!,
    scanLimit: scanLimit, minimumMessages: minimumMessages);
  Future<Map<String, dynamic>> archive() async =>
    jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;

  test('bounded scans pass a permanent ambiguous prefix and accumulate a full ordinary batch', () async {
    for (var i = 0; i < 18; i++) {
      await db.insertMessage(message('ambiguous-$i', 1000));
    }
    await db.insertMessage(message('fiction-answer', 1000,
      role: 'assistant', context: roleplay()));
    await ordinaryBatch('ordinary', 14, at: 2000);
    ConversationSummaryWork? work;
    for (var pass = 0; pass < 80 && work == null; pass++) {
      work = await prepareSummary(scanLimit: 2);
    }
    expect(work, isNotNull,
      reason: 'scan budget is independent of the persisted 14-message model batch');
    expect(work!.materials.map((m) => m.message.id).toSet(),
      {for (var i = 0; i < 14; i++) 'ordinary-$i'});
    expect(await db.commitConversationSummaryIfCurrent(work: work,
      summary: '十四条普通材料的摘要'), isTrue);
    final sql = await db.database;
    expect(await sql.query(ConversationSummaryStore.table), hasLength(33));
    expect(await sql.query(ConversationSummaryStore.table,
      where: "state = 'covered'"), hasLength(14));
    expect(await prepareSummary(), isNull);
    expect(await sql.query('conversation_summaries'), hasLength(1));
  });

  test('thirteen pending materials survive process reopen and join the next source', () async {
    await db.closeForTesting();
    persistedFiles = await Directory.systemTemp.createTemp('g3-summary-reopen-');
    final path = '${persistedFiles!.path}/summary.sqlite';
    db = await AppDatabase.createForTesting(databaseFactoryFfi, path: path);
    await ordinaryBatch('pending', 13);
    expect(await prepareSummary(), isNull);
    await db.closeForTesting();
    db = await AppDatabase.createForTesting(databaseFactoryFfi,
      path: path, reopenExisting: true);
    await db.insertMessage(message('fourteenth', 2000));
    final work = (await prepareSummary())!;
    expect(work.materials.map((m) => m.message.id).toSet(),
      {for (var i = 0; i < 13; i++) 'pending-$i', 'fourteenth'});
    expect(await db.commitConversationSummaryIfCurrent(work: work,
      summary: '跨重启累计的材料'), isTrue);
    expect(await prepareSummary(), isNull);
  });

  test('a real old range index migrates without erasing history or rejecting late batches in the same event range', () async {
    await db.closeForTesting();
    persistedFiles = await Directory.systemTemp.createTemp('g3-summary-old-schema-');
    final path = '${persistedFiles!.path}/summary.sqlite';
    db = await AppDatabase.createForTesting(databaseFactoryFfi, path: path);
    final sql = await db.database;
    expect(await db.insertConversationSummary(fromAt: DateTime.fromMillisecondsSinceEpoch(100),
      toAt: DateTime.fromMillisecondsSinceEpoch(200), summary: '原档案历史摘要'), isTrue);
    await sql.execute('DROP INDEX idx_summary_source_batch');
    await sql.execute('DROP INDEX idx_summary_range');
    await sql.execute('ALTER TABLE conversation_summaries DROP COLUMN source_batch_hash');
    await sql.execute('ALTER TABLE conversation_summaries DROP COLUMN source_manifest_json');
    await sql.execute('DROP TABLE ${ConversationSummaryStore.table}');
    await sql.execute('CREATE UNIQUE INDEX idx_summary_range_unique ON conversation_summaries(from_at,to_at)');
    await db.closeForTesting();
    db = await AppDatabase.createForTesting(databaseFactoryFfi,
      path: path, reopenExisting: true);
    for (final batch in ['first', 'late']) {
      await ordinaryBatch(batch, 14);
      final work = (await prepareSummary())!;
      expect(work.materials.map((m) => m.message.id).toSet(),
        {for (var i = 0; i < 14; i++) '$batch-$i'});
      expect(await db.commitConversationSummaryIfCurrent(work: work,
        summary: '$batch 独立来源批次'), isTrue);
    }
    final rows = await (await db.database).query('conversation_summaries');
    expect(rows, hasLength(3));
    final old = rows.singleWhere((row) => row['summary'] == '原档案历史摘要');
    expect(old['source_batch_hash'], '');
    expect(old['source_manifest_json'], '');
    final sameRange = rows.where((row) => row['from_at'] == 1000 && row['to_at'] == 1013).toList();
    expect(sameRange, hasLength(2));
    expect(sameRange.map((row) => row['source_batch_hash']).toSet(), hasLength(2));
    // Reopen the already-migrated same-range data too: startup must not rebuild
    // the retired unique index or collapse the two accepted batches.
    await db.closeForTesting();
    db = await AppDatabase.createForTesting(databaseFactoryFfi,
      path: path, reopenExisting: true);
    expect(await (await db.database).query('conversation_summaries'), hasLength(3));
  });

  test('an imported missing legacy baseline cannot infer a prefix from backdated event time', () async {
    await db.insertMessage(message('uncovered-later-event', 10000));
    await db.insertMessage(message('backdated-later-ingestion', 1000));
    expect(await db.insertConversationSummary(fromAt: DateTime.fromMillisecondsSinceEpoch(500),
      toAt: DateTime.fromMillisecondsSinceEpoch(2000), summary: '没有来源清单的旧摘要'), isTrue);
    final snapshot = await archive();
    ((snapshot['tables'] as Map)['settings'] as List).removeWhere((row) =>
      (row as Map)['key'] == ConversationSourceStore.legacySummaryCoveredKey ||
      row['key'] == ConversationSummaryStore.stateKey);
    await db.importAll(snapshot);
    expect(await db.getSetting(ConversationSourceStore.legacySummaryCoveredKey), '0');
    expect(await db.getSetting('conversation_summary_legacy_baseline_unknown_v1'), '1');
    final work = (await prepareSummary(minimumMessages: 1))!;
    expect(work.materials.map((m) => m.message.id).toSet(),
      {'uncovered-later-event', 'backdated-later-ingestion'});
    expect(work.materials.map((m) => m.message.createdAt.millisecondsSinceEpoch), [1000, 10000]);
  });

  test('full restore keeps covered material consumed and pending material available beside deferred sources', () async {
    await ordinaryBatch('covered', 14);
    final accepted = (await prepareSummary())!;
    expect(await db.commitConversationSummaryIfCurrent(work: accepted, summary: '已经接受'), isTrue);
    await db.insertMessage(message('ambiguous-user', 500));
    await db.insertMessage(message('ambiguous-answer', 500, role: 'assistant'));
    await ordinaryBatch('pending', 13, at: 3000);
    expect(await prepareSummary(), isNull);
    final before = await (await db.database).query(ConversationSummaryStore.table,
      orderBy: 'message_id');
    await db.importAll(await archive());
    expect(await (await db.database).query(ConversationSummaryStore.table,
      orderBy: 'message_id'), before);
    await db.insertMessage(message('new-fourteenth', 4000));
    final work = (await prepareSummary())!;
    expect(work.materials.map((m) => m.message.id).toSet(),
      {for (var i = 0; i < 13; i++) 'pending-$i', 'new-fourteenth'});
    expect(await db.commitConversationSummaryIfCurrent(work: work, summary: '恢复后的待决材料'), isTrue);
    expect(await (await db.database).query('conversation_summaries'), hasLength(2));
  });

  test('restoring a missing sequence counter above a deleted consumed source cannot hide the next insertion', () async {
    await ordinaryBatch('original', 14);
    final covered = (await prepareSummary())!;
    expect(await db.commitConversationSummaryIfCurrent(work: covered, summary: '已消费前缀'), isTrue);
    final highest = covered.materials.reduce((a, b) =>
      a.source.stamp.ingestSeq > b.source.stamp.ingestSeq ? a : b);
    final highWater = highest.source.stamp.ingestSeq;
    final snapshot = await archive();
    final tables = snapshot['tables'] as Map;
    (tables['messages'] as List).removeWhere((row) => (row as Map)['id'] == highest.message.id);
    // A synthetic deletion must keep the declared directory consistent too.
    (tables['conversation_history_catalog'] as List).removeWhere((row) =>
      (row as Map)['message_id'] == highest.message.id);
    (tables['settings'] as List).removeWhere((row) =>
      (row as Map)['key'] == ConversationSourceStore.sequenceKey);
    await db.importAll(snapshot);
    await db.insertMessage(message('new-after-restoration', 1));
    expect((await stamp('new-after-restoration')).ingestSeq, greaterThan(highWater));
    final work = (await prepareSummary(minimumMessages: 1))!;
    expect(work.materials.map((m) => m.message.id), ['new-after-restoration']);
  });

  test('summary source mutation and competing preparations cannot consume an unaccepted batch', () async {
    await ordinaryBatch('original', 14);
    final original = (await prepareSummary())!;
    await db.insertMessage(message('original-0', 1000, text: '修订后的真实原话'));
    expect(await db.commitConversationSummaryIfCurrent(work: original, summary: '过期推断'), isFalse);
    expect(await (await db.database).query('conversation_summaries'), isEmpty);
    expect(await (await db.database).query(ConversationSummaryStore.table,
      where: "state = 'covered'"), isEmpty);
    final earlier = (await prepareSummary())!;
    final current = (await prepareSummary())!;
    expect(earlier.batchHash, current.batchHash);
    expect(earlier.batchHash, isNot(original.batchHash));
    expect(await db.commitConversationSummaryIfCurrent(work: earlier, summary: '旧准备窗口'), isFalse);
    expect(await db.commitConversationSummaryIfCurrent(work: current, summary: '当前材料摘要'), isTrue);
    expect(await db.commitConversationSummaryIfCurrent(work: current, summary: '迟到重放'), isFalse);
    expect(await (await db.database).query('conversation_summaries'), hasLength(1));
  });

  test('a context reset invalidates prepared summary work without consuming its pending sources', () async {
    await ordinaryBatch('original', 14);
    final original = (await prepareSummary())!;
    expect((await db.beginFreshConversationContext()).applied, isTrue);
    expect(await db.commitConversationSummaryIfCurrent(work: original, summary: '旧上下文迟到摘要'), isFalse);
    expect(await (await db.database).query('conversation_summaries'), isEmpty);
    expect(await (await db.database).query(ConversationSummaryStore.table,
      where: "state = 'covered'"), isEmpty);
  });

  test('a pre-reset creative share selection cannot consume cooldown with a fresh capability', () async {
    final store = CreativeStore(db);
    await store.setAutonomyEnabled(true);
    final now = DateTime.now();
    final work = {...store.autonomousWork({'id': 'private-idea', 'brief': '小灯',
      'motive': '记录颜色', 'evidence': <Object?>[]}, now,
      model: 'deepseek-flash', effort: 'high'), 'status': 'ready',
      'current': 'stored-version', 'share_after': 0};
    expect(await store.write({}, work), isTrue);
    final id = work['id'] as String;
    final original = (await db.captureBrainWorkFence(settingKeys: const [
      'conversation_context_reset_at', 'conversation_context_reset_count']))!;

    expect((await db.beginFreshConversationContext()).applied, isTrue);
    expect(await store.claimShare(id, now, workFence: original), isNull);
    expect(await store.get(id), work,
      reason: 'rejected old selection must not spend the private work share attempt');

    final fresh = (await db.captureBrainWorkFence(settingKeys: const [
      'conversation_context_reset_at', 'conversation_context_reset_count']))!;
    final accepted = await store.claimShare(id, now, workFence: fresh);
    expect(accepted, isNotNull);
    expect((await store.get(id))['share_after'],
      now.add(const Duration(hours: 2)).millisecondsSinceEpoch);
    expect((await store.get(id))['visibility'], 'private');
    expect(await store.claimShare(id, now, workFence: fresh), isNull);
  });

  test('completing a pair preserves the original user command but retires its background version', () async {
    final turn = await db.createGenerationTurn(user: message('u', 1000,
      text: '请把灯改蓝'), assistantMessageId: 'a',
      model: 'deepseek-flash', reasoningEffort: 'high');
    final job = (await db.claimGenerationJob(turn.id))!;
    final original = await stamp('u');
    final unresolved = await qualified('u');
    expect(await original.matchesCapturedVersion(await db.database), isTrue);
    expect(unresolved.eligibility, ConversationSourceEligibility.unresolved);

    expect(await db.completeGenerationJobIfCurrent(jobId: job.id, runToken: job.runToken,
      assistant: message('a', 2000, role: 'assistant')), isTrue);

    final current = await qualified('u');
    expect(current.isOrdinary, isTrue);
    expect(current.stamp.ingestSeq, greaterThan(original.ingestSeq));
    expect(await original.matches(await db.database), isTrue,
      reason: 'pair-only bookkeeping cannot withdraw the unchanged user instruction');
    expect(await original.matchesCapturedVersion(await db.database), isFalse);
    expect(await unresolved.matches(await db.database), isFalse);
    expect(await current.matches(await db.database), isTrue);
  });

  test('same ID and identical text reinserted later cannot validate an old captured background version', () async {
    final source = message('same-id', 1000, text: '不能把删除重插当成同一次采集');
    await db.insertMessage(source);
    final old = await qualified(source.id);
    final sql = await db.database;
    // Deliberate low-level removal models an imported/legacy replacement of
    // the same identity; the new insertion still goes through the real writer.
    await sql.delete('messages', where: 'id = ?', whereArgs: [source.id]);
    await db.insertMessage(source);
    final current = await stamp(source.id);
    expect(current.ingestSeq, greaterThan(old.stamp.ingestSeq));
    expect(current.contentHash, old.stamp.contentHash);
    expect(await old.stamp.matches(sql), isFalse);
    expect(await old.stamp.matchesCapturedVersion(sql), isFalse);
    expect(await old.matches(sql), isFalse);
  });

  test('the committed-source callback exposes the exact durable reply only after acceptance', () async {
    final turn = await db.createGenerationTurn(user: message('u', 1000),
      assistantMessageId: 'a', model: 'deepseek-flash', reasoningEffort: 'high');
    final job = (await db.claimGenerationJob(turn.id))!;
    final attempt = (await db.captureGenerationAttemptFence(job))!;
    final published = <ConversationSourceStamp>[];
    expect(await db.completeGenerationJobIfCurrent(jobId: job.id, runToken: job.runToken,
      generationAttempt: attempt, assistant: message('a', 2000, role: 'assistant',
        text: '真实提交的回复'), onCommittedSource: published.add), isTrue);
    expect(published, hasLength(1));
    final actual = await stamp('a');
    expect(published.single.toJson(), actual.toJson());
    expect(await published.single.matchesCapturedVersion(await db.database), isTrue);
    expect((await qualified('u')).isOrdinary, isTrue);
    // An already-completed replay is not a new committed reply notification.
    expect(await db.completeGenerationJobIfCurrent(jobId: job.id, runToken: job.runToken,
      generationAttempt: attempt, assistant: message('a', 2000, role: 'assistant'),
      onCommittedSource: published.add), isTrue);
    expect(published, hasLength(1));
  });

  test('a late SQL failure rolls back the reply and never publishes a committed source', () async {
    final turn = await db.createGenerationTurn(user: message('u', 1000),
      assistantMessageId: 'a', model: 'deepseek-flash', reasoningEffort: 'high');
    final job = (await db.claimGenerationJob(turn.id))!;
    final attempt = (await db.captureGenerationAttemptFence(job))!;
    final before = await stamp('u');
    final published = <ConversationSourceStamp>[];
    final sql = await db.database;
    await sql.execute("CREATE TRIGGER fail_generation_completion BEFORE UPDATE ON generation_jobs "
      "WHEN NEW.status = 'completed' BEGIN SELECT RAISE(ABORT, 'fixture_completion_failure'); END");
    try {
      await expectLater(db.completeGenerationJobIfCurrent(jobId: job.id, runToken: job.runToken,
        generationAttempt: attempt, assistant: message('a', 2000, role: 'assistant'),
        onCommittedSource: published.add), throwsA(isA<DatabaseException>()));
      expect(published, isEmpty);
      expect(await db.messageById('a'), isNull);
      expect(await before.matchesCapturedVersion(sql), isTrue);
      expect((await sql.query('generation_jobs', where: 'id = ?', whereArgs: [job.id]))
        .single['status'], 'running');
    } finally {
      await sql.execute('DROP TRIGGER fail_generation_completion');
    }
  });

  test('legacy missing sequence stays unknown and malformed sequence cannot become a positive capability', () async {
    await db.insertMessage(message('u', 1000));
    final original = await stamp('u');
    final raw = jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
    final legacy = Map<String, dynamic>.from(raw)..remove('ingest_seq');
    final unknown = ConversationSourceStamp.fromJson(legacy)!;
    expect(unknown.ingestSeq, 0);
    expect(await unknown.matches(await db.database), isTrue);
    expect(await unknown.matchesCapturedVersion(await db.database), isFalse);
    for (final malformed in [original.ingestSeq + .5, '${original.ingestSeq}', -1]) {
      expect(ConversationSourceStamp.fromJson({...raw, 'ingest_seq': malformed}), isNull,
        reason: 'do not truncate or fresh-capture a malformed stored version');
    }
    final paired = (await qualified('u')).toJson();
    for (final field in ['user_id', 'assistant_id']) {
      expect(QualifiedConversationSource.fromJson({...paired, field: 123}), isNull,
        reason: 'invalid checkpoint pair IDs are rejected instead of throwing or borrowing current IDs');
    }
  });

  for (final reversedIds in [false, true]) {
    test('legacy RP same-millisecond user is unresolved with ${reversedIds ? 'reverse' : 'forward'} UUID order', () async {
      final userId = reversedIds ? 'z-user' : 'a-user';
      final answerId = reversedIds ? 'a-answer' : 'z-answer';
      await db.insertMessage(message(userId, 1000, text: '虚构王国的用户原话'));
      await db.insertMessage(message(answerId, 1000, role: 'assistant', context: roleplay()));
      // A later ordinary answer must not hide ambiguity in the same-time bucket.
      await db.insertMessage(message('later-answer', 2000, role: 'assistant'));
      expect((await qualified(userId)).eligibility, ConversationSourceEligibility.unresolved);
      expect((await qualified(answerId)).eligibility, ConversationSourceEligibility.roleplay);
    });
  }

  test('multiple ambiguous same-time users remain excluded while proactive material is independent', () async {
    for (final id in ['a-user', 'z-user']) {
      await db.insertMessage(message(id, 1000));
    }
    await db.insertMessage(message('m-fiction', 1000, role: 'assistant', context: roleplay()));
    await db.insertMessage(message('p-ordinary', 1000, role: 'assistant', proactive: true));
    for (final id in ['a-user', 'z-user']) {
      expect((await qualified(id)).eligibility, ConversationSourceEligibility.unresolved);
    }
    expect((await qualified('p-ordinary')).isOrdinary, isTrue);
  });

  test('a proactive RP reply alone is not a same-time partner of a legacy ordinary user', () async {
    await db.insertMessage(message('z-user', 1000));
    await db.insertMessage(message('a-proactive', 1000, role: 'assistant',
      proactive: true, context: roleplay()));
    expect((await qualified('z-user')).isOrdinary, isTrue);
    expect((await qualified('a-proactive')).eligibility, ConversationSourceEligibility.roleplay);
  });

  test('a durable exact pair wins over ambiguous legacy messages in the same time bucket', () async {
    final turn = await db.createGenerationTurn(user: message('z-user', 1000),
      assistantMessageId: 'a-answer', model: 'deepseek-flash', reasoningEffort: 'high');
    final job = (await db.claimGenerationJob(turn.id))!;
    await db.insertMessage(message('m-legacy', 1000, role: 'assistant', context: roleplay()));
    expect(await db.completeGenerationJobIfCurrent(jobId: job.id, runToken: job.runToken,
      assistant: message('a-answer', 1000, role: 'assistant')), isTrue);
    final user = await qualified('z-user');
    expect(user.isOrdinary, isTrue);
    expect(user.assistantMessageId, 'a-answer');
  });

  test('a material object retains its old prompt and cannot borrow a later source capability', () async {
    await db.insertMessage(message('u', 1000, text: '${List.filled(2100, '前').join()}原决定'));
    final sql = await db.database;
    final material = (await sql.transaction((txn) =>
      ConversationSourceStore.captureMaterial(txn, 'u')))!;
    expect(material.message.promptContent, endsWith('原决定'));
    await db.insertMessage(message('u', 1000, text: '${List.filled(2100, '前').join()}新决定'));
    expect(material.message.promptContent, endsWith('原决定'));
    expect(await material.source.matches(sql), isFalse);
    final current = (await sql.transaction((txn) =>
      ConversationSourceStore.captureMaterial(txn, 'u')))!;
    expect(current.message.promptContent, endsWith('新决定'));
    expect(await current.source.matches(sql), isTrue);
  });

  test('replacing an RP legacy answer requeues the previously excluded user without changing its command', () async {
    await db.insertMessage(message('u', 1000));
    await db.insertMessage(message('a', 2000, role: 'assistant', context: roleplay()));
    final original = await qualified('u');
    expect(original.eligibility, ConversationSourceEligibility.roleplay);
    final cursor = (await ConversationSourceStore.scanAfter(await db.database, afterSeq: 0)).lastScannedSeq;

    await db.insertMessage(message('a', 2000, role: 'assistant', text: '新的普通回复'));

    expect((await qualified('u')).isOrdinary, isTrue);
    expect(await original.stamp.matches(await db.database), isTrue);
    expect(await original.stamp.matchesCapturedVersion(await db.database), isFalse);
    final next = await ConversationSourceStore.scanAfter(await db.database, afterSeq: cursor);
    expect(next.sources.map((s) => s.stamp.id), contains('u'));
    expect(next.sources.singleWhere((s) => s.stamp.id == 'u').isOrdinary, isTrue);
  });

  test('inserting a new legacy user between an excluded user and its RP answer wakes the older user', () async {
    await db.insertMessage(message('u-old', 1000));
    await db.insertMessage(message('a-rp', 3000, role: 'assistant', context: roleplay()));
    expect((await qualified('u-old')).eligibility, ConversationSourceEligibility.roleplay);
    final cursor = (await ConversationSourceStore.scanAfter(await db.database, afterSeq: 0)).lastScannedSeq;

    await db.insertMessage(message('u-middle', 2000));

    expect((await qualified('u-old')).isOrdinary, isTrue);
    expect((await qualified('u-middle')).eligibility, ConversationSourceEligibility.roleplay);
    final next = await ConversationSourceStore.scanAfter(await db.database, afterSeq: cursor);
    expect(next.sources.map((s) => s.stamp.id), contains('u-old'));
  });

  test('a first provable source replaces legacy processing dates without rewriting the processing clock', () async {
    final processingStart = DateTime.now().millisecondsSinceEpoch;
    expect(await remember('legacy-source'), isTrue);
    final legacy = await onlyMemory();
    expect(legacy.evidenceTimeKnown, isFalse);
    expect(MemoryGroundingPolicy.formatForPrompt(legacy), contains('source_time_unknown'));
    expect(MemoryGroundingPolicy.recalledThoughtText(legacy), contains('来源事件时间未知'));
    final yesterday = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch);

    expect(await remember('trusted-yesterday', observedAt: yesterday), isTrue);

    final known = await onlyMemory();
    expect(known.evidenceTimeKnown, isTrue);
    expect(known.firstObservedAt, yesterday);
    expect(known.lastEvidenceAt, yesterday);
    expect(known.createdAt, legacy.createdAt);
    expect(known.updatedAt.millisecondsSinceEpoch, greaterThanOrEqualTo(processingStart));
    expect(known.retentionCheckedAt!.millisecondsSinceEpoch, greaterThanOrEqualTo(processingStart));
    expect(MemoryGroundingPolicy.formatForPrompt(known), isNot(contains('source_time_unknown')));
    final evidence = await db.memoryEvidenceFor(known.id);
    final oldEvidence = evidence.singleWhere((row) => row['source'] == 'legacy-source');
    final newEvidence = evidence.singleWhere((row) => row['source'] == 'trusted-yesterday');
    expect(oldEvidence['source_observed_at'], isNull);
    expect(newEvidence['source_observed_at'], yesterday.millisecondsSinceEpoch);
    expect(newEvidence['observed_at'], greaterThanOrEqualTo(processingStart));
  });

  test('out-of-order known evidence takes min and max while unknown evidence cannot move either boundary', () async {
    final first = DateTime.fromMillisecondsSinceEpoch(2000);
    final earlier = DateTime.fromMillisecondsSinceEpoch(1000);
    final latest = DateTime.fromMillisecondsSinceEpoch(3000);
    expect(await remember('known-middle', observedAt: first), isTrue);
    expect(await remember('known-earlier', observedAt: earlier), isTrue);
    expect((await onlyMemory()).firstObservedAt, earlier);
    expect((await onlyMemory()).lastEvidenceAt, first);
    expect(await remember('known-latest', observedAt: latest), isTrue);
    expect(await remember('unknown-processed-now'), isTrue);
    final finalMemory = await onlyMemory();
    expect(finalMemory.evidenceTimeKnown, isTrue);
    expect(finalMemory.firstObservedAt, earlier);
    expect(finalMemory.lastEvidenceAt, latest);
    expect(finalMemory.evidenceCount, 4);
    expect(finalMemory.updatedAt.isAfter(latest), isTrue);
  });

  for (final scenario in [
    (scope: 'scheduled', fact: 'unknown', tags: ['last_known_plan', 'current_status=unknown', '计划不等于已经执行']),
    (scope: 'ongoing', fact: 'ongoing', tags: ['last_known_ongoing', 'current_status=unknown']),
    (scope: 'event', fact: 'completed', tags: ['historical_completed', '不得继续当作待办']),
    (scope: 'event', fact: 'cancelled', tags: ['historical_cancelled', '不得继续追问或描述为已完成']),
  ]) {
    test('unknown source date retains the ${scenario.scope}/${scenario.fact} prompt boundary', () async {
      expect(await db.insertMemory(kind: 'user_profile', content: '一条原有生活记录',
        importance: .8, confidence: .95, source: 'legacy-unknown',
        temporalScope: scenario.scope, factState: scenario.fact), isTrue);
      final item = await onlyMemory();
      expect(item.evidenceTimeKnown, isFalse);
      final prompt = MemoryGroundingPolicy.formatForPrompt(item);
      expect(prompt, contains('source_time_unknown'));
      for (final boundary in scenario.tags) {
        expect(prompt, contains(boundary), reason: 'uncertain dates must not erase the event/plan category');
      }
    });
  }

  test('replaying identical evidence does not turn its new processing time into another event', () async {
    final first = DateTime.fromMillisecondsSinceEpoch(1000);
    expect(await remember('original-known', observedAt: first), isTrue);
    expect(await remember('one-checkpoint', observedAt: DateTime.fromMillisecondsSinceEpoch(2000)), isTrue);
    final sql = await db.database;
    final before = (await sql.query('memory_items')).single;
    final evidenceBefore = await db.memoryEvidenceFor(before['id'] as String);

    // A retry must use its stable receipt/source identity even if a caller
    // supplies a newer timestamp; an existing vote is not a new confirmation.
    expect(await remember('one-checkpoint', observedAt: DateTime.now()), isTrue);

    expect((await sql.query('memory_items')).single, before);
    expect(await db.memoryEvidenceFor(before['id'] as String), evidenceBefore);
  });

  test('a real old evidence schema migrates to unknown and a later snapshot preserves known event dates', () async {
    await db.closeForTesting();
    persistedFiles = await Directory.systemTemp.createTemp('g3-old-evidence-');
    final path = '${persistedFiles!.path}/evidence.sqlite';
    db = await AppDatabase.createForTesting(databaseFactoryFfi, path: path);
    expect(await remember('old-format'), isTrue);
    final sql = await db.database;
    final oldEvidence = (await sql.query('memory_evidence')).single;
    // Remove precisely the G3 columns, preserving the actual legacy schema,
    // old observed_at NOT NULL and its processing-time values.
    await sql.execute('ALTER TABLE memory_items DROP COLUMN evidence_time_known');
    await sql.execute('ALTER TABLE memory_evidence DROP COLUMN source_observed_at');
    await db.closeForTesting();
    db = await AppDatabase.createForTesting(databaseFactoryFfi,
      path: path, reopenExisting: true);
    final migrated = await onlyMemory();
    expect(migrated.evidenceTimeKnown, isFalse);
    final migratedEvidence = (await (await db.database).query('memory_evidence')).single;
    expect(migratedEvidence['observed_at'], oldEvidence['observed_at']);
    expect(migratedEvidence['source_observed_at'], isNull);
    expect(MemoryGroundingPolicy.formatForPrompt(migrated), contains('source_time_unknown'));
    final sourceTime = DateTime.fromMillisecondsSinceEpoch(2000);
    expect(await remember('new-provable', observedAt: sourceTime), isTrue);
    final archive = jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;
    await db.importAll(archive);
    final restored = await onlyMemory();
    expect(restored.evidenceTimeKnown, isTrue);
    expect(restored.firstObservedAt, sourceTime);
    expect(restored.lastEvidenceAt, sourceTime);
    expect((await db.memoryEvidenceFor(restored.id))
      .singleWhere((row) => row['source'] == 'new-provable')['source_observed_at'], sourceTime.millisecondsSinceEpoch);
  });
}
