import 'dart:async';

import 'package:ai_companion_localfirst/core/ai/prompt_builder.dart';
import 'package:ai_companion_localfirst/core/autonomy/public_web_read_service.dart';
import 'package:ai_companion_localfirst/core/autonomy/public_web_share_contract.dart';
import 'package:ai_companion_localfirst/core/autonomy/public_web_share_policy.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/desire/conversation_initiative_policy.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const body = 'Whale song contains repeated themes and phrases. Researchers compare '
    'recordings from different years to describe changes within a population. '
    'These observations do not establish every proposed explanation of the songs.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late Database sql;
  late String id;
  late int reads;
  late PublicWebReadService service;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    sql = await db.database;
    id = await db.seedDiagnosticPublicWebShareCandidate();
    reads = 0;
    await sql.update('public_web_candidates', {
      'page_body': body,
      'lifecycle_state': 'shared',
      'shared_message_id': 'previous-share',
      'read_at': DateTime.now().subtract(const Duration(minutes: 10)).millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [id]);
    final row = (await sql.query('public_web_candidates', where: 'id = ?', whereArgs: [id])).single;
    await sql.insert('public_web_knowledge', {
      'candidate_id': id, 'title': row['title'], 'summary': row['summary'],
      'url': row['url'], 'source_domain': row['source_domain'],
      'content_sha256': row['content_sha256'], 'lifecycle_state': 'active',
      'read_at': row['read_at'], 'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await db.upsertThought(id: 'selected-web-thought', text: PublicWebSharePolicy.thoughtText,
      drive: DriveKey.curiosity, kind: 'flit', strength: .62,
      source: PublicWebSharePolicy.source(id), topicKey: PublicWebSharePolicy.topicKey(id));
    service = PublicWebReadService(db, reader: (page, _, __) async {
      reads++;
      return page.copyWith(pageBody: body, readAt: DateTime.now());
    });
  });
  tearDown(() async => db.closeForTesting());

  test('actual ordinary prompt includes selected history body and specific expression evidence', () async {
    final thought = (await db.thoughtById('selected-web-thought'))!;
    final built = await PromptBuilder(db, webReader: (page, _, __) async {
      reads++;
      return page.copyWith(readAt: DateTime.now());
    }).buildChatPrompt(latestUserText: '今天的安排', recent: const [],
      desire: await db.loadDesire(), thoughts: [thought], historicalWebIds: const [],
      conversationInitiativeOverride: const ConversationInitiativePlan(
        primary: ConversationInitiativeMode.shareOwnView, topicMove: ConversationTopicMove.stay,
        speechAct: ConversationSpeechAct.selfShare, drive: DriveKey.curiosity, action: 'share_thought',
        scoreBand: 'high', hasThought: true, sourceProvenance: 'public_web_candidate',
        askAuthorized: false, curiosityGateReason: 'no_specific_gap', questionPressureBand: 'none',
        alternatives: [], sourceThoughtId: 'selected-web-thought'));
    final text = built.messages.map((m) => m['content']).join('\n');
    expect(text, contains(body));
    expect(built.publicWebSources.single.profile, PublicWebSourceProfile.historicalKnowledge);
    expect(built.expectedPublicWebShare, isNull);
    expect(built.selectedThoughtEvidence!['title'], '座头鲸的歌声会随时间变化');
    expect(built.selectedThoughtEvidence, isNot(contains('thought')));
    expect(reads, 1);
  });

  test('selected shared thought supplies historical body on consecutive ordinary turns', () async {
    for (var turn = 0; turn < 2; turn++) {
      final bundle = await service.preparePromptBundle(candidateIds: [id]);
      expect(bundle.items, isEmpty);
      expect(bundle.knowledgeItems.single.id, id);
      expect(bundle.knowledgeItems.single.pageBody, body);
      expect(bundle.sourceStamps.single.profile, PublicWebSourceProfile.historicalKnowledge);
      expect(bundle.expectedShare, isNull);
      final thought = (await db.thoughtById('selected-web-thought'))!;
      expect(thought.actionCount, 0);
      expect(thought.lifecycleState, 'active');
    }
    expect(reads, 1, reason: 'the next turn may reuse the freshly qualified body');
    final row = (await sql.query('public_web_candidates', where: 'id = ?', whereArgs: [id])).single;
    expect(row['shared_message_id'], 'previous-share');
    expect(row['lifecycle_state'], 'shared');
  });

  test('overlapping IDs read once and expired candidate retains active history qualification', () async {
    await sql.update('public_web_candidates', {
      'expires_at': DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [id]);
    final bundle = await service.preparePromptBundle(candidateIds: [id, id], historicalKnowledgeIds: [id]);
    expect(reads, 1);
    expect(bundle.knowledgeItems.single.pageBody, body);
    expect(bundle.sourceStamps, hasLength(1));
  });

  for (final invalid in ['revoked', 'missing_history', 'user_deleted', 'declined', 'discarded', 'share_staging']) {
    test('$invalid is rejected before reading or displaying a read activity', () async {
      if (invalid == 'missing_history') {
        await sql.delete('public_web_knowledge', where: 'candidate_id = ?', whereArgs: [id]);
      } else if (invalid == 'revoked') {
        await sql.update('public_web_knowledge', {'lifecycle_state': 'revoked'},
          where: 'candidate_id = ?', whereArgs: [id]);
      } else {
        await sql.update('public_web_candidates', {'lifecycle_state': invalid},
          where: 'id = ?', whereArgs: [id]);
      }
      var activities = 0;
      final bundle = await service.preparePromptBundle(candidateIds: [id],
        historicalKnowledgeIds: [id], onActivity: (_) => activities++);
      expect(bundle.sourceStamps, isEmpty);
      expect(reads, 0);
      expect(activities, 0);
    });
  }

  test('explicit new share never falls back to already shared history', () async {
    final bundle = await service.preparePromptBundle(candidateIds: [id], historicalKnowledgeIds: [id],
      selectedShareCandidateId: id, selectedShareThoughtId: 'selected-web-thought');
    expect(bundle.sourceStamps, isEmpty);
    expect(bundle.expectedShare, isNull);
    expect(reads, 0);
  });

  test('new share keeps its own qualification and selected thought contract', () async {
    await sql.update('public_web_candidates', {'lifecycle_state': 'share_ready', 'shared_message_id': ''},
      where: 'id = ?', whereArgs: [id]);
    final bundle = await service.preparePromptBundle(candidateIds: [id], historicalKnowledgeIds: [id],
      selectedShareCandidateId: id, selectedShareThoughtId: 'selected-web-thought');
    expect(bundle.items.single.id, id);
    expect(bundle.knowledgeItems, isEmpty);
    expect(bundle.sourceStamps.single.profile, PublicWebSourceProfile.share);
    expect(bundle.expectedShare, isNotNull);
  });

  test('ordinary new candidate stays in candidate context despite an overlapping history ID', () async {
    await sql.update('public_web_candidates', {'lifecycle_state': 'unread'},
      where: 'id = ?', whereArgs: [id]);
    final bundle = await service.preparePromptBundle(candidateIds: [id], historicalKnowledgeIds: [id]);
    expect(bundle.items.single.id, id);
    expect(bundle.knowledgeItems, isEmpty);
    expect(bundle.sourceStamps.single.profile, PublicWebSourceProfile.candidateContext);
    expect(bundle.expectedShare, isNull);
  });

  for (final mutation in ['revoke', 'delete']) {
    test('$mutation while reader waits excludes the completed read from the prompt', () async {
      final entered = Completer<void>(), release = Completer<void>();
      final guarded = PublicWebReadService(db, reader: (page, _, __) async {
        entered.complete();
        await release.future.timeout(const Duration(seconds: 5));
        return page.copyWith(readAt: DateTime.now());
      });
      final work = guarded.preparePromptBundle(candidateIds: [id]);
      try {
        await entered.future.timeout(const Duration(seconds: 5));
        if (mutation == 'revoke') {
          await sql.update('public_web_knowledge', {'lifecycle_state': 'revoked'},
            where: 'candidate_id = ?', whereArgs: [id]);
        } else {
          await sql.update('public_web_candidates', {'lifecycle_state': 'user_deleted'},
            where: 'id = ?', whereArgs: [id]);
        }
      } finally {
        release.complete();
      }
      expect((await work).sourceStamps, isEmpty);
    });
  }

  test('a failed read cannot substitute a generic thought for missing page evidence', () async {
    final failed = PublicWebReadService(db, reader: (_, __, ___) async => throw StateError('offline'));
    await expectLater(failed.preparePromptBundle(candidateIds: [id]), throwsStateError);
    expect((await db.thoughtById('selected-web-thought'))!.actionCount, 0);
  });
}
