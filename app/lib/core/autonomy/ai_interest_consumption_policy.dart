import 'dart:math';

import 'ai_interest_evidence_policy.dart';

enum AiInterestConsumptionMode {
  exploit('exploit'),
  adjacent('adjacent'),
  wildcard('wildcard');

  const AiInterestConsumptionMode(this.key);
  final String key;

  static AiInterestConsumptionMode? fromKey(String key) {
    for (final value in values) {
      if (value.key == key) return value;
    }
    return null;
  }
}

enum AiInterestConsumptionSurface {
  publicWeb('public_web'),
  proactive('proactive');

  const AiInterestConsumptionSurface(this.key);
  final String key;
}

class AiInterestConsumptionCandidate {
  const AiInterestConsumptionCandidate({
    required this.id,
    required this.interestKey,
    required this.label,
    required this.sourceDomain,
    required this.status,
    required this.confidence,
    required this.freshness,
    required this.version,
    required this.lastEvidenceAt,
  });

  final String id;
  final String interestKey;
  final String label;
  final String sourceDomain;
  final String status;
  final double confidence;
  final double freshness;
  final int version;
  final DateTime? lastEvidenceAt;
}

class AiInterestConsumptionEvent {
  const AiInterestConsumptionEvent({
    required this.candidateId,
    required this.mode,
    required this.surface,
    required this.status,
    required this.createdAt,
  });

  final String candidateId;
  final String mode;
  final String surface;
  final String status;
  final DateTime createdAt;

  bool get completed => status == 'completed';
}

class AiInterestConsumptionPlan {
  const AiInterestConsumptionPlan({
    required this.candidate,
    required this.mode,
    required this.surface,
  });

  final AiInterestConsumptionCandidate candidate;
  final AiInterestConsumptionMode mode;
  final AiInterestConsumptionSurface surface;

  String get safeLabel => AiInterestConsumptionPolicy.safeData(label: candidate.label);

  String get safeDomain =>
      AiInterestConsumptionPolicy.safeData(label: candidate.sourceDomain);

  Map<String, Object?> toPlannerJson() => <String, Object?>{
        'mode': mode.key,
        'label': safeLabel,
        'public_domain': safeDomain,
      };

  String promptHint() {
    final topic = safeLabel.isNotEmpty ? safeLabel : safeDomain;
    if (topic.isEmpty) return '';
    return switch (mode) {
      AiInterestConsumptionMode.exploit =>
        '本轮可把“$topic”当作一个已经由跨日期真实自主证据形成的成熟兴趣，'
            '自然挑一个具体的新角度；它只是轻量偏向，不是必须提及的人设标签。',
      AiInterestConsumptionMode.adjacent =>
        '本轮可从成熟兴趣“$topic”向相邻但不同的公开主题走一步，'
            '避免复述旧结论；找不到自然连接就输出 WAIT。',
      AiInterestConsumptionMode.wildcard =>
        '本轮允许把成熟兴趣“$topic”只当作很远的跳板，出现一次意外但合理的联想；'
            '不要硬解释关联，也不要为了命中兴趣而固定口头禅。',
    };
  }
}

/// Phase 3C consumes only the current, established candidate snapshot.
/// It does not create Desire or bypass any tool/delivery gate; callers ask for
/// a plan only after the existing behavior has already won its normal lane.
class AiInterestConsumptionPolicy {
  const AiInterestConsumptionPolicy._();

  static const window = Duration(hours: 24);
  static const candidateCooldown = Duration(hours: 12);
  static const minimumFreshness = 0.25;

  static const Map<AiInterestConsumptionMode, int> dailyLimits =
      <AiInterestConsumptionMode, int>{
    AiInterestConsumptionMode.exploit: 2,
    AiInterestConsumptionMode.adjacent: 1,
    AiInterestConsumptionMode.wildcard: 1,
  };

  static const Map<AiInterestConsumptionMode, Duration> modeCooldowns =
      <AiInterestConsumptionMode, Duration>{
    AiInterestConsumptionMode.exploit: Duration(hours: 6),
    AiInterestConsumptionMode.adjacent: Duration(hours: 12),
    AiInterestConsumptionMode.wildcard: Duration(hours: 24),
  };

  static const Map<AiInterestConsumptionSurface, int> surfaceLimits =
      <AiInterestConsumptionSurface, int>{
    AiInterestConsumptionSurface.publicWeb: 3,
    AiInterestConsumptionSurface.proactive: 2,
  };

  static bool eligible(
    AiInterestConsumptionCandidate candidate, {
    required DateTime now,
  }) {
    if (candidate.status != AiInterestStatus.established.key ||
        candidate.id.trim().isEmpty ||
        candidate.interestKey.trim().isEmpty ||
        candidate.version < 1 ||
        candidate.confidence < AiInterestEvidencePolicy.establishedConfidence ||
        candidate.lastEvidenceAt == null ||
        (safeData(label: candidate.label).isEmpty &&
            safeData(label: candidate.sourceDomain).isEmpty)) {
      return false;
    }
    final liveFreshness = const AiInterestEvidencePolicy()
        .freshnessAt(candidate.lastEvidenceAt, now);
    return min(candidate.freshness, liveFreshness) >= minimumFreshness;
  }

  static bool completionAllowed({
    required AiInterestConsumptionPlan plan,
    required List<AiInterestConsumptionEvent> recentEvents,
    required DateTime now,
  }) {
    if (!eligible(plan.candidate, now: now)) return false;
    final since = now.subtract(window);
    final completed = recentEvents.where(
      (event) =>
          event.completed &&
          !event.createdAt.isBefore(since) &&
          !event.createdAt.isAfter(now),
    );
    if (completed.where((event) => event.surface == plan.surface.key).length >=
        (surfaceLimits[plan.surface] ?? 0)) {
      return false;
    }
    final sameMode = completed
        .where((event) => event.mode == plan.mode.key)
        .toList(growable: false);
    if (sameMode.length >= (dailyLimits[plan.mode] ?? 0)) return false;
    if (sameMode.isNotEmpty) {
      final latest = sameMode
          .map((event) => event.createdAt)
          .reduce((left, right) => left.isAfter(right) ? left : right);
      if (now.difference(latest) < (modeCooldowns[plan.mode] ?? window)) {
        return false;
      }
    }
    return completed
        .where((event) => event.candidateId == plan.candidate.id)
        .every(
          (event) => now.difference(event.createdAt) >= candidateCooldown,
        );
  }

  static AiInterestConsumptionPlan? select({
    required List<AiInterestConsumptionCandidate> candidates,
    required List<AiInterestConsumptionEvent> recentEvents,
    required AiInterestConsumptionSurface surface,
    required DateTime now,
    required double modeUnit,
    required double candidateUnit,
  }) {
    final since = now.subtract(window);
    final completed = recentEvents
        .where((event) =>
            event.completed &&
            !event.createdAt.isBefore(since) &&
            !event.createdAt.isAfter(now))
        .toList(growable: false);
    final surfaceLimit = surfaceLimits[surface] ?? 0;
    if (completed.where((event) => event.surface == surface.key).length >=
        surfaceLimit) {
      return null;
    }

    final availableModes = AiInterestConsumptionMode.values.where((mode) {
      final events = completed.where((event) => event.mode == mode.key).toList();
      if (events.length >= (dailyLimits[mode] ?? 0)) return false;
      if (events.isEmpty) return true;
      final latest = events
          .map((event) => event.createdAt)
          .reduce((left, right) => left.isAfter(right) ? left : right);
      return now.difference(latest) >= (modeCooldowns[mode] ?? window);
    }).toList(growable: false);
    if (availableModes.isEmpty) return null;

    final mode = _weightedMode(availableModes, modeUnit);
    final usable = candidates.where((candidate) {
      if (!eligible(candidate, now: now)) return false;
      final sameCandidate = completed.where(
        (event) => event.candidateId == candidate.id,
      );
      return sameCandidate.every(
        (event) => now.difference(event.createdAt) >= candidateCooldown,
      );
    }).toList(growable: false);
    if (usable.isEmpty) return null;
    usable.sort((left, right) {
      final leftScore = left.confidence * left.freshness;
      final rightScore = right.confidence * right.freshness;
      final byScore = rightScore.compareTo(leftScore);
      if (byScore != 0) return byScore;
      return left.id.compareTo(right.id);
    });
    final weights = usable
        .map((candidate) =>
            max(0.05, candidate.confidence * candidate.freshness).toDouble())
        .toList(growable: false);
    final total = weights.fold<double>(0, (sum, value) => sum + value);
    var cursor = candidateUnit.clamp(0.0, 0.999999999).toDouble() * total;
    var picked = usable.last;
    for (var index = 0; index < usable.length; index++) {
      cursor -= weights[index];
      if (cursor < 0) {
        picked = usable[index];
        break;
      }
    }
    return AiInterestConsumptionPlan(
      candidate: picked,
      mode: mode,
      surface: surface,
    );
  }

  static AiInterestConsumptionMode _weightedMode(
    List<AiInterestConsumptionMode> available,
    double unit,
  ) {
    const weights = <AiInterestConsumptionMode, double>{
      AiInterestConsumptionMode.exploit: 0.55,
      AiInterestConsumptionMode.adjacent: 0.30,
      AiInterestConsumptionMode.wildcard: 0.15,
    };
    final total = available.fold<double>(
      0,
      (sum, mode) => sum + (weights[mode] ?? 0),
    );
    var cursor = unit.clamp(0.0, 0.999999999).toDouble() * total;
    for (final mode in available) {
      cursor -= weights[mode] ?? 0;
      if (cursor < 0) return mode;
    }
    return available.last;
  }

  static String safeData({required String label}) {
    final normalized = label
        .replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized.substring(0, min(80, normalized.length));
  }
}
