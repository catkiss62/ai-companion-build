import 'package:ai_companion_localfirst/core/models/chat_language_variant.dart';
import 'package:ai_companion_localfirst/core/models/chat_segment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MultilingualReplyCodec', () {
    test('projects aligned natural-language segments without persisting tags', () {
      const raw = '''
<multilingual_reply>{"segments":[{"kind":"action","zh":"她轻轻抬眼","ja":"そっと目を上げる","en":"She looks up softly"},{"kind":"dialogue","zh":"我在这里。","ja":"ここにいるよ。","en":"I'm right here."}]}</multilingual_reply>
''';

      final parsed = MultilingualReplyCodec.tryParse(
        raw,
        messageId: 'assistant-1',
      );

      expect(parsed, isNotNull);
      expect(parsed!.chineseContent, '（她轻轻抬眼）\n\n「我在这里。」');
      expect(
        parsed.chineseSegments.map((segment) => segment.kind),
        <ChatSegmentKind>[
          ChatSegmentKind.action,
          ChatSegmentKind.dialogue,
        ],
      );
      expect(
        parsed.foreignVariants[ChatLanguage.japanese]!.content,
        '（そっと目を上げる）\n\n「ここにいるよ。」',
      );
      expect(
        parsed.foreignVariants[ChatLanguage.english]!.content,
        "（She looks up softly）\n\n「I'm right here.」",
      );
      expect(parsed.chineseContent, isNot(contains('multilingual_reply')));
    });

    test('drops one incomplete foreign projection but preserves Chinese', () {
      const raw = '''
<multilingual_reply>{"segments":[{"kind":"dialogue","zh":"第一句","ja":"一つ目","en":"First"},{"kind":"dialogue","zh":"第二句","ja":"","en":"Second"}]}</multilingual_reply>
''';

      final parsed = MultilingualReplyCodec.tryParse(
        raw,
        messageId: 'assistant-2',
      );

      expect(parsed, isNotNull);
      expect(parsed!.chineseContent, '「第一句」\n\n「第二句」');
      expect(parsed.foreignVariants.containsKey(ChatLanguage.japanese), isFalse);
      expect(parsed.foreignVariants.containsKey(ChatLanguage.english), isTrue);
    });

    test('rejects malformed structure and hides partial streams', () {
      const partial =
          '<multilingual_reply>{"segments":[{"kind":"dialogue","zh":"还没完';
      expect(
        MultilingualReplyCodec.streamingChinese(
          partial,
          messageId: 'assistant-3',
        ),
        isEmpty,
      );
      expect(
        MultilingualReplyCodec.tryParse(
          '<multilingual_reply>{"segments":[]}</multilingual_reply>tail',
          messageId: 'assistant-3',
        ),
        isNull,
      );
    });
  });
}
