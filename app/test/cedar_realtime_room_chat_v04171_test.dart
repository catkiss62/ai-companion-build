import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_text_envelope.dart';
import 'package:ai_companion_localfirst/core/grounding/operational_claim_grounding_guard.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_turn_state_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nested singular room resolves the companion actor', () {
    final resolved = McpTurnStateResolver.resolveStructured(<String, Object?>{
      'status': 'playing',
      'room': <String, Object?>{
        'current_actor': <String, Object?>{
          'player_id': 'machine-2',
          'participant_kind': 'bound_machine',
        },
      },
    });

    expect(resolved?.nextActor, 'companion');
    expect(resolved?.reason, 'structured_current_actor_role');
  });

  test('server next_call becomes a typed long-poll continuation', () {
    final resolved = McpContinuationCallResolver.resolveStructured(
      <String, Object?>{
        'wait_scope': 'current_request_only',
        'next_call': <String, Object?>{
          'game': 'board_room',
          'action': 'state',
          'params': <String, Object?>{
            'room_id': 'ROOM-1',
            'wait': true,
          },
        },
      },
    );

    expect(resolved?.game, 'board_room');
    expect(resolved?.action, 'state');
    expect(resolved?.params['wait'], isTrue);
    expect(resolved?.isLongPoll, isTrue);
    expect(resolved?.waitScope, 'current_request_only');
  });

  test('public room messages distinguish the companion participant', () {
    final batch = McpRoomMessageResolver.resolveStructured(<String, Object?>{
      'room': <String, Object?>{
        'participants': <Object?>[
          <String, Object?>{
            'player_id': 'human-1',
            'display_name': 'person',
            'role': 'human',
          },
          <String, Object?>{
            'player_id': 'machine-2',
            'display_name': 'companion',
            'participant_kind': 'bound_machine',
          },
        ],
      },
      // The true Cedar bootstrap shape keeps events at the root while
      // participant identities live inside the singular room.
      'events': <Object?>[
        <String, Object?>{'name': 'person', 'message': '该你了'},
        <String, Object?>{'name': 'companion', 'message': '看招'},
      ],
    });

    expect(batch.messages, hasLength(2));
    expect(batch.messages.first.fromCompanion, isFalse);
    expect(batch.messages.last.fromCompanion, isTrue);
    expect(batch.ownAliases, contains('companion'));
  });

  test('co-play waiting session remains observable after app restart', () {
    final restored = CedarGameSession.fromJson(
      CedarGameSession(
        id: 'session-1',
        gameId: 'board_room',
        guide: 'state supports wait and message',
        guideComplete: true,
        mode: CedarParticipationMode.coPlay,
        phase: CedarActivityPhase.waitingUser,
        nextActor: 'user',
        invitationApproved: true,
        continuationAction: 'state',
        continuationParamsJson: '{"room_id":"ROOM-1","wait":true}',
        continuationWaitScope: 'current_request_only',
        pendingRoomMessage: 'person：该你了',
        seenRoomMessageKeys: const <String>['room-1'],
        ownRoomAliases: const <String>['companion'],
        nextActionAt: DateTime.fromMillisecondsSinceEpoch(2000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
      ).toJson(),
    );

    expect(restored.companionCanContinue, isFalse);
    expect(restored.companionCanObserve, isTrue);
    expect(restored.needsContinuation, isTrue);
    expect(restored.pendingRoomMessage, contains('该你了'));
    expect(restored.ownRoomAliases, contains('companion'));
  });

  test('truncated bare tool arguments are never visible prose', () {
    const fragment = '"revision": 3,\n"wait": true,\n"move": {"row": 5,';

    expect(AgentToolTextEnvelope.looksLikeMachinePayload(fragment), isTrue);
    expect(
      OperationalClaimGroundingGuard.evaluate(text: fragment).reason,
      'machine_protocol_leak',
    );
    expect(
      OperationalClaimGroundingGuard.removeUnsupportedSentences(text: fragment),
      isEmpty,
    );
  });

  test('visible self move coordinate must equal submitted arguments', () {
    const result = AgentToolResult(
      toolId: 'cedar_toy.play',
      status: AgentToolStatus.succeeded,
      displayText: '已落子',
      promptData: '真实 outcome',
      submittedArguments: <String, Object?>{
        'game': 'board_room',
        'action': 'move',
        'params': <String, Object?>{
          'move': <String, Object?>{'row': 6, 'col': 6},
        },
      },
    );

    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我刚才下在 (6, 6)。',
        currentToolResults: const <AgentToolResult>[result],
      ).allowed,
      isTrue,
    );
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '那就直接下在 (7, 8)。',
        currentToolResults: const <AgentToolResult>[result],
      ).reason,
      'cedar_action_argument_mismatch',
    );
  });
}
