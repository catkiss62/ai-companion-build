import 'package:ai_companion_localfirst/core/agent/agent_tool_planner.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ordinary companionship turns have no local tool command', () {
    expect(AgentToolPlanner.routeLocally('今天有点累，抱抱我'), isNull);
    expect(AgentToolPlanner.routeLocally('随便和我聊点什么'), isNull);
    expect(
      AgentToolPlanner.nativeToolDefinitionsFor('今天有点累，抱抱我'),
      isEmpty,
      reason: 'CHAT_LIGHT must not carry a permanent toolbox schema',
    );
    expect(
      AgentToolPlanner.nativeToolDefinitionsFor('今天抽到的塔罗牌有点怪'),
      isEmpty,
      reason: 'mentioning phone content is still ordinary chat without a read intent',
    );
    expect(
      AgentToolPlanner.nativeToolDefinitionsFor('我想和你聊聊日记这件事'),
      isEmpty,
      reason: 'a topic mention must not turn into a phone-read task',
    );
  });

  test('route-aware native schemas expose only relevant capability groups', () {
    final webNames = AgentToolPlanner.nativeToolDefinitionsFor('今天有什么最新新闻')
        .map((item) => (item['function'] as Map)['name'])
        .toList();
    expect(webNames, ['public_web_search']);

    final phoneNames = AgentToolPlanner.nativeToolDefinitionsFor('看看你的塔罗记录')
        .map((item) => (item['function'] as Map)['name'])
        .toList();
    expect(phoneNames, containsAll(['phone_search', 'phone_read']));
    expect(phoneNames, isNot(contains('public_web_search')));
  });

  test('explicit phone content request uses a side-effect-free phone read', () {
    final plan = AgentToolPlanner.routeLocally('看看你手机里的日记');
    expect(plan, isNotNull);
    expect(plan!.calls.single.toolId, AgentToolRegistry.phoneRead.id);
    expect(plan.calls.single.arguments['section'], 'diary');

    final search = AgentToolPlanner.routeLocally('查一下你手机塔罗里有没有月亮');
    expect(search, isNotNull);
    expect(search!.calls.single.toolId, AgentToolRegistry.phoneSearch.id);
    expect(search.calls.single.arguments['section'], 'tarot');
  });

  test('explicit web request is routed locally without a second model call', () {
    final plan = AgentToolPlanner.routeLocally('帮我上网搜一下 REDMI K80 Ultra 的公开资料');
    expect(plan, isNotNull);
    expect(plan!.calls.single.toolId, AgentToolRegistry.publicWebSearch.id);
    expect(plan.calls.single.arguments['query'], contains('REDMI K80 Ultra'));
  });

  test('explicit web image save uses one bounded workflow tool', () {
    final plan = AgentToolPlanner.routeLocally('帮我上网找一张唯美黄昏风景图并保存到相册');
    expect(plan, isNotNull);
    expect(plan!.calls.single.toolId, AgentToolRegistry.imageFindAndSave.id);
    expect(plan.calls.single.arguments['query'], contains('黄昏'));
  });

  test('explicit current attachment save is distinct from web image search', () {
    final plan = AgentToolPlanner.routeLocally('把这张图片保存进你的相册');
    expect(plan, isNotNull);
    expect(plan!.calls.single.toolId, AgentToolRegistry.attachmentSave.id);
  });

  test('explicit rules and device reads become real bounded calls', () {
    final rules = AgentToolPlanner.routeLocally('去看看当前规则02');
    expect(rules!.calls.single.toolId, AgentToolRegistry.rulesRead.id);

    final device = AgentToolPlanner.routeLocally('看看我现在打开的是哪个 App');
    expect(device!.calls.single.toolId, AgentToolRegistry.deviceContextRead.id);
  });

  test('one-time screen pixels are distinct from coarse device context', () {
    final screen = AgentToolPlanner.routeLocally(
      '请看一下我此刻的当前屏幕，只说真实画面。',
    );
    expect(screen, isNotNull);
    expect(screen!.calls.single.toolId, AgentToolRegistry.screenObservation.id);

    final device = AgentToolPlanner.routeLocally('看看我现在打开的是哪个 App');
    expect(device!.calls.single.toolId, AgentToolRegistry.deviceContextRead.id);
  });

  test('explicit saved-album recall is local and never becomes web search', () {
    final plan = AgentToolPlanner.routeLocally(
      '你记不记得之前你存的一张你自己的图片？',
    );
    expect(plan, isNotNull);
    expect(plan!.calls.single.toolId, AgentToolRegistry.albumSearch.id);
    expect(plan.calls.single.arguments['query'], contains('你自己的图片'));
  });

  test('meta discussion does not become an explicit search command', () {
    expect(
      AgentToolPlanner.routeLocally(
        '变聪明了，现在让你上网搜索你就搜索，没说搜索就不会调用，挺好',
      ),
      isNull,
    );
    expect(AgentToolPlanner.routeLocally('别上网搜索，这只是举例'), isNull);
  });

  test('explicit self-system questions choose the narrowest local scope', () {
    final facts = AgentToolPlanner.routeLocally('我给你做了哪些能力？');
    expect(facts, isNotNull);
    expect(facts!.calls.single.toolId, AgentToolRegistry.systemSelfRead.id);
    expect(facts.calls.single.arguments['scope'], 'facts');

    final outcomes = AgentToolPlanner.routeLocally('你最近自己做了什么？');
    expect(outcomes, isNotNull);
    expect(outcomes!.calls.single.toolId, AgentToolRegistry.systemSelfRead.id);
    expect(outcomes.calls.single.arguments['scope'], 'outcomes');

    final growth = AgentToolPlanner.routeLocally('查看你的人格学习成长系统状态');
    expect(growth, isNotNull);
    expect(growth!.calls.single.toolId, AgentToolRegistry.systemSelfRead.id);
    expect(growth.calls.single.arguments['scope'], 'growth');
  });

  test('future capability discussion does not falsely execute system self', () {
    expect(AgentToolPlanner.routeLocally('以后有 MCP 之后再说吧'), isNull);
    expect(AgentToolPlanner.routeLocally('今天想和你普通聊聊天'), isNull);
  });

  test('system command prefix always routes to truthful self inspection', () {
    final facts = AgentToolPlanner.routeLocally('【检查系统】你查一下自己的功能');
    expect(facts, isNotNull);
    expect(facts!.calls.single.toolId, AgentToolRegistry.systemSelfRead.id);
    expect(facts.calls.single.arguments['scope'], 'facts');
    expect(facts.calls.single.reasonTag, 'explicit_system_command');

    final outcomes = AgentToolPlanner.routeLocally('【检查系统】最近工具调用结果');
    expect(outcomes!.calls.single.arguments['scope'], 'outcomes');

    final growth = AgentToolPlanner.routeLocally('【检查系统】人格学习候选状态');
    expect(growth!.calls.single.arguments['scope'], 'growth');

    final blank = AgentToolPlanner.routeLocally('【检查系统】');
    expect(blank!.calls.single.arguments['scope'], 'all');
    expect(
      AgentToolPlanner.routeLocally('我们讨论一下【检查系统】这个格式'),
      isNull,
    );
  });

  test('natural system inspection phrases remain compatible', () {
    for (final text in const [
      '检查你的功能',
      '检查你已经有的系统',
      '检查你真实系统',
      '你检查一下你能查看的功能',
    ]) {
      final plan = AgentToolPlanner.routeLocally(text);
      expect(plan, isNotNull, reason: text);
      expect(
        plan!.calls.single.toolId,
        AgentToolRegistry.systemSelfRead.id,
        reason: text,
      );
    }
  });

  test('native function call maps back into the gated local registry', () {
    final plan = AgentToolPlanner.fromNativeToolCalls(const [
      DeepSeekToolCall(
        id: 'call-1',
        name: 'public_web_search',
        arguments: '{"query":"今天的公开新闻"}',
      ),
    ]);
    expect(plan.calls.single.toolId, AgentToolRegistry.publicWebSearch.id);
    expect(plan.calls.single.arguments['query'], '今天的公开新闻');
    expect(
      AgentToolPlanner.nativeToolDefinitions
          .map((item) => (item['function'] as Map)['name']),
      contains('public_web_search'),
    );
    expect(
      AgentToolPlanner.nativeToolDefinitions
          .map((item) => (item['function'] as Map)['name']),
      contains('album_search'),
    );
    expect(
      AgentToolPlanner.nativeToolDefinitions
          .map((item) => (item['function'] as Map)['name']),
      contains('system_self_read'),
    );
    expect(
      AgentToolPlanner.nativeToolDefinitions
          .map((item) => (item['function'] as Map)['name']),
      containsAll(['phone_search', 'phone_read']),
    );
    expect(
      AgentToolPlanner.nativeToolDefinitions
          .map((item) => (item['function'] as Map)['name']),
      isNot(contains('screen_observation_inspect')),
      reason: 'model tool selection is not screenshot consent',
    );
  });

  test('native album function maps back into the read-only registry', () {
    final plan = AgentToolPlanner.fromNativeToolCalls(const [
      DeepSeekToolCall(
        id: 'call-album',
        name: 'album_search',
        arguments: '{"query":"蓝发鲸鱼尾的图片"}',
      ),
    ]);
    expect(plan.calls.single.toolId, AgentToolRegistry.albumSearch.id);
    expect(plan.calls.single.arguments['query'], '蓝发鲸鱼尾的图片');
  });

  test('native system-self function keeps its validated scope', () {
    final plan = AgentToolPlanner.fromNativeToolCalls(const [
      DeepSeekToolCall(
        id: 'call-self',
        name: 'system_self_read',
        arguments: '{"scope":"outcomes"}',
      ),
    ]);
    expect(plan.calls.single.toolId, AgentToolRegistry.systemSelfRead.id);
    expect(plan.calls.single.arguments['scope'], 'outcomes');
  });
}
