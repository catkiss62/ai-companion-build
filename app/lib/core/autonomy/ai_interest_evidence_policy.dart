import 'dart:math';

enum AiInterestStatus {
  forming('forming'),
  established('established'),
  contradicted('contradicted'),
  inactive('inactive');

  const AiInterestStatus(this.key);
  final String key;
}

enum AiInterestEvidenceSource {
  autonomousWebVerified('autonomous_web_verified', true),
  autonomousShare('autonomous_share', true),
  userFeedbackPositive('user_feedback_positive', false),
  userFeedbackNegative('user_feedback_negative', false);

  const AiInterestEvidenceSource(this.key, this.autonomous);
  final String key;
  final bool autonomous;

  static AiInterestEvidenceSource? fromKey(String key) {
    for (final value in values) {
      if (value.key == key) return value;
    }
    return null;
  }
}

class AiInterestEvidenceObservation {
  const AiInterestEvidenceObservation({
    required this.sourceKind,
    required this.polarity,
    required this.weight,
    required this.localDay,
    required this.occurredAt,
  });

  final String sourceKind;
  final int polarity;
  final double weight;
  final String localDay;
  final DateTime occurredAt;
}

class AiInterestAggregate {
  const AiInterestAggregate({
    required this.status,
    required this.supportCount,
    required this.counterCount,
    required this.autonomousDayCount,
    required this.confidence,
    required this.freshness,
    required this.lastEvidenceAt,
  });

  final AiInterestStatus status;
  final int supportCount;
  final int counterCount;
  final int autonomousDayCount;
  final double confidence;
  final double freshness;
  final DateTime? lastEvidenceAt;
}

/// Phase 3A's evidence contract. It deliberately has no prompt-facing API.
///
/// A candidate can only become established after positive terminal outcomes
/// from autonomous behavior on at least two different local dates. User
/// feedback can strengthen or contradict an existing candidate, but can never
/// bootstrap one or satisfy the cross-date autonomous requirement by itself.
class AiInterestEvidencePolicy {
  const AiInterestEvidencePolicy();

  static const double minimumDiscoveryInterest = 0.55;
  static const double establishedConfidence = 0.68;

  bool isValidInterestKey(String value) {
    final key = normalizeInterestKey(value);
    return key.length >= 3 &&
        key.length <= 160 &&
        RegExp(r'^[a-z0-9][a-z0-9._:-]*$').hasMatch(key);
  }

  String normalizeInterestKey(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  bool isEligibleSource(String sourceKind) =>
      AiInterestEvidenceSource.fromKey(sourceKind) != null;

  bool canCreateCandidate(String sourceKind, int polarity) {
    final source = AiInterestEvidenceSource.fromKey(sourceKind);
    return source != null && source.autonomous && polarity > 0;
  }

  String localDayKey(DateTime instant) {
    final local = instant.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  AiInterestAggregate aggregate(
    Iterable<AiInterestEvidenceObservation> observations, {
    required DateTime now,
  }) {
    var positiveWeight = 0.0;
    var negativeWeight = 0.0;
    var supportCount = 0;
    var counterCount = 0;
    DateTime? lastPositiveAt;
    final autonomousDays = <String>{};

    for (final item in observations) {
      final source = AiInterestEvidenceSource.fromKey(item.sourceKind);
      if (source == null || item.weight <= 0 || item.localDay.isEmpty) continue;
      final weight = item.weight.clamp(0.0, 1.0).toDouble();
      if (item.polarity > 0) {
        supportCount++;
        positiveWeight += weight;
        if (source.autonomous) autonomousDays.add(item.localDay);
        if (lastPositiveAt == null || item.occurredAt.isAfter(lastPositiveAt)) {
          lastPositiveAt = item.occurredAt;
        }
      } else if (item.polarity < 0) {
        counterCount++;
        negativeWeight += weight;
      }
    }

    final confidence = positiveWeight == 0
        ? 0.0
        : positiveWeight / (positiveWeight + negativeWeight + 0.5);
    final freshness = freshnessAt(lastPositiveAt, now);
    final AiInterestStatus status;
    if (positiveWeight == 0) {
      status = AiInterestStatus.inactive;
    } else if (negativeWeight >= max(1.0, positiveWeight)) {
      status = AiInterestStatus.contradicted;
    } else if (autonomousDays.length >= 2 &&
        supportCount >= 2 &&
        confidence >= establishedConfidence) {
      status = AiInterestStatus.established;
    } else {
      status = AiInterestStatus.forming;
    }

    return AiInterestAggregate(
      status: status,
      supportCount: supportCount,
      counterCount: counterCount,
      autonomousDayCount: autonomousDays.length,
      confidence: confidence.clamp(0.0, 1.0).toDouble(),
      freshness: freshness,
      lastEvidenceAt: lastPositiveAt,
    );
  }

  double freshnessAt(DateTime? lastPositiveAt, DateTime now) {
    if (lastPositiveAt == null) return 0;
    final age = now.difference(lastPositiveAt);
    if (age <= const Duration(days: 1)) return 1;
    final ageDays = age.inHours / 24.0;
    return (1.0 - ((ageDays - 1.0) / 59.0)).clamp(0.0, 1.0).toDouble();
  }
}
