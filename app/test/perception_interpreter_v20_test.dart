import 'package:ai_companion_localfirst/core/perception/perception_interpreter.dart';
import 'package:ai_companion_localfirst/core/platform/android_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const interpreter = PerceptionInterpreter();
  final now = DateTime(2026, 8, 11, 14, 0);

  test('sustained game usage becomes human-level awareness without package leak', () {
    final usage = <UsageEventInfo>[
      UsageEventInfo(
        packageName: 'com.example.secret.game',
        timestamp: now.subtract(const Duration(minutes: 55)),
        eventType: 'foreground',
        appCategory: 'game',
        appLabel: '原神',
      ),
    ];
    final result = interpreter.interpret(
      usage: usage,
      recentSignals: const [],
      deviceStateEvents: const [],
      deviceState: const DevicePerceptionState(
        usageAccess: true,
        screenInteractive: true,
        deviceLocked: false,
        notificationListenerConnected: false,
        accessibilityConnected: false,
      ),
      now: now,
    );

    final joined = result.observations.map((e) => e.summary).join('\n');
    expect(joined, contains('玩游戏'));
    expect(joined, contains('当前打开的是 原神'));
    expect(joined, isNot(contains('com.example.secret.game')));
    expect(result.currentAppLabel, '原神');
    expect(result.currentActivityKey, 'game');
    expect(result.currentActivityLabel, '游戏');
    expect(result.dominantActivityKey, 'game');
  });


  test('financial app label is visible while raw package and screen text stay absent', () {
    final result = interpreter.interpret(
      usage: [
        UsageEventInfo(
          packageName: 'com.example.wallet.private',
          timestamp: now.subtract(const Duration(minutes: 2)),
          eventType: 'foreground',
          appCategory: 'unknown',
          appLabel: '支付宝',
        ),
      ],
      recentSignals: const [],
      deviceStateEvents: const [],
      deviceState: const DevicePerceptionState(
        usageAccess: true,
        screenInteractive: true,
        deviceLocked: false,
        notificationListenerConnected: false,
        accessibilityConnected: false,
      ),
      now: now,
    );

    final joined = result.observations.map((e) => e.summary).join('\n');
    expect(joined, contains('当前打开的是 支付宝'));
    expect(joined, isNot(contains('com.example.wallet.private')));
    expect(result.currentAppLabel, '支付宝');
  });

  test('screen off observation is explicit but uncertain about user activity', () {
    final offAt = now.subtract(const Duration(minutes: 25));
    final result = interpreter.interpret(
      usage: const [],
      recentSignals: const [],
      deviceStateEvents: [
        {
          'event_type': 'screen_off',
          'occurred_at': offAt.millisecondsSinceEpoch,
        }
      ],
      deviceState: const DevicePerceptionState(
        usageAccess: false,
        screenInteractive: false,
        deviceLocked: true,
        notificationListenerConnected: false,
        accessibilityConnected: false,
      ),
      now: now,
    );

    final screen = result.observations.singleWhere((e) => e.dedupeKey == 'screen_state');
    expect(screen.summary, contains('可能'));
    expect(screen.expiresAt.difference(now), const Duration(minutes: 10));
    expect(result.currentActivityKey, isNull);
  });

  test('raw notification and accessibility text never appears in observations', () {
    final signals = List<Map<String, Object?>>.generate(8, (index) => {
          'source': index < 5 ? 'notification' : 'accessibility',
          'summary': index < 5 ? 'private notification text $index' : 'private page text $index',
        });
    final result = interpreter.interpret(
      usage: const [],
      recentSignals: signals,
      deviceStateEvents: const [],
      deviceState: const DevicePerceptionState(
        usageAccess: false,
        screenInteractive: true,
        deviceLocked: false,
        notificationListenerConnected: true,
        accessibilityConnected: true,
      ),
      now: now,
    );
    final joined = result.observations.map((e) => e.summary).join('\n');
    expect(joined, isNot(contains('private notification text')));
    expect(joined, isNot(contains('private page text')));
    expect(joined, contains('通知比较密集'));
  });
}
