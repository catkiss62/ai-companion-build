import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/grounding/operational_claim_grounding_guard.dart';
import 'package:flutter_test/flutter_test.dart';

const _selfReadSuccess = AgentToolResult(
  toolId: 'system_self.read',
  status: AgentToolStatus.succeeded,
  displayText: '已读取成长状态',
  promptData:
      '【PERSONALITY LEARNING STATUS】\n[GROWTH_RUNTIME phase=phase2b_bounded_bias]',
);

const _factsOnlySuccess = AgentToolResult(
  toolId: 'system_self.read',
  status: AgentToolStatus.succeeded,
  displayText: '已读取系统事实',
  promptData: '【SYSTEM FACTS】',
);

const _screenSuccess = AgentToolResult(
  toolId: 'screen_observation.inspect',
  status: AgentToolStatus.succeeded,
  displayText: '已观察当前屏幕',
  promptData: 'bounded visual summary',
);

const _attachmentSaveSuccess = AgentToolResult(
  toolId: 'attachment.save',
  status: AgentToolStatus.succeeded,
  displayText: '已保存',
  promptData: 'TERMINAL SUCCESS',
);

const _stickerSendSuccess = AgentToolResult(
  toolId: 'sticker.send',
  status: AgentToolStatus.succeeded,
  displayText: '已准备真实表情包',
  promptData: 'STICKER ATTACHMENT',
);

const _webImageSendSuccess = AgentToolResult(
  toolId: 'image.web_send',
  status: AgentToolStatus.succeeded,
  displayText: '已准备图片',
  promptData: 'WEB IMAGE ATTACHMENT',
);

const _cedarPlaySuccess = AgentToolResult(
  toolId: 'cedar_toy.play',
  status: AgentToolStatus.succeeded,
  displayText: '已取得真实游玩结果',
  promptData: '【Cedar Toy 真实 游玩 Outcome】',
);

void main() {
  test('immediate Cedar join claim requires a successful play outcome', () {
    final blocked = OperationalClaimGroundingGuard.evaluate(
      text: '我这就杀进去，马上加入房间。',
    );
    expect(blocked.allowed, isFalse);
    expect(blocked.requiredToolId, 'cedar_toy.play');
  });

  test('Cedar game achievements require a current successful play outcome', () {
    expect(
      OperationalClaimGroundingGuard.evaluate(text: '我刚才玩了一局，还赢了。')
          .allowed,
      isFalse,
    );
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我刚才玩了一局，还赢了。',
        currentToolResults: const [_cedarPlaySuccess],
      ).allowed,
      isTrue,
    );
    expect(
      OperationalClaimGroundingGuard.evaluate(text: '我想去玩一局。').allowed,
      isTrue,
    );
  });

  test('durable autonomous Cedar outcome authorizes its later share', () {
    final now = DateTime(2026, 9, 20, 6);
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我刚才玩了一局游戏。',
        cedarOutcomeAvailable: true,
        cedarOutcomeAt: now.subtract(const Duration(minutes: 12)),
        now: now,
      ).allowed,
      isTrue,
    );
  });

  test('old Cedar outcome cannot be presented as just completed', () {
    final now = DateTime(2026, 9, 20, 6);
    final result = OperationalClaimGroundingGuard.evaluate(
      text: '我刚在钓鱼里连甩了十竿，还钓上来三条鱼。',
      cedarOutcomeAvailable: true,
      cedarOutcomeAt: now.subtract(const Duration(hours: 4)),
      now: now,
    );
    expect(result.allowed, isFalse);
    expect(result.reason, 'stale_cedar_event_presented_as_recent');
  });

  test('old Cedar outcome remains shareable with an honest history anchor', () {
    final now = DateTime(2026, 9, 20, 6);
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '上次钓鱼时连甩了十竿，还碰到过分裂鱼钩。',
        cedarOutcomeAvailable: true,
        cedarOutcomeAt: now.subtract(const Duration(days: 1)),
        now: now,
      ).allowed,
      isTrue,
    );
  });

  test('fresh Cedar fishing action is authorized by its exact outcome time', () {
    final now = DateTime(2026, 9, 20, 6);
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我刚在钓鱼里连甩了十竿。',
        cedarOutcomeAvailable: true,
        cedarOutcomeAt: now.subtract(const Duration(minutes: 59)),
        now: now,
      ).allowed,
      isTrue,
    );
  });

  test('unfinished fishing scene is not evidence of live play', () {
    for (final text in <String>[
      '主人，漂还是没动，图鉴也还是那几条老面孔。',
      '我把鱼竿往石缝里插稳，继续坐在池塘边等。',
      '鱼饵补齐了，我又坐回池塘边上了。',
      '我换了好几个方向甩，图鉴一点没往上动。',
      '你负责帮我盯鱼漂，我负责靠着你发呆。',
      '我就把鱼漂挂着等待，看看什么时候咬钩。',
      '钓鱼多省事，甩出去挂着就行。',
    ]) {
      final result = OperationalClaimGroundingGuard.evaluate(text: text);
      expect(result.allowed, isFalse, reason: text);
      expect(result.reason, 'ungrounded_cedar_live_state');
      expect(result.requiredToolId, 'cedar_toy.play');
    }
  });

  test('game non-execution and honest history anchors remain speakable', () {
    for (final text in <String>[
      '我其实还没有去玩，只是又想起钓鱼了。',
      '我打算待会儿去钓鱼，但现在还没开始。',
      '上次钓鱼时，鱼漂确实半天没动。',
      '昨天我坐在池塘边等过一阵。',
    ]) {
      expect(
        OperationalClaimGroundingGuard.evaluate(text: text).allowed,
        isTrue,
        reason: text,
      );
    }
  });

  test('a current Cedar outcome can ground a live game report', () {
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我正在钓鱼，鱼漂刚有动静。',
        currentToolResults: const [_cedarPlaySuccess],
      ).allowed,
      isTrue,
    );
  });

  test('blocks a fabricated all-afternoon growth-system report', () {
    final result = OperationalClaimGroundingGuard.evaluate(
      text: '我看了一下午自己的人格学习和成长系统，发现变化挺大的。',
    );
    expect(result.allowed, isFalse);
    expect(result.reason, 'unsupported_operation_duration');
    expect(result.requiredToolId, 'system_self.read');
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我没有偷懒，我看了一下午成长系统。',
      ).allowed,
      isFalse,
    );
  });

  test('one-shot self read supports only a bounded immediate report', () {
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我刚才读取了成长状态。',
        currentToolResults: const [_factsOnlySuccess],
      ).allowed,
      isFalse,
      reason: 'facts scope cannot masquerade as a growth-table read',
    );
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我刚才读取了成长状态，目前是有界倾向层。',
        currentToolResults: const [_selfReadSuccess],
      ).allowed,
      isTrue,
    );
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我研究了好几个小时成长系统。',
        currentToolResults: const [_selfReadSuccess],
      ).allowed,
      isFalse,
    );
  });

  test('screen content requires the matching screen tool', () {
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我刚才看了当前屏幕，画面里有一张照片。',
      ).reason,
      'ungrounded_screen_observation',
    );
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我刚才看了当前屏幕，画面里有一张照片。',
        currentToolResults: const [_screenSuccess],
      ).allowed,
      isTrue,
    );
    final fabricatedPage = OperationalClaimGroundingGuard.evaluate(
      text: '屏幕上最后停在那堆呆毛的调试页上。',
    );
    expect(fabricatedPage.allowed, isFalse);
    expect(fabricatedPage.reason, 'ungrounded_screen_observation');
    expect(fabricatedPage.requiredToolId, 'screen_observation.inspect');
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '屏幕上显示着 Live2D 调试页面。',
        currentToolResults: const [_screenSuccess],
      ).allowed,
      isTrue,
    );
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '手机屏幕亮着，但我不知道里面显示什么。',
      ).allowed,
      isTrue,
      reason: 'coarse power state is not a pixel-content claim',
    );
  });

  test('denial and correction of an old false report remain speakable', () {
    for (final text in <String>[
      '我并没有真的看一下午成长系统，那句话是虚报。',
      '我不能说自己刚才看过当前屏幕，因为没有截图结果。',
      '如果我声称已经调用 MCP，那就是编造。',
      '我刚才一直在想这件事，但没有读取系统。',
      '用户问我是不是看了一下午成长系统，需要按真实结果回答。',
      '如果屏幕显示调试页，也不能在没有截图时当成事实。',
    ]) {
      expect(
        OperationalClaimGroundingGuard.evaluate(text: text).allowed,
        isTrue,
        reason: text,
      );
    }
  });

  test('blocks unsupported completion claims for future tools', () {
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我已经成功调用 MCP，把游戏接好了。',
      ).allowed,
      isFalse,
    );
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我刚才设置了真实提醒。',
      ).allowed,
      isFalse,
    );
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我调用 MCP 成功了。',
      ).allowed,
      isFalse,
    );
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我已经把这张图片保存进相册了。',
        currentToolResults: const [_attachmentSaveSuccess],
      ).allowed,
      isTrue,
    );
  });

  test('sticker send claims require the current real media result', () {
    final blocked = OperationalClaimGroundingGuard.evaluate(
      text: '我给你发了一张表情包。',
    );
    expect(blocked.allowed, isFalse);
    expect(blocked.reason, 'ungrounded_sticker_send');
    expect(blocked.requiredToolId, 'sticker.send');
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我给你发了一张表情包。',
        currentToolResults: const [_stickerSendSuccess],
      ).allowed,
      isTrue,
    );
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我没有发表情包，因为没找到合适的。',
      ).allowed,
      isTrue,
    );
  });

  test('ordinary image send claims require a real current media result', () {
    final blocked = OperationalClaimGroundingGuard.evaluate(
      text: '我给你发了一张海边照片。',
    );
    expect(blocked.allowed, isFalse);
    expect(blocked.reason, 'ungrounded_image_send');
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我联网找到后给你发了一张海边照片。',
        currentToolResults: const [_webImageSendSuccess],
      ).allowed,
      isTrue,
    );
    for (final fabricated in <String>[
      '（传了一张图：画面里是一只猫）',
      '我把这张图拿给你看了。',
    ]) {
      expect(
        OperationalClaimGroundingGuard.evaluate(text: fabricated).allowed,
        isFalse,
        reason: fabricated,
      );
    }
  });

  test('memory recall is real but does not become an archive read', () {
    for (final text in <String>[
      '我又想起了我们前几天聊过的那件事。',
      '我下午有一阵子又琢磨过那个承诺。',
      '根据我记得的内容，你当时确实提过海边。',
    ]) {
      expect(
        OperationalClaimGroundingGuard.evaluate(text: text).allowed,
        isTrue,
        reason: text,
      );
    }
    for (final text in <String>[
      '我翻了一遍咱俩的记录。',
      '我下午浏览了这些天的对话，发现你总爱安排我。',
      '我刚复盘了我们的聊天。',
      '我要编造一个结果，但可以说我翻看了我们的聊天记录。',
    ]) {
      final result = OperationalClaimGroundingGuard.evaluate(text: text);
      expect(result.allowed, isFalse, reason: text);
      expect(result.reason, 'ungrounded_chat_archive_read');
      expect(result.requiredToolId, 'conversation_archive.read');
    }
  });

  test('public-web journey metaphors require a successful web outcome', () {
    for (final text in <String>[
      '我出去逛网的时候看到个有意思的东西。',
      '我在网上转了一圈，现在回来了。',
      '我从网上回来了，给你带了个发现。',
    ]) {
      final blocked = OperationalClaimGroundingGuard.evaluate(text: text);
      expect(blocked.allowed, isFalse, reason: text);
      expect(blocked.reason, 'ungrounded_public_web_journey');
      expect(blocked.requiredToolId, 'public_web.discover');
      expect(
        OperationalClaimGroundingGuard.evaluate(
          text: text,
          publicWebOutcomeAvailable: true,
        ).allowed,
        isTrue,
        reason: text,
      );
    }
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我没有真的出去逛网，只是忽然想到了这件事。',
      ).allowed,
      isTrue,
    );
    expect(
      OperationalClaimGroundingGuard.evaluate(
        text: '我正想出去逛网看看，但还没有真的去。',
      ).allowed,
      isTrue,
    );
  });

  test('salvage removes only unsupported operation sentences', () {
    const text = '我刚才查看了当前屏幕。你这个称呼倒是挺会挑。那我们继续。';
    final salvaged = OperationalClaimGroundingGuard.removeUnsupportedSentences(
      text: text,
    );

    expect(salvaged, isNot(contains('查看了当前屏幕')));
    expect(salvaged, contains('你这个称呼倒是挺会挑'));
    expect(salvaged, contains('那我们继续'));
  });
}
