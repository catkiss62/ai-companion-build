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
      '（轻轻把耳鳍压低）\n\n「才没有一直等你。」',
    );
  });

  test('ordinary multiline answer is not mistaken for multiple actions', () {
    final segments = ChatSegmentCodec.parseAssistantText('第一点是这样。\n第二点也成立。');
    expect(segments, hasLength(2));
    expect(segments.every((item) => item.kind == ChatSegmentKind.dialogue), isTrue);
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
