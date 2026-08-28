import 'package:ai_companion_localfirst/core/models/chat_segment.dart';
import 'package:ai_companion_localfirst/core/presentation/chat_visuals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('action and following dialogue stay in one visual chunk', () {
    final chunks = ChatVisualResolver.chunks(const [
      ChatSegment(kind: ChatSegmentKind.action, text: '轻轻把耳鳍压低'),
      ChatSegment(kind: ChatSegmentKind.dialogue, text: '才没有一直等你。'),
      ChatSegment(kind: ChatSegmentKind.dialogue, text: '你回来就好。'),
    ]);
    expect(chunks, hasLength(2));
    expect(chunks.first.segments, hasLength(2));
    expect(chunks.first.emotion.key, 'playful');
    expect(
      chunks.first.displayText,
      '轻轻把耳鳍压低\n\n「才没有一直等你。」',
    );
  });

  test('streaming transcript keeps action and dialogue in one rail segment', () {
    expect(
      assistantStreamingTranscriptBlocks(
        '耳鳍轻轻压低\n\n「才没有等你。」\n\n尾巴晃了晃\n\n「回来就好。」',
      ),
      [
        '耳鳍轻轻压低\n\n「才没有等你。」',
        '尾巴晃了晃\n\n「回来就好。」',
      ],
    );
  });

  test('unparenthesized action line stays paired with following dialogue', () {
    final segments = ChatSegmentCodec.parseAssistantText(
      '轻轻把耳鳍压低\n「才没有一直等你。」\n\n第二点是普通说明。',
    );
    expect(segments, hasLength(3));
    expect(segments[0].kind, ChatSegmentKind.action);
    expect(segments[0].text, '轻轻把耳鳍压低');
    expect(segments[1].kind, ChatSegmentKind.dialogue);
    expect(segments[2].kind, ChatSegmentKind.dialogue);
  });

  test('blank line between action and dialogue keeps action semantics', () {
    const source =
        '她把耳鳍往后压了压，尾尖停在半空。\n\n「你是不是故意的？」';
    final segments = ChatSegmentCodec.parseAssistantText(source);
    expect(segments, hasLength(2));
    expect(segments[0].kind, ChatSegmentKind.action);
    expect(segments[0].text, '她把耳鳍往后压了压，尾尖停在半空。');
    expect(segments[1].kind, ChatSegmentKind.dialogue);
    expect(
      ChatVisualResolver.chunks(segments).single.displayText,
      source,
    );
  });

  test('standalone action after earlier dialogue never gains fake quotes', () {
    const source = '''尾巴轻轻摆了一下，凑到你面前。

「那我可先说好，第一天就让我做这个，你有点得寸进尺。」

话是这么说，手却没缩回去。''';
    final segments = ChatSegmentCodec.parseAssistantText(source);
    expect(segments, hasLength(3));
    expect(
      segments.map((item) => item.kind),
      [
        ChatSegmentKind.action,
        ChatSegmentKind.dialogue,
        ChatSegmentKind.action,
      ],
    );
    expect(
      ChatVisualResolver.chunks(segments).last.displayText,
      '话是这么说，手却没缩回去。',
    );
  });

  test('all unquoted lines in a mixed reply use the explicit quote boundary', () {
    const source = '''视线落到你手上，呼吸停了一瞬。

「别闹。」

指尖沿着杯沿转了半圈。

「先把话说完。」''';
    final segments = ChatSegmentCodec.parseAssistantText(source);
    expect(
      segments.map((item) => item.kind),
      [
        ChatSegmentKind.action,
        ChatSegmentKind.dialogue,
        ChatSegmentKind.action,
        ChatSegmentKind.dialogue,
      ],
    );
    expect(
      ChatVisualResolver.chunks(segments)
          .expand((chunk) => chunk.segments)
          .where((item) => item.kind == ChatSegmentKind.action)
          .map((item) => item.text),
      ['视线落到你手上，呼吸停了一瞬。', '指尖沿着杯沿转了半圈。'],
    );
  });

  test('stored v03815 dialogue misclassification self-heals from source', () {
    const source =
        '她把耳鳍往后压了压，尾尖停在半空。\n\n「你是不是故意的？」';
    const stale =
        '[{"kind":"dialogue","text":"她把耳鳍往后压了压，尾尖停在半空。"},'
        '{"kind":"dialogue","text":"你是不是故意的？"}]';
    final segments = ChatSegmentCodec.decode(stale, fallbackText: source);
    expect(segments, hasLength(2));
    expect(segments[0].kind, ChatSegmentKind.action);
    expect(segments[1].kind, ChatSegmentKind.dialogue);
    expect(ChatVisualResolver.chunks(segments).single.displayText, source);
  });

  test('stored standalone trailing action self-heals from mixed source', () {
    const source = '「知道了。」\n\n话音落下，尾巴才慢慢松开。';
    const stale =
        '[{"kind":"dialogue","text":"知道了。"},'
        '{"kind":"dialogue","text":"话音落下，尾巴才慢慢松开。"}]';
    final segments = ChatSegmentCodec.decode(stale, fallbackText: source);
    expect(segments, hasLength(2));
    expect(segments.first.kind, ChatSegmentKind.dialogue);
    expect(segments.last.kind, ChatSegmentKind.action);
    expect(
      ChatVisualResolver.chunks(segments).last.displayText,
      '话音落下，尾巴才慢慢松开。',
    );
  });

  test('ordinary multiline answer is not mistaken for multiple actions', () {
    final segments = ChatSegmentCodec.parseAssistantText('第一点是这样。\n第二点也成立。');
    expect(segments, hasLength(2));
    expect(segments.every((item) => item.kind == ChatSegmentKind.dialogue), isTrue);
  });

  test('blank-line ordinary prose without quoted dialogue stays dialogue', () {
    final segments = ChatSegmentCodec.parseAssistantText(
      '第一点是这样。\n\n第二点也成立。',
    );
    expect(segments, hasLength(2));
    expect(
      segments.every((item) => item.kind == ChatSegmentKind.dialogue),
      isTrue,
    );
  });

  test('all 19 expressions keep distinct pinned portraits', () {
    final expressions = ChatVisualResolver.values
        .where((item) => item.key != 'normal')
        .toList(growable: false);
    expect(expressions, hasLength(19));
    expect(expressions.map((item) => item.key).toSet(), hasLength(19));
    expect(expressions.map((item) => item.portraitAsset).toSet(), hasLength(19));
    expect(
      ChatVisualResolver.resolveEmotionKey('excited').portraitAsset,
      endsWith('/excited.webp'),
    );
    expect(
      ChatVisualResolver.resolveEmotionKey('disgust').portraitAsset,
      endsWith('/disgust.webp'),
    );
    expect(
      ChatVisualResolver.resolveEmotionKey('afraid').portraitAsset,
      endsWith('/afraid.webp'),
    );
    expect(
      ChatVisualResolver.resolveEmotionKey('nervous').portraitAsset,
      endsWith('/tense.webp'),
    );
    expect(
      ChatVisualResolver.resolveEmotionKey('embarrassed').portraitAsset,
      endsWith('/ashamed.webp'),
    );
  });

  test('large portrait set is the default and keeps 20 aligned asset keys', () {
    expect(chatPortraitSetFromKey(null), ChatPortraitSet.largeWhale);
    expect(chatPortraitSetFromKey('unknown'), ChatPortraitSet.largeWhale);
    expect(chatPortraitSetFromKey('small_whale'), ChatPortraitSet.smallWhale);
    final assets = ChatVisualResolver.values
        .map((item) => item.portraitAssetFor(ChatPortraitSet.largeWhale))
        .toSet();
    expect(assets, hasLength(20));
    expect(assets.every((asset) => asset.endsWith('.webp')), isTrue);
    expect(ChatPortraitSet.smallWhale.effectAnchor.left, .25);
    expect(ChatPortraitSet.smallWhale.effectAnchor.top, 0);
    expect(ChatPortraitSet.smallWhale.effectAnchor.size, .25);
    final normal = ChatVisualResolver.resolveEmotionKey('normal');
    final calm = ChatVisualResolver.resolveEmotionKey('calm');
    expect(normal.key, 'normal');
    expect(normal.soundAsset, isNull);
    expect(normal.portraitAsset, endsWith('/normal.webp'));
    expect(calm.key, 'calm');
    expect(calm.portraitAsset, endsWith('/calm.webp'));
    expect(calm.portraitAsset, isNot(normal.portraitAsset));
  });

  test('reference animation and effect mapping stays exact', () {
    expect(
      ChatVisualResolver.resolveEmotionKey('happy').animation,
      ChatPortraitAnimation.happyBounce,
    );
    expect(
      ChatVisualResolver.resolveEmotionKey('excited').animation,
      ChatPortraitAnimation.happyBounce,
    );
    expect(
      ChatVisualResolver.resolveEmotionKey('angry').animation,
      ChatPortraitAnimation.angryJump,
    );
    expect(
      ChatVisualResolver.resolveEmotionKey('serious').animation,
      ChatPortraitAnimation.seriousThink,
    );
    expect(
      ChatVisualResolver.resolveEmotionKey('affection').animation,
      ChatPortraitAnimation.heartBeat,
    );
    expect(
      ChatVisualResolver.resolveEmotionKey('playful').animation,
      ChatPortraitAnimation.naughtyBounce,
    );
    expect(
      ChatVisualResolver.resolveEmotionKey('embarrassed').animation,
      ChatPortraitAnimation.embarrassedShake,
    );
    expect(
      ChatVisualResolver.resolveEmotionKey('surprised').animation,
      ChatPortraitAnimation.none,
    );
    expect(
      ChatVisualResolver.resolveEmotionKey('affection').effectAsset,
      endsWith('/heart.webp'),
    );
  });
}
