import 'package:ai_companion_localfirst/core/agent/agent_tool_planner.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_registry.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/message_attachment.dart';
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

  test('media-only empty text safely accepts Cedar stage tool injection', () {
    final createdAt = DateTime(2026, 9, 23);
    final messages = <ChatMessage>[
      ChatMessage(
        id: 'image-only',
        role: 'user',
        content: '',
        createdAt: createdAt,
        attachments: <MessageAttachment>[
          MessageAttachment(
            id: 'image-attachment',
            messageId: 'image-only',
            kind: MessageAttachment.imageKind,
            originalPath: 'originals/image.jpg',
            thumbnailPath: 'thumbnails/image.png',
            mimeType: 'image/jpeg',
            byteSize: 10,
            width: 10,
            height: 10,
            source: 'gallery',
            createdAt: createdAt,
            visionStatus: MessageAttachment.visionCompletedStatus,
            visionSummary: '一只橘猫坐在窗边',
            visionModel: 'qwen-vl',
          ),
        ],
      ),
      ChatMessage(
        id: 'sticker-only',
        role: 'user',
        content: '',
        createdAt: createdAt,
        attachments: <MessageAttachment>[
          MessageAttachment(
            id: 'sticker-attachment',
            messageId: 'sticker-only',
            kind: MessageAttachment.imageKind,
            originalPath: 'originals/sticker.gif',
            thumbnailPath: 'thumbnails/sticker.png',
            mimeType: 'image/gif',
            byteSize: 10,
            width: 10,
            height: 10,
            source: 'user_sticker:personal',
            createdAt: createdAt,
            visionStatus: MessageAttachment.visionCompletedStatus,
            visionSummary: '捂着脸害羞地偷看',
            visionModel: 'sticker_index',
          ),
        ],
      ),
    ];

    for (final message in messages) {
      expect(message.content, isEmpty);
      expect(message.promptContent, isNotEmpty);
      final definitions = AgentToolPlanner.nativeToolDefinitionsFor(
        message.content,
        cedarStageToolIds: const <String>{'cedar_toy.list_games'},
      );
      expect(definitions, hasLength(1), reason: message.id);
      expect(
        (definitions.single['function'] as Map)['name'],
        'cedar_toy_list_games',
        reason: message.id,
      );
    }

    expect(AgentToolPlanner.nativeToolDefinitionsFor(''), isEmpty);
  });

  test('first-person game plans do not authorize companion game tools', () {
    for (final text in const <String>[
      '我会拿来先睡个觉然后刷刷视频玩玩游戏',
      '我打算晚上玩一下游戏',
      '我有空会去钓鱼',
    ]) {
      expect(
        AgentToolPlanner.nativeToolDefinitionsFor(text),
        isEmpty,
        reason: text,
      );
    }
  });

  test('direct and shared game requests still expose Cedar tools', () {
    for (final text in const <String>[
      '我想和你一起玩游戏',
      '你去钓鱼玩吧',
      '去游戏厅玩一下呗',
      '去钓呗',
    ]) {
      final names = AgentToolPlanner.nativeToolDefinitionsFor(text)
          .map((item) => (item['function'] as Map)['name'])
          .toSet();
      expect(names, contains('cedar_toy_play'), reason: text);
    }
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

  test('plain observation verbs do not grant public web access', () {
    expect(AgentToolPlanner.routeLocally('看看有什么好东西'), isNull);
    expect(AgentToolPlanner.routeLocally('看看氧气瓶'), isNull);

    final explicit = AgentToolPlanner.routeLocally('上网看看氧气瓶资料');
    expect(explicit, isNotNull);
    expect(explicit!.calls.single.toolId, AgentToolRegistry.publicWebSearch.id);

    final weather = AgentToolPlanner.routeLocally('看看今天的天气');
    expect(weather, isNotNull);
    expect(weather!.calls.single.toolId, AgentToolRegistry.publicWebSearch.id);
  });

  test('explicit web image save uses one bounded workflow tool', () {
    final plan = AgentToolPlanner.routeLocally('帮我上网找一张唯美黄昏风景图并保存到相册');
    expect(plan, isNotNull);
    expect(plan!.calls.single.toolId, AgentToolRegistry.imageFindAndSave.id);
    expect(plan.calls.single.arguments['query'], contains('黄昏'));
  });

  test('explicit web image send is distinct from saving to album', () {
    final plan = AgentToolPlanner.routeLocally('帮我联网找一张海边日落照片发给我');
    expect(plan, isNotNull);
    expect(plan!.calls.single.toolId, AgentToolRegistry.webImageSend.id);
    expect(plan.calls.single.arguments['query'], contains('海边日落'));
    expect(plan.calls.single.arguments['query'], isNot(contains('发给我')));
  });

  test('explicit saved album image send stays local', () {
    final plan = AgentToolPlanner.routeLocally('把你相册里那张海边照片发给我');
    expect(plan, isNotNull);
    expect(plan!.calls.single.toolId, AgentToolRegistry.albumImageSend.id);
    expect(plan.calls.single.arguments['query'], contains('海边'));
  });

  test('natural 查手机 photo wording routes to a real album attachment', () {
    for (final text in const <String>[
      '你发一张查手机的照片我看看',
      '你随便发一张查手机里的照片给我看看',
    ]) {
      final plan = AgentToolPlanner.routeLocally(text);
      expect(plan, isNotNull, reason: text);
      expect(plan!.calls.single.toolId, AgentToolRegistry.albumImageSend.id);
    }
  });

  test('存起来 is an explicit web image save command', () {
    final plan = AgentToolPlanner.routeLocally('你联网搜一张二次元的图存起来');
    expect(plan, isNotNull);
    expect(plan!.calls.single.toolId, AgentToolRegistry.imageFindAndSave.id);
    expect(plan.calls.single.arguments['query'], '二次元');
  });

  test('image send negation and capability talk do not execute media', () {
    expect(AgentToolPlanner.routeLocally('别联网找图发给我'), isNull);
    expect(AgentToolPlanner.routeLocally('你会不会联网发图？'), isNull);
  });

  test('natural image save wording does not require a web keyword', () {
    final plan = AgentToolPlanner.routeLocally('帮我存一张二次元的图');
    expect(plan, isNotNull);
    expect(plan!.calls.single.toolId, AgentToolRegistry.imageFindAndSave.id);
    expect(plan.calls.single.arguments['query'], contains('二次元'));
    expect(plan.calls.single.arguments['query'], isNot(contains('存一张')));
  });

  test('explicit current attachment save is distinct from web image search', () {
    final plan = AgentToolPlanner.routeLocally('把这张图片保存进你的相册');
    expect(plan, isNotNull);
    expect(plan!.calls.single.toolId, AgentToolRegistry.attachmentSave.id);
  });

  test('explicit sticker request takes the deterministic local Agent route', () {
    final plain = AgentToolPlanner.routeLocally('发个表情包');
    expect(plain, isNotNull);
    expect(plain!.calls.single.toolId, AgentToolRegistry.stickerSend.id);
    expect(plain.calls.single.arguments['intent'], '自然回应');

    final happy = AgentToolPlanner.routeLocally('给我发一张开心的表情包');
    expect(happy, isNotNull);
    expect(happy!.calls.single.toolId, AgentToolRegistry.stickerSend.id);
    expect(happy.calls.single.arguments['intent'], contains('开心'));
  });

  test('sticker battle and sticker-only wording route to real sticker tool', () {
    for (final text in const <String>['来斗图', '这次只回复表情包']) {
      final plan = AgentToolPlanner.routeLocally(text);
      expect(plan, isNotNull, reason: text);
      expect(plan!.calls.single.toolId, AgentToolRegistry.stickerSend.id);
    }
  });

  test('sticker capability talk and negation never send media', () {
    for (final text in const <String>[
      '你会不会发表情包？',
      '你能发表情包吗？',
      '你支持表情包功能吗？',
      '别发表情包，这只是测试。',
    ]) {
      expect(AgentToolPlanner.routeLocally(text), isNull, reason: text);
    }
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

  test('proposal tools are model-callable only for matching explicit text', () {
    final definitions = AgentToolPlanner.nativeToolDefinitionsFor(
      '把你查手机里的照片发一张给我',
    );
    expect(
      definitions.map((item) => (item['function'] as Map)['name']),
      contains('album_image_send'),
    );
    const call = DeepSeekToolCall(
      id: 'call-send-album',
      name: 'album_image_send',
      arguments: '{"query":"任意安全图片"}',
    );
    expect(
      AgentToolPlanner.fromNativeToolCalls(const <DeepSeekToolCall>[call])
          .calls,
      isEmpty,
      reason: '没有当前用户的明确授权时不接受 proposal 工具。',
    );
    final accepted = AgentToolPlanner.fromNativeToolCalls(
      const <DeepSeekToolCall>[call],
      latestUserText: '把你查手机里的照片发一张给我',
    );
    expect(accepted.calls.single.toolId, AgentToolRegistry.albumImageSend.id);
    expect(accepted.calls.single.reasonTag, 'explicit_request');
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
