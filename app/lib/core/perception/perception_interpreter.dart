import 'dart:math';

import '../models/awareness_observation.dart';
import '../platform/android_bridge.dart';

class PerceptionInterpretation {
  const PerceptionInterpretation({
    required this.observations,
    required this.managedKeys,
    required this.busyScore,
    required this.notificationCount,
    required this.accessibilityEventCount,
    this.dominantActivityKey,
    this.dominantActivityLabel,
    this.dominantActivityMinutes = 0,
    this.appSwitchesLast30Minutes = 0,
  });

  final List<AwarenessObservationDraft> observations;
  final Set<String> managedKeys;
  final double busyScore;
  final int notificationCount;
  final int accessibilityEventCount;
  final String? dominantActivityKey;
  final String? dominantActivityLabel;
  final int dominantActivityMinutes;
  final int appSwitchesLast30Minutes;
}

/// Pure local interpretation. No model/API call is used here.
///
/// Package names and external text are allowed as temporary inputs for local
/// classification, but observation summaries never contain those raw values.
class PerceptionInterpreter {
  const PerceptionInterpreter();

  static const Set<String> usageManagedKeys = {
    'current_activity',
    'recent_activity',
    'app_switching',
    'availability',
  };

  static const Set<String> deviceManagedKeys = {
    'screen_state',
  };

  static const Set<String> notificationManagedKeys = {
    'notification_pressure',
  };

  PerceptionInterpretation interpret({
    required List<UsageEventInfo> usage,
    required List<Map<String, Object?>> recentSignals,
    required List<Map<String, Object?>> deviceStateEvents,
    required DevicePerceptionState deviceState,
    required DateTime now,
  }) {
    final facts = _summarizeUsage(usage, now);
    final signalFacts = _summarizeSignals(recentSignals);
    final observations = <AwarenessObservationDraft>[];
    final managed = <String>{...deviceManagedKeys};

    if (deviceState.usageAccess) {
      managed.addAll(usageManagedKeys);
      _addUsageObservations(observations, facts, now);
    }
    if (deviceState.notificationListenerConnected) {
      managed.addAll(notificationManagedKeys);
      _addNotificationObservation(observations, signalFacts, now);
    }
    _addScreenObservation(
      observations,
      deviceState: deviceState,
      deviceStateEvents: deviceStateEvents,
      now: now,
    );

    final busyScore = _busyScore(
      usage: facts,
      signals: signalFacts,
      deviceState: deviceState,
      now: now,
    );
    if (deviceState.usageAccess && deviceState.screenInteractive && busyScore >= 0.56) {
      observations.add(
        AwarenessObservationDraft(
          kind: 'availability',
          summary: busyScore >= 0.74
              ? '现在大概比较忙，适合低打扰地联系。'
              : '现在可能有点忙，联系时更适合轻一点。',
          confidence: (0.58 + (busyScore - 0.56) * 0.9).clamp(0.58, 0.86).toDouble(),
          windowStart: now.subtract(const Duration(minutes: 15)),
          windowEnd: now,
          expiresAt: now.add(const Duration(minutes: 12)),
          dedupeKey: 'availability',
          sourceFingerprint: 'busy:${(busyScore * 10).round()}',
          metadata: {'busy_score': busyScore},
        ),
      );
    }

    return PerceptionInterpretation(
      observations: observations,
      managedKeys: managed,
      busyScore: busyScore,
      notificationCount: signalFacts.notificationCount,
      accessibilityEventCount: signalFacts.accessibilityEventCount,
      dominantActivityKey: facts.dominantCategory,
      dominantActivityLabel: facts.dominantCategory == null
          ? null
          : _activityLabel(facts.dominantCategory!),
      dominantActivityMinutes: facts.dominantMinutes,
      appSwitchesLast30Minutes: facts.switchesLast30Minutes,
    );
  }

  void _addUsageObservations(
    List<AwarenessObservationDraft> out,
    _UsageFacts facts,
    DateTime now,
  ) {
    final current = facts.currentCategory;
    if (current != null && current != 'unknown') {
      out.add(
        AwarenessObservationDraft(
          kind: 'current_activity',
          summary: '现在大概在${_activityPhrase(current)}。',
          confidence: 0.74,
          windowStart: facts.currentStartedAt ?? now.subtract(const Duration(minutes: 4)),
          windowEnd: now,
          expiresAt: now.add(const Duration(minutes: 12)),
          dedupeKey: 'current_activity',
          sourceFingerprint: 'current:$current',
          metadata: {'activity': current},
        ),
      );
    }

    final dominant = facts.dominantCategory;
    if (dominant != null && facts.dominantMinutes >= 20 && facts.dominantShare >= 0.42) {
      final confidence = (0.56 + facts.dominantShare * 0.35 + min(45, facts.dominantMinutes) / 500)
          .clamp(0.60, 0.90)
          .toDouble();
      final phrase = dominant == 'unknown'
          ? '持续使用手机'
          : '主要在${_activityPhrase(dominant)}';
      out.add(
        AwarenessObservationDraft(
          kind: 'recent_activity',
          summary: '最近一段时间$phrase。',
          confidence: confidence,
          windowStart: now.subtract(const Duration(minutes: 90)),
          windowEnd: now,
          expiresAt: now.add(const Duration(minutes: 75)),
          dedupeKey: 'recent_activity',
          sourceFingerprint:
              'recent:$dominant:${_bucket(facts.dominantMinutes, 10)}:${_bucket((facts.dominantShare * 100).round(), 10)}',
          metadata: {
            'activity': dominant,
            'minutes': facts.dominantMinutes,
            'share': facts.dominantShare,
          },
        ),
      );
    }

    if (facts.switchesLast30Minutes >= 9) {
      final confidence = (0.58 + (facts.switchesLast30Minutes - 9) * 0.025)
          .clamp(0.58, 0.82)
          .toDouble();
      out.add(
        AwarenessObservationDraft(
          kind: 'app_switching',
          summary: '最近切换应用比较频繁，像是在同时处理几件事。',
          confidence: confidence,
          windowStart: now.subtract(const Duration(minutes: 30)),
          windowEnd: now,
          expiresAt: now.add(const Duration(minutes: 25)),
          dedupeKey: 'app_switching',
          sourceFingerprint: 'switches:${_bucket(facts.switchesLast30Minutes, 3)}',
          metadata: {'switches_30m': facts.switchesLast30Minutes},
        ),
      );
    }
  }

  void _addNotificationObservation(
    List<AwarenessObservationDraft> out,
    _SignalFacts signals,
    DateTime now,
  ) {
    if (signals.notificationCount < 5) return;
    final confidence = (0.54 + min(12, signals.notificationCount) * 0.02)
        .clamp(0.56, 0.78)
        .toDouble();
    out.add(
      AwarenessObservationDraft(
        kind: 'notification_pressure',
        summary: '近期通知比较密集，可能同时有不少事情在找你。',
        confidence: confidence,
        windowStart: now.subtract(const Duration(minutes: 30)),
        windowEnd: now,
        expiresAt: now.add(const Duration(minutes: 20)),
        dedupeKey: 'notification_pressure',
        sourceFingerprint: 'notifications:${_bucket(signals.notificationCount, 3)}',
        metadata: {'count_30m': signals.notificationCount},
      ),
    );
  }

  void _addScreenObservation(
    List<AwarenessObservationDraft> out, {
    required DevicePerceptionState deviceState,
    required List<Map<String, Object?>> deviceStateEvents,
    required DateTime now,
  }) {
    if (deviceState.screenInteractive) {
      return;
    }
    DateTime? lastOff;
    for (final row in deviceStateEvents) {
      if ((row['event_type'] as String? ?? '') != 'screen_off') continue;
      final millis = (row['occurred_at'] as num?)?.toInt();
      if (millis == null) continue;
      final value = DateTime.fromMillisecondsSinceEpoch(millis);
      if (lastOff == null || value.isAfter(lastOff)) lastOff = value;
    }
    final offFor = lastOff == null ? null : now.difference(lastOff);
    final minutes = offFor?.inMinutes;
    final summary = minutes != null && minutes >= 15
        ? '屏幕已经熄灭一段时间，可能在休息或暂时离开手机。'
        : '屏幕现在是熄灭的，可能暂时没有在看手机。';
    out.add(
      AwarenessObservationDraft(
        kind: 'screen_state',
        summary: summary,
        confidence: lastOff == null ? 0.72 : 0.91,
        windowStart: lastOff ?? now,
        windowEnd: now,
        expiresAt: now.add(const Duration(minutes: 10)),
        dedupeKey: 'screen_state',
        sourceFingerprint: minutes == null
            ? 'screen:off'
            : 'screen:off:${_bucket(minutes, 10)}',
        metadata: {
          if (minutes != null) 'off_minutes': minutes,
          'locked': deviceState.deviceLocked,
        },
      ),
    );
  }

  _UsageFacts _summarizeUsage(List<UsageEventInfo> events, DateTime now) {
    if (events.isEmpty) return const _UsageFacts();
    final sorted = [...events]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final starts = <String, DateTime>{};
    final categoryByPackage = <String, String>{};
    final durationsByCategory = <String, int>{};
    String? currentPackage;
    String? currentCategory;
    DateTime? currentStartedAt;
    String? lastForegroundPackage;
    var switchesLast30 = 0;
    final switchSince = now.subtract(const Duration(minutes: 30));

    for (final event in sorted) {
      final category = _resolvedCategory(event);
      categoryByPackage[event.packageName] = category;
      if (event.eventType == 'foreground') {
        starts[event.packageName] = event.timestamp;
        currentPackage = event.packageName;
        currentCategory = category;
        currentStartedAt = event.timestamp;
        if (!event.timestamp.isBefore(switchSince) &&
            lastForegroundPackage != null &&
            lastForegroundPackage != event.packageName) {
          switchesLast30++;
        }
        lastForegroundPackage = event.packageName;
      } else if (event.eventType == 'background') {
        final start = starts.remove(event.packageName);
        if (start != null && event.timestamp.isAfter(start)) {
          final minutes = event.timestamp.difference(start).inMinutes;
          final key = categoryByPackage[event.packageName] ?? category;
          durationsByCategory[key] = (durationsByCategory[key] ?? 0) + minutes;
        }
        if (currentPackage == event.packageName) {
          currentPackage = null;
          currentCategory = null;
          currentStartedAt = null;
        }
      }
    }
    for (final entry in starts.entries) {
      final minutes = now.difference(entry.value).inMinutes.clamp(0, 90).toInt();
      final key = categoryByPackage[entry.key] ?? 'unknown';
      durationsByCategory[key] = (durationsByCategory[key] ?? 0) + minutes;
    }

    final entries = durationsByCategory.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    final dominant = entries.isEmpty ? null : entries.first;
    return _UsageFacts(
      currentCategory: currentCategory,
      currentStartedAt: currentStartedAt,
      durationsByCategory: {for (final e in entries) e.key: e.value},
      switchesLast30Minutes: switchesLast30,
      dominantCategory: dominant?.key,
      dominantMinutes: dominant?.value ?? 0,
      dominantShare: dominant == null || total <= 0 ? 0 : dominant.value / total,
    );
  }

  _SignalFacts _summarizeSignals(List<Map<String, Object?>> rows) {
    var notifications = 0;
    var accessibility = 0;
    for (final row in rows) {
      switch (row['source'] as String? ?? '') {
        case 'notification':
          notifications++;
          break;
        case 'accessibility':
          accessibility++;
          break;
      }
    }
    return _SignalFacts(
      notificationCount: notifications,
      accessibilityEventCount: accessibility,
    );
  }

  double _busyScore({
    required _UsageFacts usage,
    required _SignalFacts signals,
    required DevicePerceptionState deviceState,
    required DateTime now,
  }) {
    if (!deviceState.screenInteractive) return 0.12;
    var score = 0.10;
    if (usage.currentCategory != null) score += 0.24;
    score += (usage.dominantMinutes / 90 * 0.30).clamp(0.0, 0.30);
    score += (usage.switchesLast30Minutes / 18 * 0.18).clamp(0.0, 0.18);
    score += (signals.notificationCount / 12 * 0.12).clamp(0.0, 0.12);
    score += (signals.accessibilityEventCount / 35 * 0.08).clamp(0.0, 0.08);
    if (deviceState.deviceLocked) score -= 0.08;
    final hour = now.hour;
    if (hour >= 0 && hour < 7) score -= 0.08;
    return score.clamp(0.0, 1.0).toDouble();
  }

  String _resolvedCategory(UsageEventInfo event) {
    final native = event.appCategory.trim().toLowerCase();
    if (native.isNotEmpty && native != 'unknown') return native;
    final p = event.packageName.toLowerCase();
    if (_containsAny(p, const ['youtube', 'bilibili', 'douyin', 'tiktok', 'netflix', 'video'])) {
      return 'video';
    }
    if (_containsAny(p, const ['spotify', 'music', 'podcast', 'audio'])) return 'audio';
    if (_containsAny(p, const ['chrome', 'browser', 'firefox', 'edge'])) return 'browser';
    if (_containsAny(p, const ['wechat', 'weixin', 'telegram', 'discord', 'whatsapp', 'instagram', 'twitter', 'facebook', 'reddit'])) {
      return 'social';
    }
    if (_containsAny(p, const ['maps', 'map', 'navigation'])) return 'maps';
    return 'unknown';
  }

  bool _containsAny(String value, List<String> fragments) =>
      fragments.any(value.contains);

  String _activityPhrase(String category) => switch (category) {
        'game' => '玩游戏',
        'audio' => '听音乐或音频',
        'video' => '看视频',
        'image' => '看图片',
        'social' => '社交或聊天',
        'news' => '看资讯',
        'maps' => '使用地图或导航',
        'productivity' => '使用工作或学习类应用',
        'browser' => '浏览网页',
        _ => '使用手机',
      };

  String _activityLabel(String category) => switch (category) {
        'game' => '游戏',
        'audio' => '音频',
        'video' => '视频',
        'image' => '图片',
        'social' => '社交或聊天',
        'news' => '资讯',
        'maps' => '地图或导航',
        'productivity' => '工作或学习',
        'browser' => '网页浏览',
        _ => '手机使用',
      };

  int _bucket(int value, int size) => (value ~/ size) * size;
}

class _UsageFacts {
  const _UsageFacts({
    this.currentCategory,
    this.currentStartedAt,
    this.durationsByCategory = const {},
    this.switchesLast30Minutes = 0,
    this.dominantCategory,
    this.dominantMinutes = 0,
    this.dominantShare = 0,
  });

  final String? currentCategory;
  final DateTime? currentStartedAt;
  final Map<String, int> durationsByCategory;
  final int switchesLast30Minutes;
  final String? dominantCategory;
  final int dominantMinutes;
  final double dominantShare;
}

class _SignalFacts {
  const _SignalFacts({
    this.notificationCount = 0,
    this.accessibilityEventCount = 0,
  });

  final int notificationCount;
  final int accessibilityEventCount;
}
