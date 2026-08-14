import 'package:ai_companion_localfirst/core/models/somatic_state.dart';
import 'package:ai_companion_localfirst/core/somatic/somatic_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 15, 12);

  test('daily touch maps a user-to-AI kiss to a stable scene', () {
    final events = SomaticPolicy.detectDailyTouch(
      turnId: 'turn-1',
      text: '过来，让我亲亲你的嘴唇',
      now: now,
    );

    expect(events, hasLength(1));
    expect(events.single.direction, SomaticDirection.userToAi);
    expect(events.single.sceneKey, 'touch__kiss__lips');
    expect(events.single.source, 'user_text');
    expect(events.single.intensity, inInclusiveRange(0.16, 0.94));
  });

  test('non-contact wording and reverse direction do not invent sensation', () {
    expect(
      SomaticPolicy.detectDailyTouch(
        turnId: 'turn-2',
        text: '我只是抱怨一下今天的工作',
        now: now,
      ),
      isEmpty,
    );
    expect(
      SomaticPolicy.detectDailyTouch(
        turnId: 'turn-3',
        text: '你抱我一下',
        now: now,
      ),
      isEmpty,
    );
  });

  test('event identity is deterministic for durable recovery', () {
    final first = SomaticPolicy.detectDailyTouch(
      turnId: 'stable-turn',
      text: '抱抱你',
      now: now,
    ).single;
    final retried = SomaticPolicy.detectDailyTouch(
      turnId: 'stable-turn',
      text: '抱抱你',
      now: now.add(const Duration(minutes: 1)),
    ).single;

    expect(first.id, retried.id);
    expect(first.sceneKey, 'touch__embrace__low_sens');
  });

  test('aggregate decays and prompt hides values below threshold', () {
    final aggregate = SomaticAggregate(
      channel: SomaticChannel.touch,
      value: 0.72,
      sceneKey: 'touch__embrace__low_sens',
      narrative: '被拥抱包围的温度和压力仍留在身体里。',
      lastEventId: 'event-1',
      updatedAt: now,
      expiresAt: now.add(const Duration(minutes: 36)),
    );
    final prompt = SomaticPolicy.formatPrompt([aggregate], now: now);

    expect(prompt, contains('【身体感觉 / INTERNAL SOMATIC STATE】'));
    expect(prompt, contains('被拥抱包围'));
    expect(prompt, isNot(contains('0.72')));
    expect(prompt, contains('不要复述数值'));

    final faded = SomaticPolicy.formatPrompt(
      [aggregate],
      now: now.add(const Duration(minutes: 24)),
    );
    expect(faded, isEmpty);
  });

  test('pulses saturate instead of growing without bound', () {
    final once = SomaticPolicy.mergePulse(0.0, 0.8);
    final twice = SomaticPolicy.mergePulse(once, 0.8);

    expect(once, greaterThan(0));
    expect(twice, greaterThan(once));
    expect(twice, lessThanOrEqualTo(1.0));
  });
}
