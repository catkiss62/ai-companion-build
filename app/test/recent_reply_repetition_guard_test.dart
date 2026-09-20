import 'package:ai_companion_localfirst/core/grounding/recent_reply_repetition_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blocks an exact recent assistant reply after presentation cleanup', () {
    final result = RecentReplyRepetitionGuard.evaluate(
      text: '「我其实还没有去玩，只是又想起这件事了。」',
      recentAssistantTexts: const <String>[
        '前一条不同的消息。',
        ' 我其实还没有去玩，只是又想起这件事了。 ',
      ],
    );

    expect(result.allowed, isFalse);
    expect(result.reason, 'exact_recent_reply');
  });

  test('allows the same topic when the actual reply is different', () {
    final result = RecentReplyRepetitionGuard.evaluate(
      text: '没有睡着。我刚才把没发生的游戏画面说岔了。',
      recentAssistantTexts: const <String>[
        '我其实还没有去玩，只是又想起这件事了。',
      ],
    );

    expect(result.allowed, isTrue);
  });

  test('user reply liveness prefers a natural non-repeated candidate', () {
    expect(
      UserReplyLivenessPolicy.choose(
        initialText: '鱼漂还挂着呢。',
        correctedText: '没有睡着，刚刚只是走神了。',
        initialRepeated: false,
        correctedRepeated: false,
      ),
      UserReplyCandidateSource.corrected,
    );
    expect(
      UserReplyLivenessPolicy.choose(
        initialText: '鱼漂还挂着呢。',
        correctedText: '上一轮已经说过的话。',
        initialRepeated: false,
        correctedRepeated: true,
      ),
      UserReplyCandidateSource.initial,
    );
  });

  test('user reply liveness never selects blank over model speech', () {
    expect(
      UserReplyLivenessPolicy.choose(
        initialText: '至少保留模型真实生成的这一句。',
        correctedText: '',
        initialRepeated: true,
        correctedRepeated: false,
      ),
      UserReplyCandidateSource.initial,
    );
  });
}
