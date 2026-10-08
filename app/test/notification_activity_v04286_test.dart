import 'dart:convert';
import 'package:ai_companion_localfirst/core/platform/android_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/perception/notification_activity.dart';
import 'package:ai_companion_localfirst/core/perception/perception_interpreter.dart';

void main() {
  final now = DateTime(2026, 10, 8, 9, 21);
  Map<String, Object?> row(String body, {int seconds = 30, String package = 'com.tencent.mobileqq',
      Map<String, Object?> meta = const {}}) => {
    'source': 'notification', 'app_package': package, 'summary': body,
    'occurred_at': now.subtract(Duration(seconds: seconds)).millisecondsSinceEpoch,
    'metadata_json': jsonEncode({'notification_id': 515, ...meta}),
  };
  test('same-ID updates retain new text but repeated callbacks count once', () {
    final activity = NotificationActivity.collect([
      row('第一条', seconds: 90), row('第一条', seconds: 80),
      row('第二条', seconds: 70), row('第二条', seconds: 60),
    ], now);
    expect(activity.count30m, 2);
    expect(activity.recentCount(now), 2);
    expect(activity.countSince(now.subtract(const Duration(seconds: 75))), 1);
  });
  test('service, grouped summary and promotional callbacks are not chat activity', () {
    final activity = NotificationActivity.collect([
      row('播放中', meta: {'category': 'transport'}),
      row('后台服务', meta: {'ongoing': true}),
      row('前台服务', meta: {'foreground_service': true}),
      row('五条消息', meta: {'group_summary': true}),
      row('优惠', meta: {'category': 'promo'}),
      row('待办', package: 'com.aicompanion.localfirst', meta: {'category': 'msg'}),
      row('未知通知', package: 'unknown.app'),
      row('真正的新消息', meta: {'category': 'msg'}),
    ], now);
    expect(activity.count30m, 1);
    expect(activity.unknownCount, 1);
    expect(activity.ignoredCount, 6);
  });
  test('message timestamps distinguish identical new messages from an old repost', () {
    Map<String, Object?> message(int seconds) => {'messaging_style': true,
      'message_digest': 'same-body', 'message_time': now.subtract(Duration(seconds: seconds)).millisecondsSinceEpoch};
    final activity = NotificationActivity.collect([
      row('你好', meta: message(90)), row('你好', meta: message(90)),
      row('你好', meta: message(40)), row('昨日', meta: message(4000)),
    ], now);
    expect(activity.count30m, 2);
  });
  test('09:06 callbacks cannot describe dense messages at 09:21', () {
    final rows = [for (var i = 0; i < 8; i++) row('private-$i', seconds: 900 + i)];
    expect(NotificationActivity.collect(rows, now).count30m, 8);
    expect(NotificationActivity.collect(rows, now).recentCount(now), 0);
    final result = const PerceptionInterpreter().interpret(usage: const [],
      recentSignals: rows, deviceStateEvents: const [], now: now,
      deviceState: const DevicePerceptionState(usageAccess: false, screenInteractive: false,
        deviceLocked: true, notificationListenerConnected: true, accessibilityConnected: false));
    expect(result.observations.any((o) => o.kind == 'notification_burst'), false);
    expect(result.observations.map((o) => o.summary).join(), isNot(contains('次新的聊天通知内容')));
  });
  test('fresh arrival evidence expires promptly and never exposes message bodies', () {
    final result = const PerceptionInterpreter().interpret(usage: const [],
      recentSignals: [for (var i = 0; i < 5; i++) row('private-$i', seconds: i + 1)],
      deviceStateEvents: const [], now: now,
      deviceState: const DevicePerceptionState(usageAccess: false, screenInteractive: false,
        deviceLocked: true, notificationListenerConnected: true, accessibilityConnected: false));
    final observation = result.observations.singleWhere((o) => o.summary.contains('次新的聊天通知内容'));
    expect(observation.summary, contains('不代表你正在回复或忙碌'));
    expect(observation.summary, isNot(contains('private')));
    expect(observation.expiresAt.difference(now), const Duration(minutes: 3));
  });
  test('unknown, malformed and future rows do not invent communication', () {
    final rows = [row('未来', seconds: -1), row('过旧', seconds: 1801),
      {...row('未知', package: 'unknown'), 'metadata_json': 'invalid-json'},
      {'source': 'notification', 'summary': 'no timestamp'}];
    expect(NotificationActivity.collect(rows, now).count30m, 0);
  });
}
