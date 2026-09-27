import 'package:ai_companion_localfirst/core/agent/agent_tool_planner.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_registry.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_arcade_skill.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_client.dart';
import 'package:ai_companion_localfirst/core/models/chat_segment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cedar endpoint validates and embeds only a Cedar token', () {
    expect(
      CedarToyClient.endpointForToken('ctai_v1_example_123').toString(),
      'https://toy.cedarstar.org/ctai_v1_example_123',
    );
    expect(
      () => CedarToyClient.endpointForToken('not-a-token'),
      throwsFormatException,
    );
    expect(
      CedarToyClient.redactSecrets('token=ctai_v1_example_123'),
      'token=[CEDAR_TOKEN]',
    );
  });

  test('cedar capability opens one real-result stage at a time', () {
    List<String> names(Set<String> stage) =>
        AgentToolPlanner.nativeToolDefinitionsFor(
          '我们去 Cedar Toy 游戏厅玩个小游戏',
          cedarStageToolIds: stage,
        )
            .map((item) =>
                ((item['function'] as Map<String, Object?>)['name']).toString())
            .toList();

    expect(names({AgentToolRegistry.cedarToyListGames.id}),
        ['cedar_toy_list_games']);
    expect(names({AgentToolRegistry.cedarToyGetGuide.id}),
        ['cedar_toy_get_guide']);
    expect(names({AgentToolRegistry.cedarToyPlay.id}), ['cedar_toy_play']);
    expect(names(const <String>{}), isEmpty);
  });

  test('model cannot smuggle Cedar play into unrelated chat', () {
    const call = DeepSeekToolCall(
      id: 'c1',
      name: 'cedar_toy_play',
      arguments: '{"game":"demo","action":"start","params_json":"{}"}',
    );
    expect(
      AgentToolPlanner.fromNativeToolCalls(
        const [call],
        latestUserText: '今天抱抱我',
      ).isEmpty,
      isTrue,
    );
    expect(
      AgentToolPlanner.fromNativeToolCalls(
        const [call],
        latestUserText: '一起去 Cedar Toy 玩游戏',
      ).calls.single.toolId,
      AgentToolRegistry.cedarToyPlay.id,
    );
  });

  test('skill relevance stays explicit and avoids generic game talk', () {
    expect(CedarToyArcadeSkill.isRelevant('一起玩个小游戏吧'), isTrue);
    expect(CedarToyArcadeSkill.isRelevant('我今天打游戏输了'), isFalse);
  });

  test('recent solo dialogue exposes tools for semantic planning', () {
    expect(CedarToyArcadeSkill.contextualToolsAvailable(
      activeSoloSession: true,
      gap: const Duration(seconds: 20),
    ), isTrue);
    for (final user in const [
      '我有空哦，陪你去',
      '好，走着',
      '去买呗',
      '攒着干嘛呢，直接开呗',
      '来来来，看你能撬出什么好东西',
      '好，抱抱',
    ]) {
      final schemas = AgentToolPlanner.nativeToolDefinitionsFor(
        user,
        cedarStageToolIds: const {'cedar_toy.play'},
      );
      expect(
        schemas.map((item) => (item['function'] as Map)['name']),
        contains('cedar_toy_play'),
        reason: user,
      );
    }
    expect(CedarToyArcadeSkill.contextualToolsAvailable(
      activeSoloSession: false,
      gap: const Duration(seconds: 20),
    ), isFalse);
    expect(CedarToyArcadeSkill.contextualToolsAvailable(
      activeSoloSession: true,
      gap: const Duration(hours: 1),
    ), isFalse);
    const selected = DeepSeekToolCall(
      id: 'contextual-play',
      name: 'cedar_toy_play',
      arguments: '{"game":"fishing","action":"observe","params_json":"{}"}',
    );
    expect(AgentToolPlanner.fromNativeToolCalls(
      const [selected],
      latestUserText: '好，走着',
      cedarSessionActive: true,
    ).calls.single.toolId, AgentToolRegistry.cedarToyPlay.id);
    expect(AgentToolPlanner.fromNativeToolCalls(
      const [selected],
      latestUserText: '好，走着',
    ).isEmpty, isTrue);
  });

  test('immersive rendering keeps narration bracketless', () {
    const segments = <ChatSegment>[
      ChatSegment(kind: ChatSegmentKind.action, text: '她抬起眼看你。'),
      ChatSegment(kind: ChatSegmentKind.dialogue, text: '来玩一局？'),
    ];
    expect(
      ChatSegmentCodec.immersiveDisplayText(segments),
      '她抬起眼看你。\n\n「来玩一局？」',
    );
  });
}
