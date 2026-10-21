import 'dart:convert';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/media_blob.dart';
import 'package:ai_companion_localfirst/core/models/message_attachment.dart';
import 'package:ai_companion_localfirst/core/models/world_book_turn_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async { db = await AppDatabase.createForTesting(databaseFactoryFfi); });
  tearDown(() => db.closeForTesting());

  ChatMessage message(String id, int at, {String role = 'user',
    String text = '真实来源', String context = '', String form = '',
    bool proactive = false}) => ChatMessage(id: id, role: role,
      content: text, createdAt: DateTime.fromMillisecondsSinceEpoch(at),
      worldBookContextJson: context, formContextJson: form, isProactive: proactive);
  Future<ConversationSourceStamp> capture(String id) async =>
      (await ConversationSourceStore.captureMessage(await db.database, id))!;
  Future<QualifiedConversationSource> qualify(String id) async =>
      (await ConversationSourceStore.qualifyMessage(await db.database, id))!;
  String roleplay() => const WorldBookTurnContext(roleplaySessionId: 'fiction').encode();

  test('running user can authorize an attempt while background qualification waits', () async {
    final created = await db.createGenerationTurn(user: message('u', 1000),
      assistantMessageId: 'a', model: 'deepseek-flash', reasoningEffort: 'high');
    final job = (await db.claimGenerationJob(created.id))!;
    final source = await capture('u');
    final pending = await qualify('u');
    expect(pending.eligibility, ConversationSourceEligibility.unresolved);
    final attempt = await db.captureGenerationAttemptFence(job);
    expect(attempt, isNotNull);
    expect(await attempt!.matches(await db.database), isTrue);
    expect(await source.matches(await db.database), isTrue);
    expect(await db.completeGenerationJobIfCurrent(jobId: job.id,
      runToken: job.runToken, assistant: message('a', 2000, role: 'assistant')), isTrue);
    expect((await qualify('u')).isOrdinary, isTrue);
    expect(await pending.matches(await db.database), isFalse);
    // Pair eligibility changed, but the actual user authorization did not.
    expect(await source.matches(await db.database), isTrue);
  });

  test('full hash catches a changed suffix and provenance without clipping', () async {
    final long = List.filled(2000, '前').join();
    await db.insertMessage(message('u', 1000, text: '${long}不要执行'));
    final before = await capture('u');
    final roundtrip = ConversationSourceStamp.fromJson(jsonDecode(jsonEncode(before.toJson())));
    expect(await roundtrip!.matches(await db.database), isTrue);
    await db.insertMessage(message('u', 1000, text: '${long}现在执行'));
    expect(await before.matches(await db.database), isFalse);
    final changed = await capture('u');
    await db.insertMessage(message('u', 1000, text: '${long}现在执行', form: '{"form":"q"}'));
    expect(await changed.matches(await db.database), isFalse);
    final withForm = await capture('u');
    await db.insertMessage(message('u', 1000, text: '${long}现在执行',
      form: '{"form":"q"}', context: roleplay()));
    expect(await withForm.matches(await db.database), isFalse);
    expect((await qualify('u')).eligibility, ConversationSourceEligibility.roleplay);
  });

  test('semantic JSON order is stable but rewritten user invalidates attempt', () async {
    final created = await db.createGenerationTurn(user: message('u', 1000,
      form: '{"form":"normal","v":1}'), assistantMessageId: 'a',
      model: 'deepseek-flash', reasoningEffort: 'high');
    final job = (await db.claimGenerationJob(created.id))!;
    final before = await capture('u');
    final sql = await db.database;
    await sql.update('messages', {'form_context_json': '{"v":1,"form":"normal"}'},
      where: 'id = ?', whereArgs: ['u']);
    expect(await before.matches(sql), isTrue);
    final attempt = (await db.captureGenerationAttemptFence(job))!;
    await db.insertMessage(message('u', 1000, text: '新的要求',
      form: '{"v":1,"form":"normal"}'));
    expect(await attempt.matches(sql), isFalse);
  });

  test('durable pair crosses batch and time boundaries; proactive is unpaired', () async {
    final created = await db.createGenerationTurn(user: message('u', 2000),
      assistantMessageId: 'a', model: 'deepseek-flash', reasoningEffort: 'high');
    final job = (await db.claimGenerationJob(created.id))!;
    await db.insertMessage(message('p', 2100, role: 'assistant', proactive: true));
    expect(await db.completeGenerationJobIfCurrent(jobId: job.id,
      runToken: job.runToken,
      assistant: message('a', 500, role: 'assistant', context: roleplay())), isTrue);
    final firstPage = await ConversationSourceStore.scanAfter(await db.database,
      afterSeq: 0, limit: 1);
    expect(firstPage.sources, hasLength(1));
    // The user was requeued when paired provenance became committed.
    expect((await qualify('u')).eligibility, ConversationSourceEligibility.roleplay);
    expect((await qualify('p')).isOrdinary, isTrue);
    final stamp = await capture('u');
    expect(await stamp.matches(await db.database), isTrue);
  });

  test('legacy pair checks outside page, never crosses another user or proactive', () async {
    await db.insertMessage(message('u', 1000));
    await db.insertMessage(message('p', 1500, role: 'assistant',
      proactive: true, context: roleplay()));
    await db.insertMessage(message('a', 2000, role: 'assistant', context: roleplay()));
    final first = await ConversationSourceStore.scanAfter(await db.database, afterSeq: 0, limit: 1);
    expect(first.sources.single.eligibility, ConversationSourceEligibility.roleplay);
    await db.insertMessage(message('u2', 3000));
    await db.insertMessage(message('u3', 4000, context: roleplay()));
    expect((await qualify('u2')).isOrdinary, isTrue);
    await db.insertMessage(message('a4', 5000, role: 'assistant', text: '普通答复'));
    expect((await qualify('a4')).eligibility, ConversationSourceEligibility.roleplay);
  });

  test('same-millisecond legacy pair is unresolved, not guessed from UUID', () async {
    await db.insertMessage(message('a-user', 1000));
    await db.insertMessage(message('z-answer', 1000, role: 'assistant', context: roleplay()));
    expect((await qualify('a-user')).eligibility, ConversationSourceEligibility.unresolved);
  });

  test('knowledge and behavior remain ordinary, legacy standalone user is retained', () async {
    for (final kind in ['knowledge', 'behavior']) {
      await db.insertMessage(message(kind, kind == 'knowledge' ? 1000 : 2000,
        context: WorldBookTurnContext(sources: [WorldBookSourceRef(
          documentId: kind, entryType: kind, version: 1)]).encode()));
      expect((await qualify(kind)).isOrdinary, isTrue);
    }
    await db.insertMessage(message('old', 3000));
    expect((await qualify('old')).isOrdinary, isTrue);
  });

  test('clock rollback and equal time remain visible after an acknowledged seq', () async {
    await db.insertMessage(message('old', 2000));
    final cursor = (await capture('old')).ingestSeq;
    await db.insertMessage(message('backdate', 1000));
    await db.insertMessage(message('same-ms', 2000));
    final next = await ConversationSourceStore.scanAfter(await db.database, afterSeq: cursor);
    expect(next.sources.map((s) => s.stamp.id), ['backdate', 'same-ms']);
    expect(next.sources.first.stamp.observedAt.millisecondsSinceEpoch, 1000);
  });

  test('background and proactive commits use the same sequence writer', () async {
    await db.insertMessage(message('old', 2000));
    final cursor = (await capture('old')).ingestSeq;
    final fence = (await db.captureBrainWorkFence())!;
    final reminder = message('reminder', 500, role: 'assistant', proactive: true);
    expect(await db.insertBackgroundMessage(reminder, fence), isTrue);
    final first = (await capture('reminder')).ingestSeq;
    expect(await db.insertBackgroundMessage(reminder, fence), isTrue);
    expect((await capture('reminder')).ingestSeq, first);
    expect(await db.commitProactiveMessageIfCurrent(
      message: message('proactive', 600, role: 'assistant', proactive: true),
      evaluationStartedAt: DateTime.now(), workFence: fence), isNull);
    final next = await ConversationSourceStore.scanAfter(await db.database, afterSeq: cursor);
    expect(next.sources.map((s) => s.stamp.id), ['reminder', 'proactive']);
  });

  test('restored runtime rejects an old attempt even if its source is unchanged', () async {
    final created = await db.createGenerationTurn(user: message('u', 1000),
      assistantMessageId: 'a', model: 'deepseek-flash', reasoningEffort: 'high');
    final job = (await db.claimGenerationJob(created.id))!;
    final attempt = (await db.captureGenerationAttemptFence(job))!;
    final source = await capture('u');
    await db.setSetting('runtime_state_epoch_v1', 'restored-other-snapshot');
    expect(await source.matches(await db.database), isTrue);
    expect(await attempt.matches(await db.database), isFalse);
  });

  test('regeneration requeues paired eligibility without changing the user source', () async {
    final created = await db.createGenerationTurn(user: message('u', 1000),
      assistantMessageId: 'a', model: 'deepseek-flash', reasoningEffort: 'high');
    final job = (await db.claimGenerationJob(created.id))!;
    await db.completeGenerationJobIfCurrent(jobId: job.id, runToken: job.runToken,
      assistant: message('a', 2000, role: 'assistant'));
    final qualified = await qualify('u');
    final source = await capture('u');
    expect(await db.restartLatestCompletedReply('a'), isNotNull);
    expect((await qualify('u')).eligibility, ConversationSourceEligibility.unresolved);
    expect((await capture('u')).ingestSeq, greaterThan(source.ingestSeq));
    expect(await source.matches(await db.database), isTrue);
    expect(await qualified.matches(await db.database), isFalse);
  });

  test('idempotent writes do not requeue, changed versions do, deleted max is not reused', () async {
    await db.insertMessage(message('u', 1000));
    final original = await capture('u');
    await db.insertMessage(message('u', 1000));
    expect((await capture('u')).ingestSeq, original.ingestSeq);
    final sql = await db.database;
    await sql.transaction((txn) => ConversationSourceStore.insertMessage(txn,
      message('u', 1000, text: 'ignored').toDb(), conflictAlgorithm: ConflictAlgorithm.ignore));
    expect((await capture('u')).ingestSeq, original.ingestSeq);
    await db.insertMessage(message('u', 1000, text: 'changed'));
    final changed = await capture('u');
    expect(changed.ingestSeq, greaterThan(original.ingestSeq));
    await sql.delete('messages', where: 'id = ?', whereArgs: ['u']);
    await db.insertMessage(message('new', 50));
    expect((await capture('new')).ingestSeq, greaterThan(changed.ingestSeq));
  });

  test('attachment semantic changes invalidate stamp; file relocation does not', () async {
    final image = MessageAttachment(id: 'image', messageId: 'u', kind: 'image',
      originalPath: 'a.jpg', thumbnailPath: 'a-small.jpg', mimeType: 'image/jpeg',
      byteSize: 1, width: 1, height: 1, source: 'gallery',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000));
    await db.insertMessageWithAttachments(message('u', 1000), [image]);
    final before = await capture('u');
    expect((await qualify('u')).eligibility, ConversationSourceEligibility.unresolved);
    final sql = await db.database;
    await sql.update('message_attachments', {'original_path': 'moved.jpg',
      'thumbnail_path': 'moved-small.jpg'}, where: 'id = ?', whereArgs: ['image']);
    expect(await before.matches(sql), isTrue);
    expect(await db.markAttachmentVisionAnalyzing('image'), isTrue);
    await db.failAttachmentVision('image', 'offline');
    final failed = await capture('u');
    expect(failed.ingestSeq, greaterThan(before.ingestSeq));
    expect(await before.matches(sql), isFalse);
    await db.markAttachmentVisionAnalyzing('image');
    await db.completeAttachmentVisionAndCreateGeneration(attachmentId: 'image',
      summary: '真实图片有一只猫', visionModel: 'test', assistantMessageId: 'a',
      model: 'deepseek-flash', reasoningEffort: 'high');
    expect((await capture('u')).ingestSeq, greaterThan(failed.ingestSeq));
    expect((await qualify('u')).eligibility, ConversationSourceEligibility.unresolved);
  });

  test('legacy blob migration requeues each changed source once and replay is stable', () async {
    MessageAttachment attachment(String id) => MessageAttachment(
      id: id, messageId: 'u', kind: 'image', originalPath: '$id.jpg',
      thumbnailPath: '$id-small.jpg', mimeType: 'image/jpeg', byteSize: 1,
      width: 1, height: 1, source: 'gallery',
      visionStatus: MessageAttachment.visionCompletedStatus,
      visionSummary: '已识别的旧图片',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000));
    await db.insertMessageWithAttachments(message('u', 1000),
      [attachment('image-1'), attachment('image-2')]);
    await db.insertMessage(message('unrelated', 500));
    final original = await capture('u');
    final unrelated = await capture('unrelated');
    final cursor = unrelated.ingestSeq;
    final blobId = List.filled(64, 'a').join();
    final blob = MediaBlob(id: blobId, originalPath: '$blobId.jpg',
      thumbnailPath: '$blobId-small.jpg', originalSha256: blobId,
      thumbnailSha256: List.filled(64, 'b').join(), mimeType: 'image/jpeg',
      byteSize: 1, thumbnailByteSize: 1, width: 1, height: 1,
      messageRefCount: 0, albumRefCount: 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000));

    await db.migrateMediaBlobReferences(blob: blob,
      messageAttachmentIds: ['image-1', 'image-2', 'image-1', 'missing']);
    final migrated = await capture('u');
    expect(await original.matches(await db.database), isFalse);
    expect(migrated.ingestSeq, cursor + 1);
    expect((await capture('unrelated')).ingestSeq, cursor);
    expect(await unrelated.matches(await db.database), isTrue);
    final changed = await ConversationSourceStore.scanAfter(await db.database,
      afterSeq: cursor);
    expect(changed.sources.map((source) => source.stamp.id), ['u']);
    final attachments = await (await db.database).query('message_attachments',
      columns: ['blob_id'], where: 'message_id = ?', whereArgs: ['u']);
    expect(attachments.map((row) => row['blob_id']), [blobId, blobId]);

    await db.migrateMediaBlobReferences(blob: blob,
      messageAttachmentIds: ['image-1', 'image-2', 'missing']);
    expect((await capture('u')).ingestSeq, migrated.ingestSeq);
    expect(await migrated.matches(await db.database), isTrue);
    expect(await db.getSetting(ConversationSourceStore.sequenceKey),
      '${migrated.ingestSeq}');
    expect((await ConversationSourceStore.scanAfter(await db.database,
      afterSeq: migrated.ingestSeq)).sources, isEmpty);
  });

  test('snapshot preserves sequences and deleted high water; legacy import backfills once', () async {
    await db.insertMessage(message('first', 1000));
    await db.insertMessage(message('last', 2000));
    final high = (await capture('last')).ingestSeq;
    await (await db.database).delete('messages', where: 'id = ?', whereArgs: ['last']);
    final backup = await db.exportAll();
    await db.importAll(backup);
    expect((await capture('first')).ingestSeq, 1);
    await db.insertMessage(message('after-restore', 500));
    expect((await capture('after-restore')).ingestSeq, greaterThan(high));

    final legacy = jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;
    // This fixture predates source sequences and the history directory.
    legacy.remove('conversation_history_catalog_version');
    final tables = legacy['tables'] as Map;
    tables.remove('conversation_history_catalog');
    for (final row in tables['messages'] as List) { (row as Map).remove('source_ingest_seq'); }
    (tables['settings'] as List).removeWhere((row) =>
      (row as Map)['key'] == ConversationSourceStore.sequenceKey ||
      row['key'] == ConversationSourceStore.legacySummaryCoveredKey);
    tables['conversation_summaries'] = [{'id': 'legacy-summary', 'from_at': 0,
      'to_at': 500, 'summary': '已有摘要', 'key_points': '', 'created_at': 600}];
    await db.importAll(legacy);
    final earlier = await capture('after-restore');
    final later = await capture('first');
    expect(earlier.ingestSeq, lessThan(later.ingestSeq));
    expect(await db.getSetting(ConversationSourceStore.legacySummaryCoveredKey), '${earlier.ingestSeq}');
    await (await db.database).transaction(ConversationSourceStore.ensureSchema);
    expect((await capture('first')).ingestSeq, later.ingestSeq);
    expect(await db.getSetting(ConversationSourceStore.legacySummaryCoveredKey), '${earlier.ingestSeq}');
  });

  test('source sequence and row roll back together', () async {
    final sql = await db.database;
    final before = await db.getSetting(ConversationSourceStore.sequenceKey);
    await expectLater(sql.transaction((txn) async {
      await ConversationSourceStore.insertMessage(txn, message('rollback', 1).toDb());
      throw StateError('controlled commit failure');
    }), throwsStateError);
    expect(await db.messageById('rollback'), isNull);
    expect(await db.getSetting(ConversationSourceStore.sequenceKey), before);
  });
}
