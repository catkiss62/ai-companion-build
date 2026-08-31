enum PersonalityLearningScope {
  userPreference('user_preference', 'user.preference'),
  relationshipPermission('relationship_permission', 'relationship.permission'),
  trialPreference('trial_preference', 'trial.preference');

  const PersonalityLearningScope(this.key, this.subjectPrefix);

  final String key;
  final String subjectPrefix;

  static PersonalityLearningScope? parse(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    for (final scope in values) {
      if (scope.key == value) return scope;
    }
    return null;
  }
}

enum PersonalityLearningEvidenceKind {
  explicitPreference('explicit_preference', 1.0, 0.96),
  explicitCorrection('explicit_correction', 1.05, 0.97),
  directFeedback('direct_feedback', 0.72, 0.88),
  boundary('boundary', 1.08, 0.98),
  revealedChoice('revealed_choice', 0.28, 0.62);

  const PersonalityLearningEvidenceKind(
    this.key,
    this.baseWeight,
    this.confidenceCeiling,
  );

  final String key;
  final double baseWeight;
  final double confidenceCeiling;

  bool get isExplicit =>
      this == PersonalityLearningEvidenceKind.explicitPreference ||
      this == PersonalityLearningEvidenceKind.explicitCorrection ||
      this == PersonalityLearningEvidenceKind.boundary;

  static PersonalityLearningEvidenceKind? parse(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    for (final kind in values) {
      if (kind.key == value) return kind;
    }
    return null;
  }
}

enum PersonalityLearningPolarity {
  support('support'),
  contradict('contradict');

  const PersonalityLearningPolarity(this.key);
  final String key;

  static PersonalityLearningPolarity? parse(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    for (final polarity in values) {
      if (polarity.key == value) return polarity;
    }
    return null;
  }
}

enum PersonalityLearningStatus {
  candidate('candidate'),
  forming('forming'),
  established('established'),
  contradicted('contradicted'),
  retired('retired');

  const PersonalityLearningStatus(this.key);
  final String key;

  static PersonalityLearningStatus parse(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    return values.firstWhere(
      (status) => status.key == value,
      orElse: () => PersonalityLearningStatus.candidate,
    );
  }
}

class PersonalityLearningContext {
  const PersonalityLearningContext({
    required this.kind,
    required this.contextKey,
    this.trialId = '',
    this.trialKey = '',
  });

  const PersonalityLearningContext.ordinary()
      : kind = 'ordinary',
        contextKey = 'ordinary',
        trialId = '',
        trialKey = '';

  final String kind;
  final String contextKey;
  final String trialId;
  final String trialKey;

  bool get isTrial => kind != 'ordinary';

  bool allowsScope(PersonalityLearningScope scope) => isTrial
      ? scope == PersonalityLearningScope.trialPreference
      : scope != PersonalityLearningScope.trialPreference;
}

class PersonalityLearningCandidate {
  const PersonalityLearningCandidate({
    required this.id,
    required this.scope,
    required this.subjectKey,
    required this.proposition,
    required this.contextKey,
    required this.status,
    required this.confidence,
    required this.supportCount,
    required this.contradictionCount,
    required this.supportScore,
    required this.contradictionScore,
    required this.firstObservedAt,
    required this.lastObservedAt,
  });

  final String id;
  final PersonalityLearningScope scope;
  final String subjectKey;
  final String proposition;
  final String contextKey;
  final PersonalityLearningStatus status;
  final double confidence;
  final int supportCount;
  final int contradictionCount;
  final double supportScore;
  final double contradictionScore;
  final DateTime firstObservedAt;
  final DateTime lastObservedAt;

  factory PersonalityLearningCandidate.fromDb(Map<String, Object?> row) {
    final scope = PersonalityLearningScope.parse(row['scope'] as String?);
    if (scope == null) {
      throw StateError('personality_learning_scope_invalid');
    }
    return PersonalityLearningCandidate(
      id: row['id'] as String,
      scope: scope,
      subjectKey: row['subject_key'] as String? ?? '',
      proposition: row['proposition'] as String? ?? '',
      contextKey: row['context_key'] as String? ?? 'ordinary',
      status: PersonalityLearningStatus.parse(row['status'] as String?),
      confidence: (row['confidence'] as num?)?.toDouble() ?? 0,
      supportCount: (row['support_count'] as num?)?.toInt() ?? 0,
      contradictionCount:
          (row['contradiction_count'] as num?)?.toInt() ?? 0,
      supportScore: (row['support_score'] as num?)?.toDouble() ?? 0,
      contradictionScore:
          (row['contradiction_score'] as num?)?.toDouble() ?? 0,
      firstObservedAt: DateTime.fromMillisecondsSinceEpoch(
        (row['first_observed_at'] as num?)?.toInt() ?? 0,
      ),
      lastObservedAt: DateTime.fromMillisecondsSinceEpoch(
        (row['last_observed_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class PersonalityLearningProposal {
  const PersonalityLearningProposal({
    required this.scope,
    required this.subjectKey,
    required this.proposition,
    required this.polarity,
    required this.evidenceKind,
    required this.evidenceText,
    required this.confidence,
    this.targetCandidateId,
  });

  final PersonalityLearningScope scope;
  final String subjectKey;
  final String proposition;
  final PersonalityLearningPolarity polarity;
  final PersonalityLearningEvidenceKind evidenceKind;
  final String evidenceText;
  final double confidence;
  final String? targetCandidateId;

  double get weight => evidenceKind.baseWeight * (0.7 + confidence * 0.3);

  static PersonalityLearningProposal? parse({
    required Object? raw,
    required String userText,
    required PersonalityLearningContext context,
    required Map<String, PersonalityLearningCandidate> existingById,
  }) {
    if (raw is! Map) return null;
    final item = raw.cast<String, dynamic>();
    final polarity = PersonalityLearningPolarity.parse(
      item['polarity'] as String?,
    );
    final evidenceKind = PersonalityLearningEvidenceKind.parse(
      item['evidence_kind'] as String?,
    );
    if (polarity == null || evidenceKind == null) return null;

    final quote = _singleLine(item['evidence_quote'] as String? ?? '');
    final normalizedUser = _singleLine(userText);
    if (quote.length < 2 ||
        quote.length > 180 ||
        normalizedUser.isEmpty ||
        !normalizedUser.contains(quote)) {
      return null;
    }

    final targetId = (item['target_id'] as String? ?? '').trim();
    if (targetId.isNotEmpty) {
      final target = existingById[targetId];
      if (target == null ||
          target.status == PersonalityLearningStatus.retired ||
          target.contextKey != context.contextKey ||
          !context.allowsScope(target.scope)) {
        return null;
      }
      return PersonalityLearningProposal(
        scope: target.scope,
        subjectKey: target.subjectKey,
        proposition: target.proposition,
        polarity: polarity,
        evidenceKind: evidenceKind,
        evidenceText: quote,
        confidence: _calibratedConfidence(item['confidence'], evidenceKind),
        targetCandidateId: target.id,
      );
    }

    // A contradiction without a grounded target is ambiguous: the phone does
    // not let the model invent a proposition merely to refute it.
    if (polarity == PersonalityLearningPolarity.contradict) return null;
    final scope = PersonalityLearningScope.parse(item['scope'] as String?);
    if (scope == null || !context.allowsScope(scope)) return null;
    final subjectKey = (item['subject_key'] as String? ?? '')
        .trim()
        .toLowerCase();
    if (!_validSubject(scope, subjectKey)) return null;
    final proposition = _singleLine(item['proposition'] as String? ?? '');
    if (proposition.length < 4 || proposition.length > 240) return null;
    return PersonalityLearningProposal(
      scope: scope,
      subjectKey: subjectKey,
      proposition: proposition,
      polarity: polarity,
      evidenceKind: evidenceKind,
      evidenceText: quote,
      confidence: _calibratedConfidence(item['confidence'], evidenceKind),
    );
  }

  static String _singleLine(String raw) =>
      raw.replaceAll(RegExp(r'\s+'), ' ').trim();

  static double _calibratedConfidence(
    Object? raw,
    PersonalityLearningEvidenceKind kind,
  ) {
    final proposed = (raw as num?)?.toDouble() ?? 0.7;
    return proposed.clamp(0.35, kind.confidenceCeiling).toDouble();
  }

  static bool _validSubject(
    PersonalityLearningScope scope,
    String subjectKey,
  ) {
    if (!subjectKey.startsWith('${scope.subjectPrefix}.')) return false;
    return RegExp(
      r'^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*){2,7}$',
    ).hasMatch(subjectKey);
  }
}

class PersonalityLearningMaturityResult {
  const PersonalityLearningMaturityResult({
    required this.status,
    required this.confidence,
  });

  final PersonalityLearningStatus status;
  final double confidence;
}

class PersonalityLearningMaturityPolicy {
  const PersonalityLearningMaturityPolicy._();

  static PersonalityLearningMaturityResult evaluate({
    required double supportScore,
    required double contradictionScore,
    required int supportCount,
    required int contradictionCount,
    required PersonalityLearningPolarity latestPolarity,
    required PersonalityLearningEvidenceKind latestKind,
  }) {
    final total = supportScore + contradictionScore;
    final supportRatio = total <= 0 ? 0.0 : supportScore / total;

    if (latestPolarity == PersonalityLearningPolarity.contradict &&
        latestKind.isExplicit &&
        contradictionScore >= 0.82) {
      return PersonalityLearningMaturityResult(
        status: PersonalityLearningStatus.contradicted,
        confidence: (1 - supportRatio).clamp(0.35, 0.99).toDouble(),
      );
    }
    if (supportCount >= 2 &&
        supportScore >= 1.55 &&
        supportScore >= contradictionScore + 0.72) {
      return PersonalityLearningMaturityResult(
        status: PersonalityLearningStatus.established,
        confidence: supportRatio.clamp(0.68, 0.99).toDouble(),
      );
    }
    if (supportScore >= 0.62 && supportScore > contradictionScore) {
      return PersonalityLearningMaturityResult(
        status: PersonalityLearningStatus.forming,
        confidence: supportRatio.clamp(0.52, 0.90).toDouble(),
      );
    }
    return PersonalityLearningMaturityResult(
      status: PersonalityLearningStatus.candidate,
      confidence: supportRatio.clamp(0.20, 0.72).toDouble(),
    );
  }
}
