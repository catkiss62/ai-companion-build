import 'dart:convert';

import 'package:ai_companion_localfirst/core/agent/agent_participation_consent.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_text_envelope.dart';
import 'package:ai_companion_localfirst/core/grounding/operational_claim_grounding_guard.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_turn_state_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const dsmlMove = '''<｜｜DSML｜｜ calls>
<｜｜DSML｜｜ invoke name="cedar_toy_play">
<｜｜DSML｜｜ parameter name="game" string="true">board_room</｜｜DSML｜｜ parameter>
<｜｜DSML｜｜ parameter name="action" string="true">move</｜｜DSML｜｜ parameter>
<｜｜DSML｜｜ parameter name="params_json" string="true">{"x":8,"y":7}</｜｜DSML｜｜ parameter>
<｜｜DSML｜｜ parameter name="participation_mode" string="true">co_play</｜｜DSML｜｜ parameter>
<｜｜DSML｜｜ parameter name="invitation_approved">true</｜｜DSML｜｜ parameter>
</｜｜DSML｜｜ invoke>
</｜｜DSML｜｜ calls>''';

  test('provider DSML is normalized into an ordinary typed tool call', () {
    final parsed = AgentToolTextEnvelope.parse(dsmlMove);

    expect(parsed.detected, isTrue);
    expect(parsed.valid, isTrue);
    expect(parsed.calls, hasLength(1));
    expect(parsed.calls.single.name, 'cedar_toy_play');
    final arguments = jsonDecode(parsed.calls.single.arguments) as Map;
    expect(arguments['game'], 'board_room');
    expect(arguments['action'], 'move');
    expect(arguments['params_json'], '{"x":8,"y":7}');
    expect(arguments['invitation_approved'], isTrue);
  });

  test('malformed protocol is detected but never treated as dialogue', () {
    final malformed = AgentToolTextEnvelope.parse(
      '<｜｜DSML｜｜ calls><｜｜DSML｜｜ invoke name="tool">broken',
    );

    expect(malformed.detected, isTrue);
    expect(malformed.valid, isFalse);
    expect(AgentToolTextEnvelope.shouldHoldFromVisibleStream('<｜｜DS'), isTrue);
    expect(AgentToolTextEnvelope.shouldHoldFromVisibleStream('普通回复'), isFalse);
  });

  test('final outbound guard removes machine protocol instead of saving it', () {
    final blocked = OperationalClaimGroundingGuard.evaluate(text: dsmlMove);
    final salvaged = OperationalClaimGroundingGuard.removeUnsupportedSentences(
      text: '$dsmlMove\n这句才是可以显示的正文。',
    );

    expect(blocked.allowed, isFalse);
    expect(blocked.reason, 'machine_protocol_leak');
    expect(salvaged, '这句才是可以显示的正文。');
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我只是在解释 "tool_calls" 这个字段。',
      ).allowed,
      isTrue,
    );
  });

  test('participation consent recognizes either direction of invitation', () {
    expect(
      AgentParticipationConsentPolicy.explicitlyGranted(
        '我已经建好房间了，邀请你进来一起玩。',
      ),
      isTrue,
    );
    expect(
      AgentParticipationConsentPolicy.describesExistingRoom(
        '我这边已经开好房间，来吧。',
      ),
      isTrue,
    );
    expect(
      AgentParticipationConsentPolicy.explicitlyGranted('可以啊，来吧'),
      isTrue,
    );
    expect(
      AgentParticipationConsentPolicy.describesExistingRoom('5JH5MDVT'),
      isTrue,
    );
    expect(
      AgentParticipationConsentPolicy.explicitlyGranted('5JH5MDVT'),
      isTrue,
    );
    expect(
      AgentParticipationConsentPolicy.explicitlyGranted('暂时不玩'),
      isFalse,
    );
  });

  test('structured participant identity overrides guessed move order', () {
    final result = McpTurnStateResolver.resolveStructured(<String, Object?>{
      'state': <String, Object?>{
        'current_actor': <String, Object?>{'player_id': 'machine-7'},
        'participants': <Object?>[
          <String, Object?>{
            'player_id': 'person-3',
            'role': 'human',
            'piece': 'X',
          },
          <String, Object?>{
            'player_id': 'machine-7',
            'kind': 'bound_machine',
            'piece': 'O',
          },
        ],
      },
    });

    expect(result?.nextActor, 'companion');
    expect(result?.reason, 'structured_participant_identity');
  });

  test('common turn and terminal fields are resolved without game hardcode', () {
    expect(
      McpTurnStateResolver.resolve(
        '{"rooms":[{"turn":"ai","own_seat":"south"}]}\nnotice',
      )?.nextActor,
      'companion',
    );
    expect(
      McpTurnStateResolver.resolve('{"current_actor":"human"}')?.nextActor,
      'user',
    );
    expect(
      McpTurnStateResolver.resolve('{"status":"completed"}')?.nextActor,
      'finished',
    );
    expect(McpTurnStateResolver.resolve('轮到谁并不明确'), isNull);
  });
}
