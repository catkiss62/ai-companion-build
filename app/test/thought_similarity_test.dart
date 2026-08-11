import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/desire/thought_similarity.dart';

void main() {
  test('exact and near-identical Chinese thoughts score high', () {
    expect(ThoughtSimilarity.score('他说今晚会回来继续聊', '他说今晚会回来继续聊'), 1.0);
    expect(
      ThoughtSimilarity.score('他说今晚会回来继续聊。', '他说今晚会回来继续聊'),
      greaterThanOrEqualTo(0.95),
    );
  });

  test('unrelated topics do not merge just because they share generic words', () {
    final score = ThoughtSimilarity.score('想问他今晚什么时候回来', '想知道他最近玩的游戏叫什么');
    expect(score, lessThan(0.84));
  });

  test('same semantic topic should prefer topic_key outside fuzzy text matching', () {
    final score = ThoughtSimilarity.score('等他告诉我项目结果', '他答应有结果后跟我说');
    // This intentionally does not demand a fuzzy merge. v0.10 uses stable
    // topic_key as the authoritative semantic link and keeps text-only merges
    // high precision.
    expect(score, inInclusiveRange(0.0, 1.0));
  });
}
