import 'dart:math';

import '../platform/android_bridge.dart';

/// Evidence since the last successful perception, never a rolling-window sum.
/// An unlock only establishes a baseline. It does not delay other motives.
class PhoneActivityEvidence {
  const PhoneActivityEvidence({
    required this.reset,
    required this.reason,
    this.activeMinutes = 0,
    this.switches = 0,
    this.accessibilityEvents = 0,
  });

  final bool reset;
  final String reason;
  final double activeMinutes;
  final int switches;
  final int accessibilityEvents;

  static const maximumGap = Duration(minutes: 30);

  static PhoneActivityEvidence collect({
    required DateTime now,
    required DateTime? previousAt,
    required bool wasInteractive,
    required bool interactive,
    required List<UsageEventInfo> usage,
    required List<Map<String, Object?>> deviceEvents,
    required List<Map<String, Object?>> signals,
  }) {
    if (!interactive) {
      return const PhoneActivityEvidence(
        reset: true,
        reason: 'not_interactive',
      );
    }
    if (previousAt == null ||
        !wasInteractive ||
        !now.isAfter(previousAt) ||
        now.difference(previousAt) > maximumGap) {
      return const PhoneActivityEvidence(
        reset: true,
        reason: 'capture_baseline',
      );
    }
    final since = previousAt.millisecondsSinceEpoch;
    final until = now.millisecondsSinceEpoch;
    for (final event in deviceEvents) {
      final at = (event['occurred_at'] as num?)?.toInt() ?? 0;
      if (at > since &&
          at <= until &&
          const {
            'screen_off',
            'screen_on',
            'user_present',
          }.contains(event['event_type'])) {
        return const PhoneActivityEvidence(
          reset: true,
          reason: 'screen_session_changed',
        );
      }
    }

    final events = usage.where((e) => !e.timestamp.isAfter(now)).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    String? foreground;
    String? lastForeground;
    var cursor = previousAt;
    var activeMillis = 0;
    var switches = 0;
    for (final event in events) {
      if (event.timestamp.isAfter(previousAt)) {
        if (foreground != null) {
          activeMillis += max(
            0,
            event.timestamp.difference(cursor).inMilliseconds,
          );
        }
        cursor = event.timestamp;
      }
      if (event.eventType == 'foreground') {
        if (event.timestamp.isAfter(previousAt) &&
            lastForeground != null &&
            lastForeground != event.packageName) {
          switches++;
        }
        foreground = event.packageName;
        lastForeground = event.packageName;
      } else if (event.eventType == 'background' &&
          foreground == event.packageName) {
        foreground = null;
      }
    }
    if (foreground != null) {
      activeMillis += max(0, now.difference(cursor).inMilliseconds);
    }
    final accessibility = signals.where((event) {
      final at = (event['occurred_at'] as num?)?.toInt() ?? 0;
      return event['source'] == 'accessibility' && at > since && at <= until;
    }).length;
    return PhoneActivityEvidence(
      reset: false,
      reason: 'fresh_interval',
      activeMinutes:
          min(activeMillis, now.difference(previousAt).inMilliseconds) / 60000,
      switches: switches,
      accessibilityEvents: accessibility,
    );
  }
}
