import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_topic_evidence.dart';
import 'package:ai_companion_localfirst/core/memory/memory_grounding_policy.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/memory_item.dart';
import 'package:ai_companion_localfirst/core/models/world_book_turn_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  final start = DateTime(2026, 11, 12, 23);
  final now = DateTime(2026, 11, 18, 18);
  final seed = MemoryItem(
    id: 'old-progress',
    kind: 'event',
    content: '用户看电视剧潮汐邮局到第十集',
    importance: .7,
    createdAt: start,
    updatedAt: now,
    lastEvidenceAt: start,
    evidenceTimeKnown: true,
    actorKey: 'user',
    factState: 'ongoing',
    sourceUserMessageId: 'progress',
  );

  setUp(
    () async => db = await AppDatabase.createForTesting(databaseFactoryFfi),
  );
  tearDown(() => db.closeForTesting());

  Future<void> say(
    String id,
    String text,
    int minutes, {
    bool fiction = false,
  }) => db.insertMessage(
    ChatMessage(
      id: id,
      role: 'user',
      content: text,
      createdAt: start.add(Duration(minutes: minutes)),
      worldBookContextJson: fiction
          ? const WorldBookTurnContext(roleplaySessionId: 'fiction').encode()
          : '',
    ),
  );

  Future<({String prompt, bool completed})> recall({
    bool withSeed = true,
  }) async {
    final fence = (await db.captureBrainWorkFence(
      settingKeys: ['conversation_context_reset_at'],
    ))!;
    return ProactiveTopicEvidence(db).read(
      fence: fence,
      cue: '《潮汐邮局》看到第十集',
      now: now,
      seed: withSeed ? seed : null,
      namedQuestion: !withSeed,
    );
  }

  test(
    'old progress follows a bare completion using source time and ordinary chat',
    () async {
      await say('progress', '《潮汐邮局》现在在第十集', 0);
      await say('finish', '看完了，结尾挺意外', 93);
      final evidence = await recall();
      expect(evidence.completed, isTrue);
      expect(evidence.prompt, contains('看完了，结尾挺意外'));
      expect(evidence.prompt, contains('2026-11-13T00:33'));
      expect(evidence.prompt, contains('REAL_USER_HISTORY'));
      expect((await recall(withSeed: false)).completed, isTrue);
      expect(await (await db.database).query('memory_items'), isEmpty);
    },
  );

  test(
    'new viewing round supersedes completion and other works do not',
    () async {
      await say('progress', '《潮汐邮局》看到第十集', 0);
      await say('finish', '看完了', 30);
      await say('repeat', '重看《潮汐邮局》，到第三集了', 24 * 60);
      await say('sequel', '《潮汐邮局2》看完了', 25 * 60);
      final evidence = await recall();
      expect(evidence.completed, isFalse);
      expect(evidence.prompt, contains('"status":"ongoing"'));
      expect(evidence.prompt, contains('重看《潮汐邮局》'));
      expect(evidence.prompt, isNot(contains('潮汐邮局2')));
    },
  );

  test(
    'other speakers, fiction, changed subjects and reset cannot complete the record',
    () async {
      await say('progress', '《潮汐邮局》看到第十集', 0);
      await say('other', '我朋友看完了《潮汐邮局》', 15);
      await say('roleplay', '我看完了《潮汐邮局》', 21, fiction: true);
      await say('unrelated', '快递到了', 30);
      await say('unnamed', '看完了', 60);
      var evidence = await recall();
      expect(evidence.completed, isFalse);
      expect(evidence.prompt, contains('last_known_currently_unknown'));
      expect(evidence.prompt, isNot(contains('看完了')));
      await db.setSetting(
        'conversation_context_reset_at',
        start.add(const Duration(days: 1)).millisecondsSinceEpoch.toString(),
      );
      evidence = await recall();
      expect(evidence.completed, isFalse);
      expect(evidence.prompt, isNot(contains('看到第十集')));
    },
  );

  test(
    'question, completion of an episode and unknown evidence time stay distinct',
    () {
      expect(ProactiveTopicEvidence.namedStatusQuestion('《潮汐邮局》你看了没'), '潮汐邮局');
      expect(ProactiveTopicEvidence.namedStatusQuestion('我突然想起《潮汐邮局》'), isNull);
      expect(
        ProactiveTopicEvidence.progressIn('看完第十集了', viewing: true),
        TopicProgress.ongoing,
      );
      expect(
        ProactiveTopicEvidence.progressIn('你看完了吗？', viewing: true),
        isNull,
      );
      expect(
        MemoryGroundingPolicy.thoughtTemporalNote(
          provenance: 'memory',
          sourceTime: null,
          now: now,
        ),
        contains('last_evidence=unknown'),
      );
    },
  );
}
