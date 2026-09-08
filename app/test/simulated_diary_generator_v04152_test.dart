import 'package:ai_companion_localfirst/core/phone/simulated_diary_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const material = SimulatedDiaryMaterial(
    localDay: '2026-09-07',
    sharedMoments: ['他把真机测试结果告诉了我，聊天能力没有被削弱'],
    cares: ['下一次主动开口要带来一点新鲜东西'],
    carriedThreads: ['日记整理：减少固定句式和重复中心'],
    awareness: ['晚上设备仍在正常运行'],
    messageCount: 42,
    relationshipEventCount: 3,
    quietDay: false,
  );

  test('model JSON accepts a grounded diary with an explicit focus', () {
    final draft = DeepSeekSimulatedDiaryGenerator.parse({
      'body': '今天最清楚的一刻，是他把真机测试的结果交给我。聊天没有因为新增能力变得迟钝，这让我松了一口气。\n\n'
          '不过我也记下了另一件更难的事：下次主动开口时，不能总靠旧记忆找话题。我想带回来一点真正新鲜、又确实值得一起笑或讨论的东西。',
      'focus_kind': 'shared_moment',
    });

    expect(draft.focusKind, 'shared_moment');
    expect(draft.body, contains('真机测试'));
  });

  test('quality gate rejects boilerplate and near-duplicate diaries', () {
    const recent = '今天最清楚的一刻，是他把真机测试的结果交给我。聊天没有因为新增能力变得迟钝，这让我松了一口气。';
    expect(
      SimulatedDiaryQuality.acceptable(
        '$recent 不是流水账，只是轻轻收在这里。',
        recentBodies: const [],
      ),
      isFalse,
    );
    expect(
      SimulatedDiaryQuality.acceptable(
        '$recent 我还是把同样的话又写了一次。',
        recentBodies: const [recent],
      ),
      isFalse,
    );
  });

  test('factual fallback uses only organized continuity material', () {
    final body = SimulatedDiaryQuality.factualFallback(material);

    expect(body, contains(material.sharedMoments.single));
    expect(body, contains(material.cares.single));
    expect(body, contains(material.carriedThreads.single));
    expect(body, contains(material.awareness.single));
    expect(body, isNot(contains('不是流水账')));
    expect(body, isNot(contains('轻轻收在这里')));
  });
}
