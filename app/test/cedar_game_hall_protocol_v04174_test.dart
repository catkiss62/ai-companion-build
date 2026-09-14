import 'package:ai_companion_localfirst/core/agent/agent_tool_planner.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_registry.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_game_protocol.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_turn_state_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hybrid can start solo while shared observation still needs consent', () {
    expect(CedarParticipationMode.hybrid.requiresInvitation, isFalse);
    expect(
      CedarParticipationMode.hybrid.supportsSharedParticipation,
      isTrue,
    );
    expect(CedarParticipationMode.multiplayer.requiresInvitation, isTrue);

    CedarToyActivityState stateFor(
      CedarParticipationMode mode, {
      bool approved = false,
    }) =>
        CedarToyActivityState(
          activeGameId: 'game',
          sessions: <String, CedarGameSession>{
            'game': CedarGameSession(
              id: 'game',
              gameId: 'game',
              guide: 'guide',
              guideComplete: true,
              mode: mode,
              phase: CedarActivityPhase.active,
              invitationApproved: approved,
              updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
            ),
          },
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
        );
    expect(
      stateFor(CedarParticipationMode.coPlay).hasUserTurnContinuation,
      isTrue,
    );
    expect(
      stateFor(CedarParticipationMode.hybrid).hasUserTurnContinuation,
      isFalse,
    );
    expect(
      stateFor(CedarParticipationMode.hybrid, approved: true)
          .hasUserTurnContinuation,
      isTrue,
    );
  });

  test('live catalog parser returns Chinese titles without hardcoded games', () {
    const catalog = '''测试: mbti·16型人格测试，短/完整/快速·南山君 | enneagram·九型人格测试，36题A/B或180题Likert·Max Ross
小游戏: duel·双弈，25款棋牌骰对弈·南山君&Clio | fishing·钓鱼模拟，抛竿卖鱼收集图鉴·初一 | eco·文字生态模拟，造物主养池塘·南山君&Clio | garden_cat·花园与猫咪长期养成·乐诶雷女士''';

    final entries = CedarCatalogParser.parse(catalog);
    expect(entries.map((item) => item.id),
        containsAll(<String>['mbti', 'enneagram', 'duel', 'fishing', 'garden_cat']));
    expect(CedarCatalogParser.titleFor(catalog, 'duel'), '双弈');
    expect(
      CedarCatalogParser.titleFor(catalog, 'garden_cat'),
      '花园与猫咪长期养成',
    );
    expect(
      CedarToyActivityStore.catalogMentionedGameId('可以玩玩瓶中生态', catalog),
      'eco',
    );
  });

  test('Cedar platform actions are independent of a game guide', () {
    expect(CedarPlatformActionPolicy.isPlatformAction('rest'), isTrue);
    expect(CedarPlatformActionPolicy.isPlatformAction('announcements'), isTrue);
    expect(CedarPlatformActionPolicy.isPlatformAction('vote'), isTrue);
    expect(CedarPlatformActionPolicy.isPlatformAction('move'), isFalse);
    expect(CedarPlatformActionPolicy.isReadOnly('state'), isTrue);
    expect(CedarPlatformActionPolicy.isRemoteExit('resign'), isTrue);
  });

  test('duel incremental your_turn becomes authoritative companion turn', () {
    final resolved = McpTurnStateResolver.resolveStructured(<String, Object?>{
      'status': 'playing',
      'revision': 9,
      'current_actor': <String, Object?>{
        'player_id': '9171',
        'name': 'machine',
      },
      'your_turn': true,
      'slot': 1,
    });

    expect(resolved?.nextActor, 'companion');
    expect(resolved?.reason, 'structured_your_turn');
  });

  test('non-own duel turn remains observable rather than actionable', () {
    final resolved = McpTurnStateResolver.resolveStructured(<String, Object?>{
      'status': 'playing',
      'your_turn': false,
      'next_call': <String, Object?>{
        'action': 'state',
        'params': <String, Object?>{'wait': true},
      },
    });

    expect(resolved?.nextActor, 'wait');
  });

  test('strict state machine legal actions authorize companion planning', () {
    final resolved = McpTurnStateResolver.resolveStructured(<String, Object?>{
      'state': <String, Object?>{
        'phase': 'choose',
        'available_actions': <Object?>[
          <String, Object?>{'action': 'spin'},
        ],
      },
    });

    expect(resolved?.nextActor, 'companion');
    expect(resolved?.reason, 'structured_legal_actions');
  });

  test('recent game advice is bounded and survives session serialization', () {
    expect(CedarGameAdvicePolicy.isLikelyAdvice('我建议你下一手走中间'), isTrue);
    expect(CedarGameAdvicePolicy.isLikelyAdvice('今天吃什么'), isFalse);
    final restored = CedarGameSession.fromJson(
      CedarGameSession(
        id: 'duel-1',
        gameId: 'duel',
        guide: 'move and state',
        guideComplete: true,
        mode: CedarParticipationMode.multiplayer,
        phase: CedarActivityPhase.active,
        adviceNotes: const <String>['可以先守中间'],
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      ).toJson(),
    );

    expect(restored.adviceNotes, <String>['可以先守中间']);
  });

  test('temporary absence routes to local session release, not remote leave', () {
    final pause = AgentToolPlanner.routeLocally('我暂时要忙，你自己玩下别的吧');
    expect(pause?.calls.single.toolId,
        AgentToolRegistry.cedarToyManageActivity.id);
    expect(pause?.calls.single.arguments['operation'], 'pause_and_release');

    final resume = AgentToolPlanner.routeLocally('回来继续这局游戏吧');
    expect(resume?.calls.single.toolId,
        AgentToolRegistry.cedarToyManageActivity.id);
    expect(resume?.calls.single.arguments['operation'], 'resume');
  });

  test('released paused session remains recoverable without active game', () {
    final paused = CedarGameSession(
      id: 'duel-1',
      gameId: 'duel',
      gameTitle: '双弈',
      guide: 'move and state',
      guideComplete: true,
      mode: CedarParticipationMode.multiplayer,
      phase: CedarActivityPhase.paused,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
    );
    final restored = CedarToyActivityState.fromJson(
      CedarToyActivityState(
        activeGameId: '',
        sessions: <String, CedarGameSession>{'duel': paused},
        updatedAt: DateTime.fromMillisecondsSinceEpoch(2),
      ).toJson(),
    );

    expect(restored.activeSession, isNull);
    expect(restored.sessions['duel']?.displayName, '双弈');
    expect(restored.sessions['duel']?.continuable, isTrue);
  });
}
