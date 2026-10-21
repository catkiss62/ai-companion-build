import 'package:ai_companion_localfirst/core/ai/final_reply_control.dart';
import 'support/cedar_task_fixture.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/agent/turn_execution_store.dart';
import 'package:ai_companion_localfirst/core/agent/turn_task_intent.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';
import 'package:ai_companion_localfirst/core/ai/playful_self_judge.dart';
import 'package:ai_companion_localfirst/core/ai/durable_generation_runner.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_timed_play_task.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_client.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_http_client.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override Future<String?> getApplicationSupportPath() async => path;
  @override Future<String?> getTemporaryPath() async => path;
}

http.Response _sse(String content) => http.Response.bytes(utf8.encode(
  'data: ${jsonEncode({'choices': [{'delta': {'content': content}, 'finish_reason': 'stop'}]})}\n\ndata: [DONE]\n\n'),
  200, headers: {'content-type': 'text/event-stream; charset=utf-8'});

http.Response _toolSse(String name, Map<String, Object?> args, int round) => http.Response.bytes(
  utf8.encode('data: ${jsonEncode({'choices': [{'delta': {'tool_calls': [{'index': 0,
    'id': 'call-$round', 'type': 'function', 'function': {'name': name, 'arguments': jsonEncode(args)}}]},
    'finish_reason': 'tool_calls'}]})}\n\ndata: [DONE]\n\n'), 200,
  headers: {'content-type': 'text/event-stream; charset=utf-8'});

// Only the semantic decision and model prose are deterministic test inputs.
// Every planner gate, original attempt, local tool, goal receipt, message
// transaction and post-commit acknowledgement below is production code.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  for (final scenario in ['timed_no_call', 'negated_pause', 'pause_target', 'wrong_target', 'unrelated_terminal', 'timed_report', 'unrelated_report']) {
    test('real ordinary runner respects goals/target/delivery: $scenario', () async {
      final files = await Directory.systemTemp.createTemp('turn-goal-runner-');
      final originalPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(files.path);
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'test',
        'cedar_toy_token': 'ctai_v1_test', 'chat_api_provider': 'deepseek'});
      final secure = SecureConfig.forTesting(const FlutterSecureStorage());
      final cancellation = GenerationCancellationToken();
      var plans = 0;
      var finalContainsMissingGoal = false;
      final client = DeepSeekClient(streamClientFactory: () => MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        if ((body['tools'] as List?)?.isNotEmpty == true) {
          plans++;
          return _sse('「我可以陪你。」');
        }
        final prompt = jsonEncode(body['messages']);
        if (prompt.contains('本轮仍未获得执行证据的目标')) finalContainsMissingGoal = true;
        if (prompt.contains('Classify only the actual ASSISTANT_REPLY')) return _sse('{}');
        return _sse(scenario == 'timed_no_call' ? '「这次还没把定时任务登记好，暂时没有开始计时。」'
          : scenario == 'pause_target' ? '「已经暂停这局了。」'
          : scenario == 'timed_report' ? '「白色房间的二十分钟任务已经结束，累计玩了二十分钟。」' : '「嗯，我们聊聊今天的晚饭。」');
      }), jsonClientFactory: () => MockClient((_) async => http.Response(
        jsonEncode({'choices': [{'message': {'content': '{}'}}]}), 200)));
      try {
        await db.setSetting('cedar_toy_enabled', '1');
        await db.setSetting('cedar_toy_autonomy_enabled', '1');
        final activity = CedarToyActivityStore(db);
        await activity.saveCatalog('white_room·白色房间，单人游戏·tester\nforest·森林，单人游戏·tester');
        final original = await activity.recordGuide(gameId: 'white_room', guide: '单人白色房间，cmd操作。');
        if (scenario == 'wrong_target') {
          await activity.recordGuide(gameId: 'forest', guide: '单人森林，cmd操作。');
        }
        if (scenario == 'unrelated_terminal') {
          await activity.recordPlay(gameId: 'white_room', action: 'finish',
            outcome: const McpToolOutcome(content: [McpContentBlock(kind: McpContentKind.text,
              text: '真实终局：已找到白门并通关。')], isError: false,
              structuredContent: {'status': 'finished', 'winner': 'companion'}),
            mode: CedarParticipationMode.solo, nextActor: 'finished',
            shareLevel: 'required', invitationApproved: false);
          expect((await activity.load())!.hasPendingTerminalDelivery, isTrue);
        }
        if (scenario.endsWith('_report')) {
          await CedarTimedPlayTaskStore(db).finish({'id': 'saved-task', 'turnId': 'old-turn',
            'gameId': original.gameId, 'sessionId': original.id, 'title': '白色房间', 'minutes': 20,
            'requestedAt': DateTime.now().subtract(const Duration(minutes: 20)).millisecondsSinceEpoch},
            usedMs: 1200000, reason: 'budget_complete', now: DateTime.now());
          expect(await CedarTimedPlayTaskStore(db).pendingReports(), hasLength(1));
        }
        final text = switch (scenario) {
          'timed_no_call' => '现在去白色房间玩20分钟',
          'timed_report' => '之前白色房间的二十分钟任务结果怎么样？',
          'negated_pause' => '不要暂停游戏，我们只是讨论暂停按钮。',
          'pause_target' || 'wrong_target' => '现在把白色房间暂停一下，回来再继续。',
          _ => '晚饭吃什么好呢？',
        };
        final intent = switch (scenario) {
          'timed_report' => TurnTaskIntent(available: true, gameAction: 'report', gameId: original.gameId),
          'timed_no_call' => TurnTaskIntent(available: true, gameAction: 'play',
            gameId: original.gameId, sessionId: original.id, durationText: '20分钟', minutes: 20),
          'pause_target' || 'wrong_target' => TurnTaskIntent(available: true, gameAction: 'pause',
            gameId: original.gameId, sessionId: original.id),
          _ => const TurnTaskIntent(available: true),
        };
        await db.tryAcquireLocalLease('chat_turn_lease');
        final job = await db.createGenerationTurn(user: ChatMessage(id: 'user', role: 'user',
          content: text, createdAt: DateTime.now()), assistantMessageId: 'reply',
          model: 'deepseek-flash', reasoningEffort: 'high');
        final source = (await ConversationSourceStore.captureMessage(await db.database, 'user'))!;
        final sourceKey = '${source.contentHash}:${source.revision}';
        await db.setSetting('nsfw_route_turn_id', 'user');
        await db.setSetting('nsfw_route_source_key_v2', sourceKey);
        await db.setSetting('cedar_route_intent_v1', scenario == 'timed_no_call' ? 'act_now' : 'chat');
        await db.setSetting('route_task_intent_v1', jsonEncode({
          'turn_id': 'user', 'source_key': sourceKey, 'intent': intent.toJson()}));
        final judge = PlayfulSelfJudge(client: client, jevGateway: JevDecisionGateway(
          enabledReader: () async => true, keyReader: () async => 'test',
          clientFactory: () => MockClient((request) async {
            final sent = jsonDecode(request.body) as Map;
            final questions = (sent['questions'] as Map).keys.cast<String>();
            if (scenario == 'timed_report') {
              expect(questions, contains('delivery_0'));
              expect((sent['state'] as Map)['delivery_reply_full'], contains('累计玩了二十分钟'));
            } else if (scenario == 'unrelated_report' || scenario == 'unrelated_terminal') {
              expect(questions.any((q) => q.startsWith('delivery_')), isFalse);
            }
            return http.Response(jsonEncode({'answers': {for (final q in questions) q: {
              'type': 'choice', 'choice': q == 'route' ? 'none' : 'yes', 'confidence': .99,
              'probabilities': {q == 'route' ? 'none' : 'yes': .99}}}}), 200);
          })));
        final result = await DurableGenerationRunner(db: db, client: client, secureConfig: secure, selfJudge: judge)
          .run(job, cancellationToken: cancellation).timeout(const Duration(seconds: 20));
        expect(result.status, 'completed', reason: '${result.error}');
        expect(await db.messageById('reply'), isNotNull);
        final state = await activity.loadState();
        switch (scenario) {
          case 'timed_no_call':
            expect(plans, 2); // one bounded reconsideration, then grounded prose
            expect(finalContainsMissingGoal, isTrue);
            expect(await CedarTimedPlayTaskStore(db).active(), isNull);
            expect(await TurnExecutionStore(db).readEffect('user', TurnEffectSlot.cedarTimedRegistration), isNull);
            break;
          case 'pause_target':
            expect(state.sessions['white_room']!.phase, CedarActivityPhase.paused);
            expect((await TurnExecutionStore(db).readEffect('user', TurnEffectSlot.cedarControl))!.committed, isTrue);
            break;
          case 'wrong_target':
            expect(state.activeGameId, 'forest');
            expect(state.sessions['forest']!.phase, isNot(CedarActivityPhase.paused));
            expect(await TurnExecutionStore(db).readEffect('user', TurnEffectSlot.cedarControl), isNull);
            break;
          case 'negated_pause':
            expect(state.sessions['white_room']!.phase, isNot(CedarActivityPhase.paused));
            expect(await TurnExecutionStore(db).readEffect('user', TurnEffectSlot.cedarControl), isNull);
            break;
          case 'timed_report':
            expect(await CedarTimedPlayTaskStore(db).pendingReports(), isEmpty);
            break;
          case 'unrelated_report':
            expect(await CedarTimedPlayTaskStore(db).pendingReports(), hasLength(1));
            break;
          default:
            final session = state.sessions['white_room']!;
            expect(session.hasPendingTerminalDelivery, isTrue);
            expect(await TurnExecutionStore.readDeliveryInTransaction(await db.database,
              CedarToyActivityStore.terminalClaim(session)), isNull);
        }
      } finally {
        cancellation.cancel();
        client.close();
        await db.releaseLocalLease('chat_turn_lease');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await db.closeForTesting();
        PathProviderPlatform.instance = originalPaths;
        await files.delete(recursive: true);
      }
    });
  }
  for (final variant in ['play_no_timer', 'play_then_timer', 'missing_duration', 'missing_duration_then_timer', 'resume_timer', 'resume_then_pause', 'play_then_timer_manual']) {
    final manual = variant.endsWith('_manual');
    final scenario = manual ? 'play_then_timer' : variant;
    final replyControl = FinalReplyControl();
    test('production planner and MCP preserve timed goal: $variant', () async {
      final files = await Directory.systemTemp.createTemp('cedar-real-turn-');
      final originalPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(files.path);
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'test',
        'cedar_toy_token': 'ctai_v1_test',
        'chat_api_provider': manual ? 'aiwangyou_gemini' : 'deepseek',
        'aiwangyou_gemini_api_key': 'test-second',
        'aiwangyou_final_reply_endpoint': 'https://relay.invalid/v1/chat/completions'});
      final secure = SecureConfig.forTesting(const FlutterSecureStorage());
      final cancellation = GenerationCancellationToken();
      final activity = CedarToyActivityStore(db);
      final resumes = scenario.startsWith('resume');
      final succeeds = scenario == 'play_then_timer' || scenario == 'resume_timer' || scenario == 'missing_duration_then_timer';
      var plans = 0;
      var playCalls = 0;
      var finalHasMissingTimer = false;
      final mcp = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        if (body['method'] == 'notifications/initialized') return http.Response('{}', 202);
        if (body['method'] == 'initialize') return http.Response(jsonEncode({
          'jsonrpc': '2.0', 'id': body['id'], 'result': <String, Object?>{}}), 200);
        expect(body['method'], 'tools/call');
        final params = body['params'] as Map;
        expect(params['name'], 'play');
        expect((params['arguments'] as Map)['game'], 'fishing');
        expect((params['arguments'] as Map)['action'], 'cast');
        playCalls++;
        final outcome = {'status': 'playing', 'next_actor': 'companion', 'result': '真实钓到一条鱼。'};
        return http.Response.bytes(utf8.encode(jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': {
          'isError': false, 'structuredContent': outcome,
          'content': [{'type': 'text', 'text': jsonEncode(outcome)}]}})), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final client = DeepSeekClient(streamClientFactory: () => MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        if (request.url.host == 'relay.invalid') {
          expect(playCalls, 1); // External MCP write already completed.
          replyControl.requestDeepSeek();
          return _sse('迟到的第二通道');
        }
        if ((body['tools'] as List?)?.isNotEmpty == true) {
          plans++;
          if (!resumes && plans == 1) return _toolSse('cedar_toy_play', {
            'game': 'fishing', 'action': 'cast', 'params_json': '{}',
            'participation_mode': 'solo', 'invitation_approved': false}, plans);
          if (scenario == 'resume_then_pause' && plans == 1) {
            // The local semantic resume already committed; a later real UI
            // pause while the planner awaits must invalidate its old intent.
            final receipt = await TurnExecutionStore(db).readEffect('user', TurnEffectSlot.cedarControl);
            expect(receipt?.committed, isTrue);
            expect(receipt?.result['operation'], 'resume');
            await activity.pause();
          }
          if (!resumes && plans == 2) {
            final played = await activity.loadSession('fishing');
            final outcomes = await db.recentAgentToolOutcomeRecords(limit: 8);
            final diagnostic = outcomes.map((o) => '${o.toolId}:${o.status.name}:${o.displayText}').join(', ');
            expect(outcomes.where((o) => o.toolId == 'cedar_toy.play' && o.status.name == 'succeeded'), hasLength(1),
              reason: diagnostic);
            expect(played?.lastAction, 'cast', reason: diagnostic);
            expect(played?.lastOutcome, contains('真实钓到一条鱼'), reason: diagnostic);
          }
          if ((succeeds && plans == (resumes ? 1 : 2)) ||
              (scenario == 'resume_then_pause' && plans == 1)) {
            final names = (body['tools'] as List).map((t) => ((t as Map)['function'] as Map)['name']);
            expect(names, contains('cedar_toy_start_timed_play'));
            if (!resumes) expect(names, isNot(contains('cedar_toy_play')));
            return _toolSse('cedar_toy_start_timed_play', {'game': 'fishing', 'duration_text': '20分钟'}, plans);
          }
          return _sse('「我会继续看看。」'); // Deliberately omits required registration.
        }
        final prompt = jsonEncode(body['messages']);
        if (prompt.contains('本轮仍未获得执行证据的目标') &&
            (prompt.contains('20 分钟') || prompt.contains('确认持续游玩时长'))) finalHasMissingTimer = true;
        if (prompt.contains('Classify only the actual ASSISTANT_REPLY')) return _sse('{}');
        return _sse(succeeds ? '「那我接着玩二十分钟，结束后告诉你。」'
          : scenario == 'play_no_timer' ? '「已经登记好了，现在开始计时二十分钟。」'
          : '「这次还没有登记定时任务，所以没有开始计时。」');
      }), jsonClientFactory: () => MockClient((_) async => http.Response(jsonEncode({
        'choices': [{'message': {'content': jsonEncode({'next_actor': 'companion',
          'share_level': 'quiet', 'resume_after_seconds': 0})}}]}), 200)));
      try {
        await db.setSetting('cedar_toy_enabled', '1');
        await db.setSetting('cedar_toy_autonomy_enabled', '1');
        await activity.saveCatalog('fishing·钓鱼，单人游戏·tester');
        await activity.savePlayProtocol('play(game, action, params).');
        final session = await activity.recordGuide(gameId: 'fishing', guide: '单人钓鱼。cast 动作抛竿，没有必填参数。');
        if (resumes) {
          await activity.recordPlay(gameId: 'fishing', action: 'cast',
            outcome: const McpToolOutcome(content: [McpContentBlock(kind: McpContentKind.text,
              text: '已钓到鱼，可以继续。')], isError: false,
              structuredContent: {'status': 'playing', 'next_actor': 'companion'}),
            mode: CedarParticipationMode.solo, nextActor: 'companion', shareLevel: 'quiet', invitationApproved: false);
          await activity.pause();
        }
        final userText = resumes ? '恢复钓鱼游戏，再玩20分钟。' : '现在去钓鱼玩20分钟。';
        final intent = scenario.startsWith('missing_duration')
          ? TurnTaskQuestionSet(userText: userText, state: await activity.loadState(), works: const [])
              .interpret({'task_game': 'play', 'task_game_target': 'g0', 'task_creative': 'none'})
          : TurnTaskIntent(available: true, gameAction: resumes ? 'resume' : 'play',
              gameId: 'fishing', sessionId: session.id, durationText: '20分钟', minutes: 20);
        if (scenario.startsWith('missing_duration')) expect(intent.durationResolved, isFalse);
        await db.tryAcquireLocalLease('chat_turn_lease');
        final job = await db.createGenerationTurn(user: ChatMessage(id: 'user', role: 'user',
          content: userText, createdAt: DateTime.now()), assistantMessageId: 'reply',
          model: 'deepseek-flash', reasoningEffort: 'high');
        final source = (await ConversationSourceStore.captureMessage(await db.database, 'user'))!;
        final sourceKey = '${source.contentHash}:${source.revision}';
        await db.setSetting('nsfw_route_turn_id', 'user');
        await db.setSetting('nsfw_route_source_key_v2', sourceKey);
        await db.setSetting('cedar_route_intent_v1', 'act_now');
        await db.setSetting('route_task_intent_v1', jsonEncode({
          'turn_id': 'user', 'source_key': sourceKey, 'intent': intent.toJson()}));
        final result = await DurableGenerationRunner(db: db, client: client, secureConfig: secure,
          cedarClientFactory: (token) => CedarToyClient(token: token,
            transport: McpHttpClient(endpoint: Uri.parse('https://example.invalid/mcp'), client: mcp)))
          .run(job, cancellationToken: cancellation, replyControl: replyControl).timeout(const Duration(seconds: 20));
        expect(result.status, 'completed', reason: '${result.error}');
        expect(await db.messageById('reply'), isNotNull);
        if (manual) {
          expect(result.assistant!.model, 'deepseek-flash');
          expect(result.notice, contains('按你的选择'));
        }
        expect(playCalls, resumes ? 0 : 1); // Never perform a second foreground write to fill a timer goal.
        if (!resumes) expect((await activity.loadSession('fishing'))!.lastAction, 'cast');
        final receipt = await TurnExecutionStore(db).readEffect('user', TurnEffectSlot.cedarTimedRegistration);
        if (succeeds) {
          expect(result.notice ?? '', isNot(contains('本轮定时任务未登记')));
          expect(receipt?.committed, isTrue);
          expect(receipt?.messageId, 'reply');
          expect((await CedarTimedPlayTaskStore(db).active())?['minutes'], 20);
          expect(plans, resumes ? 1 : 2);
        } else {
          expect(finalHasMissingTimer, isTrue);
          if (scenario == 'play_no_timer') {
            // Even deliberately false model prose cannot hide the app's real status.
            expect(result.assistant!.content, contains('开始计时'));
            expect(result.notice, contains('本轮定时任务未登记，尚未开始计时。'));
          }
          expect(receipt, isNull);
          expect(await CedarTimedPlayTaskStore(db).active(), isNull);
          expect(plans, inInclusiveRange(2, 4)); // One bounded reconsideration then truthful prose.
          if (scenario == 'resume_then_pause') {
            expect((await activity.loadSession('fishing'))!.phase, CedarActivityPhase.paused);
          }
        }
      } finally {
        cancellation.cancel();
        client.close();
        mcp.close();
        await db.releaseLocalLease('chat_turn_lease');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await db.closeForTesting();
        PathProviderPlatform.instance = originalPaths;
        await files.delete(recursive: true);
      }
    });
  }
  for (final scenario in ['valid', 'paused', 'cancel_during_judge']) {
    test('production draft confirmation hands off timer only for winning attempt: $scenario', () async {
      final files = await Directory.systemTemp.createTemp('timed-confirm-runner-');
      final originalPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(files.path);
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'test'});
      final secure = SecureConfig.forTesting(const FlutterSecureStorage());
      final cancellation = GenerationCancellationToken();
      final judgeStarted = Completer<void>();
      final releaseJudge = Completer<http.Response>();
      final client = DeepSeekClient(streamClientFactory: () => MockClient((request) async {
        if (scenario == 'cancel_during_judge') {
          if (!judgeStarted.isCompleted) judgeStarted.complete();
          return releaseJudge.future;
        }
        return _sse('{}');
      }), jsonClientFactory: () => MockClient((_) async => http.Response(
        jsonEncode({'choices': [{'message': {'content': '{}'}}]}), 200)));
      Future<GenerationRunResult>? running;
      try {
        await db.setSetting('cedar_toy_enabled', '1');
        await db.setSetting('cedar_toy_autonomy_enabled', '1');
        final activity = CedarToyActivityStore(db);
        final session = await activity.recordGuide(gameId: 'white_room', guide: '单人白色房间，cmd操作。');
        final staged = await stageCedarTask(db, session: session, turnId: 'user', assistantId: 'reply', minutes: 20);
        await db.holdGenerationJobForUserDecision(staged.job.id, runToken: staged.job.runToken,
          partialReasoning: '', partialContent: '「那我先玩二十分钟，结束后告诉你。」');
        expect(await CedarTimedPlayTaskStore(db).active(), isNull);
        if (scenario == 'paused') await activity.pause();
        running = DurableGenerationRunner(db: db, client: client, secureConfig: secure)
          .confirmIncompleteDraft(staged.job.id, cancellationToken: cancellation);
        if (scenario == 'cancel_during_judge') {
          await judgeStarted.future.timeout(const Duration(seconds: 10));
          cancellation.cancel();
          releaseJudge.complete(_sse('{}'));
        }
        final result = await running.timeout(const Duration(seconds: 20));
        final timer = CedarTimedPlayTaskStore(db);
        if (scenario == 'valid') {
          expect(result.status, 'completed', reason: '${result.error}');
          expect(await db.messageById('reply'), isNotNull);
          expect((await timer.active())?['minutes'], 20);
          final receipt = (await TurnExecutionStore(db).readEffect('user', TurnEffectSlot.cedarTimedRegistration))!;
          expect(receipt.committed, isTrue);
          expect(receipt.runToken, staged.job.runToken); // Original acceptance, new commit ticket.
        } else {
          expect(result.status, scenario == 'paused' ? 'incomplete' : 'cancelled_by_user');
          expect(await db.messageById('reply'), isNull);
          expect(await timer.active(), isNull);
          expect((await TurnExecutionStore(db).readEffect('user', TurnEffectSlot.cedarTimedRegistration))?.committed, isNot(true));
        }
      } finally {
        cancellation.cancel();
        if (!releaseJudge.isCompleted) releaseJudge.complete(_sse('{}'));
        if (running != null) { try { await running.timeout(const Duration(seconds: 3)); } catch (_) {} }
        client.close();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await db.closeForTesting();
        PathProviderPlatform.instance = originalPaths;
        await files.delete(recursive: true);
      }
    });
  }

}
