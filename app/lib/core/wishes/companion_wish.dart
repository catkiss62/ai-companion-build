import 'dart:math';

/// A durable intention, independent of a transient Thought or tool attempt.
class CompanionWish {
  const CompanionWish({
    required this.id,
    required this.goal,
    required this.reason,
    required this.route,
    required this.criterion,
    required this.createdAt,
    required this.updatedAt,
    this.state = 'active',
    this.gameId = '',
    this.nextStep = '',
    this.progress = '',
    this.interest = .6,
    this.sourceIds = const [],
    this.baseline = '',
    this.evidenceIds = const [],
    this.evidenceQuote = '',
    this.expressedAt,
    this.contactAttemptAt,
    this.actionAttemptAt,
    this.lastEvidenceAt,
    this.deadline,
    this.manualHold = false,
    this.legacy = false,
    this.completionKind = '',
  });
  final String completionKind;
  final String id,
      goal,
      reason,
      route,
      criterion,
      state,
      gameId,
      nextStep,
      progress;
  final String baseline, evidenceQuote;
  final double interest;
  final List<String> sourceIds, evidenceIds;
  final DateTime createdAt, updatedAt;
  final DateTime? expressedAt,
      contactAttemptAt,
      actionAttemptAt,
      lastEvidenceAt,
      deadline;
  final bool manualHold, legacy;
  bool get active => state == 'active';
  bool get terminal =>
      const {'completed', 'abandoned', 'expired'}.contains(state);
  double priority(DateTime now) =>
      interest *
      pow(
        .5,
        max(0, now.difference(lastEvidenceAt ?? createdAt).inHours) / (14 * 24),
      );
  bool mayContact(DateTime now) =>
      active &&
      !manualHold &&
      expressedAt == null &&
      (deadline == null || now.isBefore(deadline!)) &&
      (contactAttemptAt == null ||
          now.difference(contactAttemptAt!) >= const Duration(days: 1));
  bool mayAct(DateTime now) =>
      active &&
      !manualHold &&
      route != 'aspiration' &&
      (deadline == null || now.isBefore(deadline!)) &&
      (actionAttemptAt == null ||
          now.difference(actionAttemptAt!) >= const Duration(hours: 2));
  CompanionWish copyWith({
    String? state,
    String? progress,
    double? interest,
    DateTime? updatedAt,
    DateTime? expressedAt,
    DateTime? contactAttemptAt,
    DateTime? actionAttemptAt,
    DateTime? lastEvidenceAt,
    List<String>? evidenceIds,
    String? evidenceQuote,
    bool? manualHold,
  }) => CompanionWish(
    id: id,
    goal: goal,
    reason: reason,
    route: route,
    criterion: criterion,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    state: state ?? this.state,
    gameId: gameId,
    nextStep: nextStep,
    progress: progress ?? this.progress,
    interest: interest ?? this.interest,
    sourceIds: sourceIds,
    baseline: baseline,
    evidenceIds: evidenceIds ?? this.evidenceIds,
    evidenceQuote: evidenceQuote ?? this.evidenceQuote,
    expressedAt: expressedAt ?? this.expressedAt,
    contactAttemptAt: contactAttemptAt ?? this.contactAttemptAt,
    actionAttemptAt: actionAttemptAt ?? this.actionAttemptAt,
    lastEvidenceAt: lastEvidenceAt ?? this.lastEvidenceAt,
    deadline: deadline,
    manualHold: manualHold ?? this.manualHold,
    legacy: legacy,
    completionKind: completionKind,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'goal': goal,
    'reason': reason,
    'route': route,
    'criterion': criterion,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'state': state,
    'game_id': gameId,
    'next_step': nextStep,
    'progress': progress,
    'interest': interest,
    'source_ids': sourceIds,
    'baseline': baseline,
    'completion_kind': completionKind,
    'evidence_ids': evidenceIds,
    'evidence_quote': evidenceQuote,
    'expressed_at': expressedAt?.millisecondsSinceEpoch,
    'contact_attempt_at': contactAttemptAt?.millisecondsSinceEpoch,
    'action_attempt_at': actionAttemptAt?.millisecondsSinceEpoch,
    'last_evidence_at': lastEvidenceAt?.millisecondsSinceEpoch,
    'deadline': deadline?.millisecondsSinceEpoch,
    'manual_hold': manualHold,
    'legacy': legacy,
  };
  factory CompanionWish.fromJson(Map<String, dynamic> m) {
    DateTime? date(String k) => m[k] is num
        ? DateTime.fromMillisecondsSinceEpoch((m[k] as num).toInt())
        : null;
    String text(String k) => m[k]?.toString() ?? '';
    List<String> list(String k) =>
        (m[k] as List? ?? []).whereType<String>().toList();
    return CompanionWish(
      id: text('id'),
      goal: text('goal'),
      reason: text('reason'),
      route: text('route'),
      criterion: text('criterion'),
      createdAt: date('created_at') ?? DateTime(1970),
      updatedAt: date('updated_at') ?? DateTime(1970),
      state: text('state'),
      gameId: text('game_id'),
      nextStep: text('next_step'),
      progress: text('progress'),
      interest: ((m['interest'] as num?)?.toDouble() ?? .5).clamp(0, 1),
      sourceIds: list('source_ids'),
      baseline: text('baseline'),
      evidenceIds: list('evidence_ids'),
      evidenceQuote: text('evidence_quote'),
      expressedAt: date('expressed_at'),
      contactAttemptAt: date('contact_attempt_at'),
      actionAttemptAt: date('action_attempt_at'),
      lastEvidenceAt: date('last_evidence_at'),
      deadline: date('deadline'),
      manualHold: m['manual_hold'] == true,
      legacy: m['legacy'] == true,
      completionKind: text('completion_kind'),
    );
  }
  Map<String, Object?> publicEntry() {
    final local = createdAt.toLocal();
    final day =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    return {
      'id': id,
      'kind': 'wish',
      'title': '想做的事',
      'body': goal,
      'local_day': day,
      'created_at': createdAt.millisecondsSinceEpoch,
      'provenance': legacy ? 'legacy_wish' : 'generated_wish_v2',
      'state': state,
      'metadata': {
        'wish_version': 2,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'reason': reason,
        'progress': progress,
        'route': route,
        'legacy': legacy,
        'criterion': criterion,
        'evidence_count': evidenceIds.length,
        'manual_hold': manualHold,
      },
    };
  }
}

class WishEvidence {
  const WishEvidence({
    required this.id,
    required this.kind,
    required this.text,
    required this.at,
    this.gameId = '',
  });
  final String id, kind, text, gameId;
  final DateTime at;
  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'text': text,
    'at': at.toIso8601String(),
    'game_id': gameId,
  };
}
