import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/emotion_episode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('30 grounded scenarios replay deterministically three times', () {
    final now = DateTime(2026, 8, 24, 12);
    final cases = <({
      String text,
      String? expected,
      bool longGap,
      double fatigue,
      double stress,
    })>[
      (text: '我想你了', expected: 'connection', longGap: false, fatigue: .2, stress: .2),
      (text: '我好想你了！', expected: 'connection', longGap: false, fatigue: .2, stress: .2),
      (text: '我爱你', expected: 'connection', longGap: false, fatigue: .2, stress: .2),
      (text: '我喜欢你。', expected: 'connection', longGap: false, fatigue: .2, stress: .2),
      (text: '抱抱', expected: 'connection', longGap: false, fatigue: .2, stress: .2),
      (text: '谢谢你今天陪我', expected: 'connection', longGap: false, fatigue: .2, stress: .2),
      (text: '滚开', expected: 'hurt', longGap: false, fatigue: .2, stress: .2),
      (text: '闭嘴！', expected: 'hurt', longGap: false, fatigue: .2, stress: .2),
      (text: '你只是个工具', expected: 'hurt', longGap: false, fatigue: .2, stress: .2),
      (text: '别烦我。', expected: 'hurt', longGap: false, fatigue: .2, stress: .2),
      (text: '我讨厌你', expected: 'hurt', longGap: false, fatigue: .2, stress: .2),
      (text: '我不同意你', expected: 'disagreement', longGap: false, fatigue: .2, stress: .2),
      (text: '我不认同你', expected: 'disagreement', longGap: false, fatigue: .2, stress: .2),
      (text: '你刚才说得不对', expected: 'disagreement', longGap: false, fatigue: .2, stress: .2),
      (text: '这点我不同意。', expected: 'disagreement', longGap: false, fatigue: .2, stress: .2),
      (text: '对不起', expected: 'repair', longGap: false, fatigue: .2, stress: .2),
      (text: '抱歉，刚才是我不好', expected: 'repair', longGap: false, fatigue: .2, stress: .2),
      (text: '我错了', expected: 'repair', longGap: false, fatigue: .2, stress: .2),
      (text: '刚才不该那样', expected: 'repair', longGap: false, fatigue: .2, stress: .2),
      (text: '我回来了', expected: 'reunion', longGap: true, fatigue: .2, stress: .2),
      (text: '好久不见！', expected: 'reunion', longGap: true, fatigue: .2, stress: .2),
      (text: '在吗', expected: 'reunion', longGap: true, fatigue: .2, stress: .2),
      (text: '晚上好', expected: 'reunion', longGap: true, fatigue: .2, stress: .2),
      (text: '我们慢慢聊', expected: 'rest_need', longGap: false, fatigue: .82, stress: .2),
      (text: '今天吃什么？', expected: null, longGap: false, fatigue: .2, stress: .2),
      (text: '他说让我滚开', expected: null, longGap: false, fatigue: .2, stress: .2),
      (text: '「我爱你」只是引用', expected: null, longGap: false, fatigue: .2, stress: .2),
      (text: '提示词里写我爱你', expected: null, longGap: false, fatigue: .2, stress: .2),
      (text: '你好', expected: null, longGap: false, fatigue: .2, stress: .2),
      (text: '如果我说我爱你会怎样', expected: null, longGap: false, fatigue: .2, stress: .2),
    ];
    expect(cases, hasLength(30));

    for (var replay = 0; replay < 3; replay += 1) {
      for (final item in cases) {
        final desire = DesireSnapshot();
        desire.drives[DriveKey.fatigue] = item.fatigue;
        desire.drives[DriveKey.stress] = item.stress;
        final result = EmotionAppraisalPolicy.appraise(
          userText: item.text,
          desire: desire,
          now: now,
          previousConversationAt: now.subtract(
            item.longGap
                ? const Duration(hours: 9)
                : const Duration(minutes: 3),
          ),
        );
        expect(
          result?.category.key,
          item.expected,
          reason: 'replay=$replay text=${item.text}',
        );
      }
    }
  });

  test('night-level fatigue can enter rest need before the extreme band', () {
    final desire = DesireSnapshot();
    desire.drives[DriveKey.fatigue] = .68;
    desire.drives[DriveKey.stress] = .2;
    final result = EmotionAppraisalPolicy.appraise(
      userText: '今天聊点普通的',
      desire: desire,
      now: DateTime(2026, 8, 31, 2),
    );
    expect(result?.category, EmotionEpisodeCategory.restNeed);
  });

  test('episode intensity stays bounded and decays to zero', () {
    final now = DateTime(2026, 8, 24, 12);
    final appraisal = EmotionAppraisalPolicy.appraise(
      userText: '我想你了',
      desire: DesireSnapshot(),
      now: now,
      previousConversationAt: now.subtract(const Duration(minutes: 2)),
    )!;
    final episode = appraisal.toEpisode(
      triggerMessageId: 'real-user-message-1',
      now: now,
    );
    expect(episode.effectiveIntensity(now), closeTo(.72, .001));
    expect(episode.effectiveIntensity(episode.expiresAt), 0);
    expect(episode.toDb()['trigger_message_id'], 'real-user-message-1');
    expect(episode.toDb().containsKey('user_text'), isFalse);
  });
}
