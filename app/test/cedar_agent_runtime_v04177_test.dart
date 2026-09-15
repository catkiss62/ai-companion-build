import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_agent_decision.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_game_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('truncated planning stream retries as a native Cedar function call',
      () async {
    final client = _ScriptedDeepSeekClient(<List<DeepSeekDelta>>[
      const <DeepSeekDelta>[
        DeepSeekDelta(reasoning: '还在判断，但连接中断'),
      ],
      const <DeepSeekDelta>[
        DeepSeekDelta(
          toolCallDeltas: <DeepSeekToolCallDelta>[
            DeepSeekToolCallDelta(
              index: 0,
              id: 'turn-1',
              name: 'cedar_agent_turn',
              argumentsFragment:
                  '{"participation_mode":"solo","disposition":"act",',
            ),
          ],
        ),
        DeepSeekDelta(
          finishReason: 'tool_calls',
          toolCallDeltas: <DeepSeekToolCallDelta>[
            DeepSeekToolCallDelta(
              index: 0,
              argumentsFragment:
                  '"action":"cmd","params":{"instruction":"观察"}}',
            ),
          ],
        ),
        DeepSeekDelta(done: true),
      ],
    ]);
    var retries = 0;
    final model = DeepSeekCedarAgentDecisionModel(
      client: client,
      onRetry: (_) async => retries++,
    );

    final decision = await model.decideTurn(
      apiKey: 'key',
      endpoint: 'https://example.invalid/chat',
      instruction: '真实指南与状态',
    );

    expect(client.calls, 2);
    expect(retries, 1);
    expect(client.thinkingRequests, <bool>[true, false]);
    expect(client.toolChoices, everyElement('required'));
    expect(decision.disposition, CedarAgentDisposition.act);
    expect(decision.participationMode.key, 'solo');
    expect(decision.action, 'cmd');
    expect(decision.params['instruction'], '观察');
  });

  test('a second incomplete native call fails instead of becoming wait',
      () async {
    final client = _ScriptedDeepSeekClient(<List<DeepSeekDelta>>[
      const <DeepSeekDelta>[DeepSeekDelta(reasoning: '未完成')],
      const <DeepSeekDelta>[
        DeepSeekDelta(
          finishReason: 'length',
          toolCallDeltas: <DeepSeekToolCallDelta>[
            DeepSeekToolCallDelta(
              index: 0,
              name: 'cedar_agent_turn',
              argumentsFragment: '{"participation_mode":"solo"',
            ),
          ],
        ),
      ],
    ]);
    final model = DeepSeekCedarAgentDecisionModel(client: client);

    await expectLater(
      model.decideTurn(
        apiKey: 'key',
        endpoint: 'https://example.invalid/chat',
        instruction: '真实指南与状态',
      ),
      throwsFormatException,
    );
    expect(client.calls, 2);
  });

  test('foreground keeps discovery and companion turns inside one goal', () {
    expect(
      CedarAgentTurnPolicy.continueInCurrentTurn(
        succeeded: true,
        protocolAction: 'list_games',
        nextActor: '',
      ),
      isTrue,
    );
    expect(
      CedarAgentTurnPolicy.continueInCurrentTurn(
        succeeded: true,
        protocolAction: 'get_guide',
        nextActor: 'companion',
      ),
      isTrue,
    );
    expect(
      CedarAgentTurnPolicy.continueInCurrentTurn(
        succeeded: true,
        protocolAction: 'move',
        nextActor: 'companion',
      ),
      isTrue,
    );
    expect(
      CedarAgentTurnPolicy.continueInCurrentTurn(
        succeeded: true,
        protocolAction: 'move',
        nextActor: 'user',
      ),
      isFalse,
    );
  });

  test('background schedules Agent work from real actor or continuation', () {
    expect(
      CedarAgentTurnPolicy.scheduleBackground(
        succeeded: true,
        nextActor: 'companion',
        hasTimer: false,
        hasServerContinuation: false,
        hasPendingRoomMessage: false,
      ),
      isTrue,
    );
    expect(
      CedarAgentTurnPolicy.scheduleBackground(
        succeeded: true,
        nextActor: 'user',
        hasTimer: false,
        hasServerContinuation: true,
        hasPendingRoomMessage: false,
      ),
      isTrue,
    );
    expect(
      CedarAgentTurnPolicy.scheduleBackground(
        succeeded: true,
        nextActor: 'user',
        hasTimer: false,
        hasServerContinuation: false,
        hasPendingRoomMessage: false,
      ),
      isFalse,
    );
  });

  test('reading a solo guide cannot be persisted as waiting or complete', () {
    expect(
      CedarAgentTurnPolicy.permitsStopBeforePlay(
        hasRealPlayOutcome: false,
        invitationApproved: false,
        modeRequiresInvitation: false,
        disposition: 'await_remote',
      ),
      isFalse,
    );
    expect(
      CedarAgentTurnPolicy.permitsStopBeforePlay(
        hasRealPlayOutcome: false,
        invitationApproved: false,
        modeRequiresInvitation: true,
        disposition: 'invite_user',
      ),
      isTrue,
    );
    expect(
      CedarAgentTurnPolicy.permitsStopBeforePlay(
        hasRealPlayOutcome: true,
        invitationApproved: false,
        modeRequiresInvitation: false,
        disposition: 'await_remote',
      ),
      isTrue,
    );
  });
}

class _ScriptedDeepSeekClient extends DeepSeekClient {
  _ScriptedDeepSeekClient(this.scripts);

  final List<List<DeepSeekDelta>> scripts;
  final List<bool> thinkingRequests = <bool>[];
  final List<String> toolChoices = <String>[];
  int calls = 0;

  @override
  Stream<DeepSeekDelta> streamChat({
    required String apiKey,
    required DeepSeekModelProfile model,
    required ReasoningEffort effort,
    required List<Map<String, Object?>> messages,
    String endpoint = DeepSeekClient.defaultEndpoint,
    bool thinking = true,
    int? maxTokens,
    List<Map<String, Object?>> tools = const <Map<String, Object?>>[],
    String? toolChoice,
    GenerationCancellationToken? cancellationToken,
  }) async* {
    final index = calls++;
    thinkingRequests.add(thinking);
    toolChoices.add(toolChoice ?? '');
    for (final delta in scripts[index]) {
      yield delta;
    }
  }
}
