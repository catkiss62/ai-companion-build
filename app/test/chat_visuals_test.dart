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
}
