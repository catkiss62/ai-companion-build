import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_execution_repair.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_game_protocol.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_live_share_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_timed_play_task.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_client.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'support/cedar_task_fixture.dart';

class _Game extends CedarToyClient {
  _Game() : super(token: 'ctai_v1_fixture');
  final actions = <String>[];
  @override Future<McpToolOutcome> play(String game, String action, Map<String, Object?> params,
    {GenerationCancellationToken? cancellationToken}) async {
    final command = params['command'] as String; actions.add(command);
    return McpToolOutcome(isError: command != 'help', content: [McpContentBlock(kind: McpContentKind.text,
      text: command == 'help' ? '用真实酒单选择可用标识。' : '这杯目前调不出来。用 drinks 查看现有酒单。')], structuredContent:command=='help'?{'next_actor':'companion'}:null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit();
  const channel = MethodChannel('ai_companion/system');
  late AppDatabase db; late CedarToyActivityStore store;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,
      (call) async => call.method == 'runtimeProcessEpoch' ? 'execution-fixture' : null);
    db = await AppDatabase.createForTesting(databaseFactoryFfi); store = CedarToyActivityStore(db);
  });
  tearDown(() async { await db.closeForTesting(); TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null); });
  Future<CedarGameSession> step(String command, String result, {bool error = false, bool notable = false}) => store.recordPlay(
    gameId: 'bar', action: 'cmd', submittedParams: {'command': command, 'slot': 1},
    outcome: McpToolOutcome(isError: error, content: [McpContentBlock(kind: McpContentKind.text, text: result)]),
    mode: CedarParticipationMode.solo, nextActor: 'companion', shareLevel: notable ? 'notable' : 'quiet', invitationApproved: false);
  Future<CedarGameSession> start() => store.recordGuide(gameId: 'bar', guide: '单人游戏。action="cmd"，params={"command":"...","slot":1}。help 帮助，drinks 酒单，serve 出杯。');

  test('service envelope no-op and rejected parameters cannot count as progress', () async {
    expect(CedarActionFeedback.noProgress('还有客人在等酒。\n[MCP_STRUCTURED_CONTENT]\n{"next_actor":"companion"}'),true);
    await start();
    await step('next', jsonEncode({'game': 'bar', 'text': '还有客人在等酒：某位客人。可以 serve、cheers 或 decline。'}));
    await step('drinks', 'pour:sun_mead　日轮蜂蜜酒');
    await step('serve peer missing', jsonEncode({'text': '这杯目前调不出来。用 drinks 查看现有酒单。'}));
    expect((await store.loadState()).completedPlayRounds, 0);
    await step('serve peer pour:sun_mead', '客人喝到了酒，资金增加。');
    expect((await store.loadState()).completedPlayRounds, 1);
  });

  test('prefix correction uses server identifiers, without forbidding creative text', () async {
    await start(); final session = await step('drinks', jsonEncode({'text': 'pour:star_sparkling　星屑起泡酒\naviation　航空'}));
    expect(CedarExecutionRepair.issue(session, 'cmd', {'command': 'serve peer star_sparkling'}), contains('pour:star_sparkling'));
    expect(CedarExecutionRepair.issue(session, 'cmd', {'command': 'serve peer aviation'}), '');
    expect(CedarExecutionRepair.issue(session, 'cmd', {'command': 'invent gin floral "新酒名"'}), '');
    expect(CedarExecutionRepair.prompt(session), contains('pour:star_sparkling'));
  });

  test('two parameter errors require a fresh query; NPC refusal is not a parameter error', () async {
    await start(); await step('serve peer wrong', '这杯目前调不出来。', error: true);
    var session = await step('serve peer wrong2', '这杯目前调不出来。', error: true);
    expect(CedarExecutionRepair.issue(session, 'cmd', {'command': 'serve peer wrong3'}), contains('先按完整指南读取'));
    session = await step('help', '真实帮助');
    expect(CedarExecutionRepair.issue(session, 'cmd', {'command': 'serve peer corrected'}), '');
    expect(CedarActionFeedback.parameterError('🥃 推荐一杯酒\n客人尚未购买，库存与资金都没有变化。'), false);
    session = await step('serve peer corrected', '确实已经出杯');
    expect(CedarExecutionRepair.parameterFailures(session), isEmpty);
  });

  test('timed notable progress can be shared after the matching time window below five rounds', () async {
    final initial = await start(); final tasks = CedarTimedPlayTaskStore(db);
    final at = DateTime.now().subtract(const Duration(minutes: 12));
    final registration = await stageCedarTask(db, session: initial, turnId: 'timed', assistantId: 'accepted', minutes: 30, now: at);
    expect(await commitCedarTask(db, registration), true); await tasks.activateCommitted(now: at);
    final session = await step('serve peer aviation', '第一次给客人调出航空，客人说很喜欢。', notable: true);
    final sharing = CedarLiveSharePolicy(db);
    expect((await store.loadState()).completedPlayRounds, 1);
    await sharing.offer(session, share: false, now: DateTime.now());
    expect(await store.pendingDirectShares(), hasLength(1));
    await sharing.offer(session, share: true, now: DateTime.now());
    expect(await store.pendingDirectShares(), hasLength(1));
    await db.setSetting('cedar_toy_game_share_enabled', '0');
    expect(await sharing.deliveryAllowed((await store.pendingDirectShares()).single, 'mcp/cedar_game:bar:event'), false);
  });

  test('three same-category parameter failures stop a committed task after a real help query', () async {
    final initial = await start(); final tasks = CedarTimedPlayTaskStore(db);
    final registration = await stageCedarTask(db, session: initial, turnId: 'failure-task', assistantId: 'failure-accepted', minutes: 30);
    expect(await commitCedarTask(db, registration), true); await tasks.activateCommitted();
    final game = _Game();
    final ai = DeepSeekClient(streamClientFactory: () => MockClient((request) async {
      final command = game.actions.length == 2 ? 'help' : 'serve peer nonexistent';
      final event = {'choices': [{'delta': {'tool_calls': [{'index': 0, 'id': 'step', 'type': 'function', 'function': {
        'name': 'cedar_toy_play', 'arguments': jsonEncode({'game': 'bar', 'action': 'cmd', 'params_json': jsonEncode({'command': command, 'slot': 1}),
          'participation_mode': 'solo', 'invitation_approved': false, 'share_previous_outcome': false})}}]}, 'finish_reason': 'tool_calls'}]};
      return http.Response('data: ${jsonEncode(event)}\n\ndata: [DONE]\n\n', 200, headers: {'content-type': 'text/event-stream'});
    }));
    final engine = CedarToyAutonomyEngine(db: db, ai: ai, secureConfig: SecureConfig.instance, tokenReader: () async => 'fixture',
      apiKeyReader: () async => 'fixture', endpointReader: () async => DeepSeekClient.defaultEndpoint, clientFactory: (_) => game);
    try {
      for (var i = 0; i < 4; i++) {
        await store.deferContinuation(gameId: 'bar', delay: Duration.zero, now: DateTime.now().subtract(const Duration(seconds: 1)));
        await engine.continueDue(now: DateTime.now());
      }
      expect(game.actions, ['serve peer nonexistent', 'serve peer nonexistent', 'help', 'serve peer nonexistent']);
      expect(await tasks.active(), isNull);
      expect((await tasks.pendingReports()).single['reason'], 'blocked_invalid_parameters');
      expect((await tasks.pendingReports()).single['progressCount'], 0);
      await engine.continueDue(now: DateTime.now()); expect(game.actions, hasLength(4));
    } finally { ai.close(); }
  });
}
