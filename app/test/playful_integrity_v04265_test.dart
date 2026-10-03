import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_planner.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/nsfw_context_router.dart';
import 'package:ai_companion_localfirst/core/models/message_attachment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/generation_job.dart';
import 'package:ai_companion_localfirst/core/personality/playful_form_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit();
  final now = DateTime.utc(2026, 10, 3, 6);
  PlayfulFormState finish(PlayfulFormState s, PlayfulInteraction i, String id,
      {PlayfulSelfActivity self = PlayfulSelfActivity.none}) =>
      s.advance(i, id, now).onAssistantTurn(self, 'a$id', now);
  test('related user categories retain deliberate play', () {
    expect(JevDecisionGateway.resolvePlayfulGroup('chat_intimacy_route', 'interaction',
      {'serious': 0, 'ordinary': .01, 'light': .46, 'mutual': .49, 'strong': .04}), 'mutual');
    expect(JevDecisionGateway.resolvePlayfulGroup('chat_intimacy_route', 'interaction',
      {'serious': 0, 'ordinary': .04, 'light': .49, 'mutual': .45, 'strong': .02}), 'light');
  });
  test('related self categories retain her contribution', () {
    expect(JevDecisionGateway.resolvePlayfulGroup('chat_playful_self', 'route',
      {'none': .03, 'playful': .49, 'strong': .48, 'settle': 0}), 'playful');
  });
  test('uncertainty across play versus ordinary remains neutral', () {
    expect(JevDecisionGateway.resolvePlayfulGroup('chat_intimacy_route', 'interaction',
      {'ordinary': .45, 'mutual': .50, 'strong': .05}), 'ordinary');
    expect(JevDecisionGateway.resolvePlayfulGroup('chat_playful_self', 'route',
      {'none': .48, 'playful': .50, 'strong': .02}), 'none');
  });
  test('last-three pattern transforms on second full-meter stimulus', () {
    final first = finish(const PlayfulFormState(heat: 100), PlayfulInteraction.light, '1', self: PlayfulSelfActivity.strong);
    expect(first.qForm, isFalse); expect(first.stimulusStreak, 1);
    final pending = first.advance(PlayfulInteraction.mutual, '2', now);
    expect(pending.promptForTurn('2'), contains('当前是小豆丁形态'));
    expect(pending.qForm, isFalse);
    final done = pending.onAssistantTurn(PlayfulSelfActivity.strong, 'a2', now);
    expect(done.qForm, isTrue); expect(done.heat, 100); expect(done.stimulusStreak, 0);
  });
  test('strong stimulus once but first filling turn is protected', () {
    expect(finish(const PlayfulFormState(heat: 100), PlayfulInteraction.strong, '1').qForm, isTrue);
    final first = finish(const PlayfulFormState(heat: 90), PlayfulInteraction.strong, '2');
    expect(first.heat, 100); expect(first.qForm, isFalse); expect(first.stimulusStreak, 0);
  });
  test('neutral interruption clears consecutive stimuli without normal cooling', () {
    var s = finish(const PlayfulFormState(heat: 100), PlayfulInteraction.light, '1');
    s = finish(s, PlayfulInteraction.ordinary, '2');
    expect(s.heat, 100); expect(s.stimulusStreak, 0);
    expect(finish(s, PlayfulInteraction.mutual, '3').qForm, isFalse);
  });
  test('Stop restores stimulus and duplicate commit is inert', () {
    final s = finish(const PlayfulFormState(heat: 100), PlayfulInteraction.light, '1');
    final pending = s.advance(PlayfulInteraction.light, '2', now);
    expect(PlayfulFormState.decode(pending.encode()).rollbackTurn('2').encode(), s.encode());
    final done = pending.onAssistantTurn(PlayfulSelfActivity.strong, 'a2', now);
    expect(done.onAssistantTurn(PlayfulSelfActivity.strong, 'a2', now).encode(), done.encode());
  });
  test('lock during generation preserves scoring and Q cooling', () {
    final done = const PlayfulFormState(heat: 50).advance(PlayfulInteraction.mutual, 'u', now)
      .withLock(true).onAssistantTurn(PlayfulSelfActivity.playful, 'a', now);
    expect(done.heat, 83); expect(done.locked, isTrue);
    final q = const PlayfulFormState(heat: 40, qForm: true).advance(PlayfulInteraction.ordinary, 'q', now)
      .withLock(true).onAssistantTurn(PlayfulSelfActivity.none, 'aq', now);
    expect(q.heat, 22); expect(q.qForm, isTrue);
  });
  test('manual action invalidates delayed contributions', () {
    final manual = const PlayfulFormState(heat: 80).advance(PlayfulInteraction.strong, 'u', now)
      .interact(kindle: false, now: now);
    expect(manual.onAssistantTurn(PlayfulSelfActivity.strong, 'a', now).heat, 0);
    expect(manual.rollbackTurn('u').heat, 0);
  });
  test('intense fluster remains a separate full-meter trigger', () {
    final pending = const PlayfulFormState(heat: 100).advance(PlayfulInteraction.ordinary, 'u', now, breakthrough: true);
    expect(pending.promptQForm, isTrue);
    expect(pending.onAssistantTurn(PlayfulSelfActivity.none, 'a', now).qForm, isTrue);
  });
  test('zero boundary sums both contributions; neutral Q exits in six turns', () {
    final s = finish(const PlayfulFormState(heat: 15, qForm: true), PlayfulInteraction.mutual, 'u', self: PlayfulSelfActivity.playful);
    expect(s.heat, 30); expect(s.qForm, isTrue);
    var q = const PlayfulFormState(heat: 100, qForm: true);
    for (var i = 0; i < 6; i++) { q = finish(q, PlayfulInteraction.ordinary, 'q$i'); }
    expect(q.heat, 0); expect(q.qForm, isFalse);
  });
  test('explicit search planning can resolve an elliptical query; chat stays tool-free', () {
    expect(AgentToolPlanner.routeLocally('你去搜搜看')?.calls.single.toolId, 'public_web.search');
    final tools = AgentToolPlanner.nativeToolDefinitionsFor('你去搜搜看');
    expect(tools.map((t) => (t['function'] as Map)['name']), contains('public_web_search'));
    expect(AgentToolPlanner.nativeToolDefinitionsFor('你说得对'), isEmpty);
  });
  test('search negation and discussion do not expose search tools', () {
    for (final text in ['不用搜搜看了', '例如你去搜搜看这种说法', '你看看我呀', '你说得对']) {
      expect(AgentToolPlanner.nativeToolDefinitionsFor(text), isEmpty, reason: text);
    }
  });
  group('SQLite reply and heat atomicity', () {
    late AppDatabase db;
    setUp(() async { db = await AppDatabase.createForTesting(databaseFactoryFfi); });
    tearDown(() async { await db.closeForTesting(); });
    for (final manual in ['on', 'off']) {
      test('manual $manual keeps independent play and sticker semantics', () async {
        await db.setSetting('nsfw_manual_override', manual);
        var calls = 0;
        final sticker = MessageAttachment(id: 'st', messageId: 'prior',
          kind: MessageAttachment.imageKind, originalPath: 'sticker.png',
          thumbnailPath: 'sticker.png', mimeType: 'image/png', byteSize: 10,
          width: 10, height: 10, source: 'user_sticker:test', createdAt: now,
          visionStatus: MessageAttachment.visionCompletedStatus,
          visionSummary: '故意逗她的坏笑', visionModel: 'sticker_index');
        final prior = ChatMessage(id: 'prior', role: 'user', content: '',
          createdAt: now, attachments: [sticker]);
        final gateway = JevDecisionGateway(enabledReader: () async => true,
          keyReader: () async => 'test-key', clientFactory: () => MockClient((request) async {
            calls++;
            final body = jsonDecode(request.body) as Map;
            expect((body['state'] as Map)['recent_context'], contains('故意逗她的坏笑'));
            const picks = {'mode': 'nsfw_reference', 'interaction': 'mutual',
              'flustered': 'no', 'initiative': 'closed'};
            return http.Response(jsonEncode({'answers': picks.map((key, value) => MapEntry(key,
              {'type': 'choice', 'choice': value, 'confidence': 1.0, 'probabilities': {value: 1.0}}))}), 200);
          }));
        final router = NsfwContextRouter(db: db, client: DeepSeekClient(), jevGateway: gateway);
        final result = await router.decide(apiKey: 'unused', endpoint: 'https://invalid.example',
          turnId: 'manual-$manual', latestUserText: '就是在逗你', recent: [prior]);
        expect(result.active, manual == 'on'); expect(result.referenceActive, isFalse);
        expect(result.playfulInteraction, PlayfulInteraction.mutual); expect(calls, 1);
        final replay = await router.decide(apiKey: 'unused', endpoint: 'https://invalid.example',
          turnId: 'manual-$manual', latestUserText: '就是在逗你', recent: [prior]);
        expect(replay.playfulInteraction, PlayfulInteraction.mutual); expect(calls, 1);
      });
    }
    Future<GenerationJob> prepare() async {
      await db.setSetting(PlayfulFormState.settingKey, const PlayfulFormState(heat: 50).encode());
      final pending = await db.createGenerationTurn(user: ChatMessage(id: 'u', role: 'user', content: '开玩笑', createdAt: now),
        assistantMessageId: 'a', model: 'deepseek-flash', reasoningEffort: 'high');
      final claimed = (await db.claimGenerationJob(pending.id))!;
      await PlayfulFormStore(db).onTurn(interaction: PlayfulInteraction.mutual, turn: 'u', now: now);
      return claimed;
    }
    Future<bool> commit(GenerationJob job, {PlayfulSelfActivity self = PlayfulSelfActivity.playful}) =>
      db.completeGenerationJobIfCurrent(jobId: job.id, runToken: job.runToken,
        assistant: ChatMessage(id: 'a', role: 'assistant', content: '回嘴', createdAt: now), playfulActivity: self);
    test('reply commit writes heat exactly once', () async {
      final job = await prepare(); expect(await commit(job), isTrue);
      expect((await PlayfulFormStore(db).load()).heat, 83);
      expect(await commit(job), isTrue); expect((await PlayfulFormStore(db).load()).heat, 83);
      expect((await PlayfulFormStore(db).load()).pendingTurn, isFalse);
    });
    test('heat write failure rolls back reply and job completion', () async {
      final job = await prepare(); final sql = await db.database;
      await sql.execute("CREATE TRIGGER fail_heat BEFORE INSERT ON settings WHEN NEW.key = 'playful_last_settlement_v2' BEGIN SELECT RAISE(ABORT, 'test'); END");
      await expectLater(commit(job), throwsA(anything));
      expect(await db.messageById('a'), isNull);
      expect((await db.generationJobById(job.id))!.status, 'running');
      expect((await PlayfulFormStore(db).load()).heat, 50);
    });
    test('Stop wins against late candidate', () async {
      final job = await prepare(); expect(await db.cancelGenerationJobByUser(job.id), isTrue);
      expect(await commit(job), isFalse); expect((await PlayfulFormStore(db).load()).heat, 50);
    });
    test('regeneration replaces old settlement', () async {
      final job = await prepare(); await commit(job);
      final reopened = await db.restartLatestCompletedReply('a'); expect(reopened, isNotNull);
      expect((await PlayfulFormStore(db).load()).heat, 50);
      final retry = (await db.claimGenerationJob(reopened!.id))!;
      await PlayfulFormStore(db).onTurn(interaction: PlayfulInteraction.mutual, turn: 'u', now: now);
      await commit(retry, self: PlayfulSelfActivity.settle);
      expect((await PlayfulFormStore(db).load()).heat, 72);
    });
    test('regeneration preserves the form locked after a transformation', () async {
      final job = await prepare();
      await db.setSetting(PlayfulFormState.settingKey,
        const PlayfulFormState(heat: 100).advance(PlayfulInteraction.strong, 'u', now).encode());
      await commit(job);
      expect((await PlayfulFormStore(db).load()).qForm, isTrue);
      await PlayfulFormStore(db).lock(true);
      await db.restartLatestCompletedReply('a');
      final restored = await PlayfulFormStore(db).load();
      expect(restored.qForm, isTrue); expect(restored.locked, isTrue);
      expect(restored.heat, 100);
    });
    test('regeneration cannot undo a newer manual form selection', () async {
      final job = await prepare(); await commit(job); await PlayfulFormStore(db).interact(false);
      await db.restartLatestCompletedReply('a'); expect((await PlayfulFormStore(db).load()).heat, 0);
    });
    test('accepted incomplete reply settles at same commit boundary', () async {
      final job = await prepare();
      await db.holdGenerationJobForUserDecision(job.id, runToken: job.runToken, partialReasoning: '', partialContent: '保留的回嘴');
      final claimed = (await db.claimGenerationDraftForConfirmation(job.id))!; await commit(claimed);
      expect((await PlayfulFormStore(db).load()).heat, 83);
      expect((await PlayfulFormStore(db).load()).pendingTurn, isFalse);
    });
  });
}
