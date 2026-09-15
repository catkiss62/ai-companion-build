import 'package:ai_companion_localfirst/core/agent/agent_participation_consent.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_agent_loop_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_game_protocol.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_arcade_skill.dart';
import 'package:flutter_test/flutter_test.dart';

AgentToolResult _cedarResult(
  String toolId, {
  bool continuation = false,
  AgentToolStatus status = AgentToolStatus.succeeded,
}) =>
    AgentToolResult(
      toolId: toolId,
      status: status,
      displayText: toolId,
      promptData: toolId,
      continuationRecommended: continuation,
    );

void main() {
  test('one user goal stays open through discovery and room creation', () {
    // The old runner stopped after one of these stages. The unified contract
    // must keep the same user goal alive until a real play hands off control.
    final scriptedRounds = <List<AgentToolResult>>[
      <AgentToolResult>[
        _cedarResult('cedar_toy.list_games', continuation: true),
      ],
      <AgentToolResult>[
        _cedarResult('cedar_toy.get_guide', continuation: true),
      ],
      <AgentToolResult>[
        _cedarResult('cedar_toy.play', continuation: true),
      ],
      <AgentToolResult>[
        _cedarResult('cedar_toy.play'),
      ],
    ];

    final decisions = scriptedRounds
        .map(
          (results) => CedarAgentLoopPolicy.shouldFinalizeRound(
            results: results,
            proposalExecuted: false,
            commitPendingMedia: false,
            loopLimitReached: false,
          ),
        )
        .toList(growable: false);

    expect(decisions, <bool>[false, false, false, true]);
    expect(CedarPlatformActionPolicy.continuesPlanning('list_games'), isTrue);
    expect(CedarPlatformActionPolicy.continuesPlanning('get_guide'), isTrue);
  });

  test('recoverable validation result does not terminate the Agent turn', () {
    expect(
      CedarAgentLoopPolicy.shouldFinalizeRound(
        results: <AgentToolResult>[
          _cedarResult(
            'cedar_toy.play',
            continuation: true,
            status: AgentToolStatus.blocked,
          ),
        ],
        proposalExecuted: false,
        commitPendingMedia: false,
        loopLimitReached: false,
      ),
      isFalse,
    );
  });

  test('explicit Cedar request gets one bounded no-call recovery', () {
    expect(
      CedarAgentLoopPolicy.shouldRetryInitialNoCall(
        cedarRequested: true,
        retryUsed: false,
        remainingCalls: 8,
      ),
      isTrue,
    );
    expect(
      CedarAgentLoopPolicy.shouldRetryInitialNoCall(
        cedarRequested: true,
        retryUsed: true,
        remainingCalls: 8,
      ),
      isFalse,
    );
  });

  test('server next_call keeps an established room alive without local labels',
      () {
    expect(
      CedarServerContinuationPolicy.authorizesExactAction(
        action: 'state',
        continuationAction: 'state',
      ),
      isTrue,
    );
    expect(
      CedarServerContinuationPolicy.authorizesExactAction(
        action: 'move',
        continuationAction: 'state',
      ),
      isFalse,
    );
    expect(
      CedarServerContinuationPolicy.canObserve(
        guideComplete: true,
        phaseContinuable: true,
        paused: false,
        hasContinuationCall: true,
        nextActor: 'user',
      ),
      isTrue,
    );
    expect(
      CedarServerContinuationPolicy.usesRealtimePace(
        hasContinuationCall: true,
        hasPendingRoomMessage: false,
        companionTurn: false,
      ),
      isTrue,
    );
    expect(
      CedarServerContinuationPolicy.needsUserTurnTools(
        guideReady: false,
        awaitingInvitation: false,
        waitingUser: false,
        hasContinuationCall: true,
        participationActive: false,
      ),
      isTrue,
    );
  });

  test('remote wait without a continuation route cannot pin the arcade', () {
    CedarGameSession waiting({
      String continuationAction = '',
      DateTime? nextActionAt,
    }) =>
        CedarGameSession(
          id: 'session',
          gameId: 'garden_cat',
          guide: 'complete guide',
          guideComplete: true,
          mode: CedarParticipationMode.solo,
          phase: CedarActivityPhase.waitingRemote,
          updatedAt: DateTime.utc(2026, 9, 15),
          nextActor: 'wait',
          continuationAction: continuationAction,
          nextActionAt: nextActionAt,
        );

    expect(waiting().isUnroutableRemoteWait, isTrue);
    expect(
      waiting(continuationAction: 'state').isUnroutableRemoteWait,
      isFalse,
    );
    expect(
      waiting(nextActionAt: DateTime.utc(2026, 9, 15, 1))
          .isUnroutableRemoteWait,
      isFalse,
    );
  });

  test('normal request grants the requested shared-game authority', () {
    expect(
      AgentParticipationConsentPolicy.explicitlyGranted('我们下棋，你建房，我加入'),
      isTrue,
    );
    expect(
      AgentParticipationConsentPolicy.explicitlyGranted('陪我下一局五子棋'),
      isTrue,
    );
    expect(
      AgentParticipationConsentPolicy.explicitlyGranted('暂时不玩，我们下次再下棋'),
      isFalse,
    );
    expect(CedarToyArcadeSkill.isRelevant('陪我下一局五子棋'), isTrue);
    expect(CedarToyArcadeSkill.isRelevant('帮我开一把伞'), isFalse);
  });
}
