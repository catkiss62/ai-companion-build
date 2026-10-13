import 'package:ai_companion_localfirst/core/autonomy/public_web_share_contract.dart';
import 'package:ai_companion_localfirst/core/autonomy/public_web_share_policy.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/brain_work_fence.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Independent review of the real prompt-bundle/SQLite delivery boundary. The
// discovery fixture is local; neither network nor the commit method is mocked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const limit = Duration(seconds: 30);
  late AppDatabase db;
  late Database handle;
  late DateTime instant;
  late String shareId;
  const thoughtId = 'atomic-web-thought';
  const knowledgeId = 'atomic-web-knowledge';
  const body = 'Whale song has repeated phrases and themes. Researchers compare '
      'recordings from different dates and groups to describe how those themes '
      'change. The recordings do not establish every proposed explanation.';

  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    handle = await db.database;
    instant = DateTime.now();
    shareId = await db.seedDiagnosticPublicWebShareCandidate(now: instant);
    final seeded = (await handle.query('public_web_candidates',
      where: 'id = ?', whereArgs: [shareId])).single;
    // Make this an ordinary autonomous candidate so interest evidence really
    // executes. Diagnostic candidates intentionally skip that production path.
    await handle.update('autonomous_action_runs', {
      'reason_source': 'self_drive/curiosity',
    }, where: 'id = ?', whereArgs: [seeded['action_run_id']]);
    await handle.update('public_web_candidates', {
      'lifecycle_state': 'share_ready', 'provider': 'local_fixture',
      'interest_key': 'whale_song', 'page_body': body,
      'motive_kind': 'curiosity', 'why_cared': 'The changes invite comparison.',
    }, where: 'id = ?', whereArgs: [shareId]);
    final share = (await handle.query('public_web_candidates',
      where: 'id = ?', whereArgs: [shareId])).single;
    await handle.insert('public_web_candidates', {
      ...share, 'id': knowledgeId, 'fingerprint': 'atomic-knowledge-fingerprint',
      'lifecycle_state': 'shared', 'semantic_state': 'history_only',
      'title': 'Previously read comparison', 'summary': 'A separate older reading.',
      'expires_at': instant.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      'read_at': instant.subtract(const Duration(days: 3)).millisecondsSinceEpoch,
      'shared_message_id': 'historical-message',
    });
    await handle.insert('public_web_knowledge', {
      'candidate_id': knowledgeId, 'title': 'Retrieval title',
      'summary': 'Retrieval index, not the rendered body.', 'url': share['url'],
      'source_domain': share['source_domain'], 'content_sha256': share['content_sha256'],
      'lifecycle_state': 'active', 'read_at': share['read_at'],
      'created_at': instant.millisecondsSinceEpoch,
    });
    await db.upsertThought(id: thoughtId, text: PublicWebSharePolicy.thoughtText,
      drive: DriveKey.curiosity, kind: 'flit', strength: .62,
      source: PublicWebSharePolicy.source(shareId),
      topicKey: PublicWebSharePolicy.topicKey(shareId));
  });
  tearDown(() async { await db.closeForTesting().timeout(limit); });

  Future<PublicWebPromptBundle> bundle() => db.publicWebPromptBundle(
    candidateIds: [shareId], historicalKnowledgeIds: [knowledgeId],
    selectedShareCandidateId: shareId, selectedShareThoughtId: thoughtId);
  Future<BrainWorkFence> fence() async => (await db.captureBrainWorkFence(
    settingKeys: const ['conversation_context_reset_at', 'conversation_context_reset_count']))!;
  Future<String?> commit(PublicWebPromptBundle material, BrainWorkFence owner,
      {String messageId = 'atomic-web-message'}) => db.commitProactiveMessageIfCurrent(
    message: ChatMessage(id: messageId, role: 'assistant', content: 'The recordings show changing phrases.',
      createdAt: instant, isProactive: true),
    evaluationStartedAt: instant, deliveryAt: instant,
    workFence: owner, publicWebSources: material.sourceStamps,
    expectedPublicWebShare: material.expectedShare,
    proactiveTriggerReason: 'public_web_atomic_review', enforceProactiveBudget: true);
  Future<int> count(String table) async =>
      (await handle.rawQuery('SELECT COUNT(*) AS n FROM $table')).single['n'] as int;
  Future<void> untouched() async {
    expect(await count('messages'), 0);
    expect(await count('proactive_history'), 0);
    expect(await count('ai_interest_evidence'), 0);
    expect(await count('ai_interest_candidates'), 0);
    expect(await count('thought_lifecycle_events'), 0);
    final share = (await handle.query('public_web_candidates',
      where: 'id = ?', whereArgs: [shareId])).single;
    expect(share['shared_message_id'], '');
    final thought = (await db.thoughtById(thoughtId))!;
    expect(thought.actionCount, 0);
    expect(thought.lastOutboundMessageId, isNull);
  }
  Future<void> delivered() async {
    expect(await count('messages'), 1);
    expect(await count('proactive_history'), 1);
    expect(await count('ai_interest_evidence'), 1);
    expect(await count('ai_interest_candidates'), 1);
    expect(await count('thought_lifecycle_events'), 1);
    final share = (await handle.query('public_web_candidates',
      where: 'id = ?', whereArgs: [shareId])).single;
    expect(share['lifecycle_state'], 'shared');
    expect(share['shared_message_id'], 'atomic-web-message');
    final thought = (await db.thoughtById(thoughtId))!;
    expect(thought.actionCount, 1);
    expect(thought.lastOutboundMessageId, 'atomic-web-message');
  }

  for (final mutation in ['share_summary', 'share_motive', 'share_interest',
      'knowledge_body', 'knowledge_revoked', 'share_expired', 'thought_snoozed']) {
    test('captured actual material rejects $mutation before any delivery effect', () async {
      final material = await bundle(), owner = await fence();
      expect(material.items.single.id, shareId);
      expect(material.knowledgeItems.single.id, knowledgeId);
      expect(material.sourceStamps.map((source) => source.id).toSet(),
        {shareId, knowledgeId});
      expect(material.expectedShare, isNotNull);
      switch (mutation) {
        case 'share_summary':
          await handle.update('public_web_candidates', {'summary': 'Different conclusion, same body hash.'},
            where: 'id = ?', whereArgs: [shareId]);
        case 'share_motive':
          await handle.update('public_web_candidates', {'why_cared': 'A different motive.'},
            where: 'id = ?', whereArgs: [shareId]);
        case 'share_interest':
          await handle.update('public_web_candidates', {'interest_key': 'different_interest'},
            where: 'id = ?', whereArgs: [shareId]);
        case 'knowledge_body':
          await handle.update('public_web_candidates', {'page_body': '$body A new qualification.'},
            where: 'id = ?', whereArgs: [knowledgeId]);
        case 'knowledge_revoked':
          await handle.update('public_web_knowledge', {'lifecycle_state': 'revoked'},
            where: 'candidate_id = ?', whereArgs: [knowledgeId]);
        case 'share_expired':
          await handle.update('public_web_candidates', {
            'expires_at': instant.subtract(const Duration(seconds: 1)).millisecondsSinceEpoch,
          }, where: 'id = ?', whereArgs: [shareId]);
        case 'thought_snoozed':
          await handle.update('thoughts', {
            'snoozed_until': instant.add(const Duration(hours: 1)).millisecondsSinceEpoch,
          }, where: 'id = ?', whereArgs: [thoughtId]);
      }
      expect(await commit(material, owner), isNotNull);
      await untouched();
    });
  }

  test('view maintenance and expired historical share TTL preserve one atomic delivery', () async {
    final material = await bundle(), owner = await fence();
    expect(material.knowledgeItems.single.pageBody, body);
    await handle.update('public_web_candidates', {
      'view_count': 9, 'last_viewed_at': instant.millisecondsSinceEpoch,
    });
    expect(await commit(material, owner), isNull);
    await delivered();
    expect(await commit(material, owner, messageId: 'must-not-send-again'),
      'public_web_already_committed');
    await delivered();
  });

  test('expiry alone invalidates a captured share with every stored byte unchanged', () async {
    final material = await bundle();
    final share = material.expectedShare!;
    final expiry = DateTime.fromMillisecondsSinceEpoch(share.source.expiresAt);
    expect(await share.matches(handle, now: expiry.subtract(const Duration(milliseconds: 1))), isTrue);
    expect(await share.matches(handle, now: expiry), isFalse);
    final history = material.sourceStamps.singleWhere((source) => source.id == knowledgeId);
    expect(await history.matches(handle, now: expiry), isTrue);
    await untouched();
  });

  test('old declined draft cannot sleep a changed candidate thought or rewrite stage outcome', () async {
    final material = await bundle(), owner = await fence();
    await handle.update('public_web_candidates', {'summary': 'A newly read conclusion.'},
      where: 'id = ?', whereArgs: [shareId]);
    final outcome = await db.getSetting('public_web_share_last_outcome');
    expect(await db.declinePublicWebShareIfCurrent(material.expectedShare!,
      workFence: owner), isFalse);
    expect(await db.getSetting('public_web_share_last_outcome'), outcome);
    expect((await db.thoughtById(thoughtId))!.canDriveIntent, isTrue);
    await untouched();
    final current = await bundle();
    expect(await db.declinePublicWebShareIfCurrent(current.expectedShare!,
      workFence: owner), isTrue);
    expect((await db.thoughtById(thoughtId))!.lifecycleState, 'dormant');
    expect(await count('messages'), 0);
    expect(await count('proactive_history'), 0);
  });

  for (final point in ['candidate', 'interest']) {
    test('SQLite $point failure rolls back message quota thought and interest, retry commits once', () async {
      final material = await bundle(), owner = await fence();
      final trigger = point == 'candidate'
          ? "BEFORE UPDATE OF lifecycle_state ON public_web_candidates WHEN NEW.lifecycle_state = 'shared'"
          : 'BEFORE INSERT ON ai_interest_evidence';
      await handle.execute("CREATE TRIGGER fail_web_delivery $trigger BEGIN SELECT RAISE(ABORT, 'injected_web_atomic_failure'); END");
      try {
        await expectLater(commit(material, owner), throwsA(isA<DatabaseException>()));
        await untouched();
      } finally {
        await handle.execute('DROP TRIGGER IF EXISTS fail_web_delivery');
      }
      expect(await commit(material, owner), isNull);
      await delivered();
    });
  }

  test('recent reading profiles retain 14 day material while short share TTL expires', () async {
    final row = (await handle.query('public_web_candidates',
      where: 'id = ?', whereArgs: [knowledgeId])).single;
    final wish = PublicWebSourceStamp.capture(row,
      profile: PublicWebSourceProfile.wish, now: instant);
    expect(wish, isNotNull);
    expect(PublicWebSourceStamp.capture(row,
      profile: PublicWebSourceProfile.reflection, now: instant), isNull);
    final valid = {...row, 'semantic_state': 'valid'};
    expect(PublicWebSourceStamp.capture(valid,
      profile: PublicWebSourceProfile.reflection, now: instant), isNotNull);
    expect(PublicWebSourceStamp.capture(valid,
      profile: PublicWebSourceProfile.share, now: instant), isNull);
    expect(await wish!.matches(handle, now: instant), isTrue);
    expect(await wish.matches(handle, now: instant.add(const Duration(days: 12))), isFalse);
    expect(PublicWebSourceStamp.capture({...valid,
      'read_at': instant.add(const Duration(seconds: 1)).millisecondsSinceEpoch,
    }, profile: PublicWebSourceProfile.wish, now: instant), isNull);
  });
}
