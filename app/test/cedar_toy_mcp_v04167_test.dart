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

  test('short directives continue a recent solo game exchange', () {
    const examples = <(String, String)>[
      ('你那地图碎片还卡在最后一片吧？一起去海沟找大鱼。', '我有空哦，陪你去'),
      ('等本大人把高级饵和氧气瓶算明白。', '好，走着'),
      ('那些高级饵打折有刷新时段，积分要省着花。', '去买呗'),
      ('之前钓鱼钩上来一个锈迹宝箱，我一直没舍得开。', '攒着干嘛呢，直接开呗'),
      ('钓鱼捞上来一个藤壶密箱，看我一撬棍下去。', '来来来，看你能撬出什么好东西'),
    ];
    for (final (assistant, user) in examples) {
      expect(CedarToyArcadeSkill.requestsContextualContinuation(
        userText: user,
        previousAssistantText: assistant,
        activeSoloSession: true,
        gap: const Duration(seconds: 20),
      ), isTrue, reason: user);
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
    for (final user in const ['好，抱抱', '下次去买', '我有空会去钓鱼']) {
      expect(CedarToyArcadeSkill.requestsContextualContinuation(
        userText: user,
        previousAssistantText: '鱼饵和氧气瓶都准备好了。',
        activeSoloSession: true,
        gap: const Duration(seconds: 20),
      ), isFalse, reason: user);
    }
    expect(CedarToyArcadeSkill.requestsContextualContinuation(
      userText: '去买呗',
      previousAssistantText: '鱼饵打折了。',
      activeSoloSession: false,
      gap: const Duration(seconds: 20),
    ), isFalse);
    expect(CedarToyArcadeSkill.requestsContextualContinuation(
      userText: '去买呗',
      previousAssistantText: '鱼饵打折了。',
      activeSoloSession: true,
      gap: const Duration(hours: 1),
    ), isFalse);
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
