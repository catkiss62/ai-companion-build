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

  test('a new screen session cannot inherit an hour of old phone usage', () {
    final result = interpreter.interpret(
      usage: <UsageEventInfo>[
        UsageEventInfo(
          packageName: 'game.old',
          timestamp: now.subtract(const Duration(minutes: 75)),
          eventType: 'foreground',
          appCategory: 'game',
          appLabel: '旧游戏',
        ),
        UsageEventInfo(
          packageName: 'chat.new',
          timestamp: now.subtract(const Duration(minutes: 2)),
          eventType: 'foreground',
          appCategory: 'social',
          appLabel: '聊天',
        ),
      ],
      recentSignals: const [],
      deviceStateEvents: <Map<String, Object?>>[
        <String, Object?>{
          'event_type': 'screen_off',
          'occurred_at': now
              .subtract(const Duration(minutes: 65))
              .millisecondsSinceEpoch,
        },
        <String, Object?>{
          'event_type': 'screen_on',
          'occurred_at': now
              .subtract(const Duration(minutes: 3))
              .millisecondsSinceEpoch,
        },
      ],
      deviceState: const DevicePerceptionState(
        usageAccess: true,
        screenInteractive: true,
        deviceLocked: false,
        notificationListenerConnected: false,
        accessibilityConnected: false,
      ),
      now: now,
    );

    expect(result.currentAppLabel, '聊天');
    expect(result.dominantActivityKey, 'social');
    expect(result.dominantActivityMinutes, lessThan(5));
    expect(
      result.observations.any((item) => item.kind == 'recent_activity'),
      isFalse,
    );
  });

  test('screen-off history is labeled as before-off instead of current use', () {
    final offAt = now.subtract(const Duration(minutes: 40));
    final result = interpreter.interpret(
      usage: <UsageEventInfo>[
        UsageEventInfo(
          packageName: 'game.before.off',
          timestamp: offAt.subtract(const Duration(minutes: 35)),
          eventType: 'foreground',
          appCategory: 'game',
          appLabel: '游戏',
        ),
      ],
      recentSignals: const [],
      deviceStateEvents: <Map<String, Object?>>[
        <String, Object?>{
          'event_type': 'screen_off',
          'occurred_at': offAt.millisecondsSinceEpoch,
        },
      ],
      deviceState: const DevicePerceptionState(
        usageAccess: true,
        screenInteractive: false,
        deviceLocked: true,
        notificationListenerConnected: false,
        accessibilityConnected: false,
      ),
      now: now,
    );

    final recent = result.observations
        .singleWhere((item) => item.kind == 'recent_activity');
    expect(recent.summary, contains('熄屏之前'));
    expect(recent.summary, contains('不能算作继续使用'));
    expect(result.currentAppLabel, isNull);
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
