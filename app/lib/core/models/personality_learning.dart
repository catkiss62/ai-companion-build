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

enum PersonalityLearningRejectionReason {
  invalidPayload('invalid_payload'),
  invalidPolarityOrKind('invalid_polarity_or_kind'),
  invalidQuote('invalid_quote'),
  invalidTarget('invalid_target'),
  ungroundedTarget('ungrounded_target'),
  contradictionWithoutTarget('contradiction_without_target'),
  invalidScope('invalid_scope'),
  invalidSubject('invalid_subject'),
  invalidProposition('invalid_proposition'),
  ambiguousReinforcement('ambiguous_reinforcement'),
  contextOnlyReply('context_only_reply');

  const PersonalityLearningRejectionReason(this.key);

  final String key;
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
  }) =>
      parseDetailed(
        raw: raw,
        userText: userText,
        context: context,
        existingById: existingById,
      ).proposal;

  static PersonalityLearningParseResult parseDetailed({
    required Object? raw,
    required String userText,
    required PersonalityLearningContext context,
    required Map<String, PersonalityLearningCandidate> existingById,
  }) {
    PersonalityLearningParseResult reject(
      PersonalityLearningRejectionReason reason,
    ) =>
        PersonalityLearningParseResult.rejected(reason);

    if (raw is! Map) {
      return reject(PersonalityLearningRejectionReason.invalidPayload);
    }
    final item = raw.cast<String, dynamic>();
    final polarity = PersonalityLearningPolarity.parse(
      item['polarity'] as String?,
    );
    final evidenceKind = PersonalityLearningEvidenceKind.parse(
      item['evidence_kind'] as String?,
    );
    if (polarity == null || evidenceKind == null) {
      return reject(
        PersonalityLearningRejectionReason.invalidPolarityOrKind,
      );
    }

    final quote = _singleLine(item['evidence_quote'] as String? ?? '');
    final normalizedUser = _singleLine(userText);
    if (quote.length < 2 ||
        quote.length > 180 ||
        normalizedUser.isEmpty ||
        !normalizedUser.contains(quote)) {
      return reject(PersonalityLearningRejectionReason.invalidQuote);
    }
    if (_isContextOnlyPacingReply(quote)) {
      return reject(PersonalityLearningRejectionReason.contextOnlyReply);
    }

    final targetId = (item['target_id'] as String? ?? '').trim();
    if (targetId.isNotEmpty) {
      final target = existingById[targetId];
      if (target == null ||
          target.status == PersonalityLearningStatus.retired ||
          target.contextKey != context.contextKey ||
          !context.allowsScope(target.scope)) {
        return reject(PersonalityLearningRejectionReason.invalidTarget);
      }
      if (!_isGroundedToTarget(
        normalizedUser: normalizedUser,
        evidenceKind: evidenceKind,
        target: target,
        explicitTarget: true,
      )) {
        return reject(PersonalityLearningRejectionReason.ungroundedTarget);
      }
      return PersonalityLearningParseResult.accepted(
        _proposalForTarget(
          target: target,
          polarity: polarity,
          evidenceKind: evidenceKind,
          quote: quote,
          confidence: item['confidence'],
        ),
      );
    }

    // A contradiction without a grounded target is ambiguous: the phone does
    // not let the model invent a proposition merely to refute it.
    if (polarity == PersonalityLearningPolarity.contradict) {
      return reject(
        PersonalityLearningRejectionReason.contradictionWithoutTarget,
      );
    }
    final scope = PersonalityLearningScope.parse(item['scope'] as String?);
    if (scope == null || !context.allowsScope(scope)) {
      return reject(PersonalityLearningRejectionReason.invalidScope);
    }
    final subjectKey = (item['subject_key'] as String? ?? '')
        .trim()
        .toLowerCase();

    final reinforcement = _findGroundedReinforcementTarget(
      normalizedUser: normalizedUser,
      evidenceKind: evidenceKind,
      scope: scope,
      proposedSubjectKey: subjectKey,
      context: context,
      existingById: existingById,
    );
    if (reinforcement.target != null) {
      return PersonalityLearningParseResult.accepted(
        _proposalForTarget(
          target: reinforcement.target!,
          polarity: polarity,
          evidenceKind: evidenceKind,
          quote: quote,
          confidence: item['confidence'],
        ),
      );
    }
    if (reinforcement.ambiguous) {
      return reject(
        PersonalityLearningRejectionReason.ambiguousReinforcement,
      );
    }
    final collidesWithUngroundedTarget = existingById.values.any(
      (candidate) =>
          candidate.status != PersonalityLearningStatus.retired &&
          candidate.scope == scope &&
          candidate.contextKey == context.contextKey &&
          candidate.subjectKey == subjectKey,
    );
    if (collidesWithUngroundedTarget) {
      return reject(PersonalityLearningRejectionReason.ungroundedTarget);
    }
    if (!_validSubject(scope, subjectKey)) {
      return reject(PersonalityLearningRejectionReason.invalidSubject);
    }
    final proposition = _singleLine(item['proposition'] as String? ?? '');
    if (proposition.length < 4 || proposition.length > 240) {
      return reject(PersonalityLearningRejectionReason.invalidProposition);
    }
    return PersonalityLearningParseResult.accepted(
      PersonalityLearningProposal(
        scope: scope,
        subjectKey: subjectKey,
        proposition: proposition,
        polarity: polarity,
        evidenceKind: evidenceKind,
        evidenceText: quote,
        confidence: _calibratedConfidence(item['confidence'], evidenceKind),
      ),
    );
  }

  static PersonalityLearningProposal _proposalForTarget({
    required PersonalityLearningCandidate target,
    required PersonalityLearningPolarity polarity,
    required PersonalityLearningEvidenceKind evidenceKind,
    required String quote,
    required Object? confidence,
  }) =>
      PersonalityLearningProposal(
        scope: target.scope,
        subjectKey: target.subjectKey,
        proposition: target.proposition,
        polarity: polarity,
        evidenceKind: evidenceKind,
        evidenceText: quote,
        confidence: _calibratedConfidence(confidence, evidenceKind),
        targetCandidateId: target.id,
      );

  static _PersonalityLearningTargetMatch _findGroundedReinforcementTarget({
    required String normalizedUser,
    required PersonalityLearningEvidenceKind evidenceKind,
    required PersonalityLearningScope scope,
    required String proposedSubjectKey,
    required PersonalityLearningContext context,
    required Map<String, PersonalityLearningCandidate> existingById,
  }) {
    // Direct feedback is intentionally allowed to use the previous AI turn to
    // locate an expression, so it must keep an explicit model-selected target.
    if (evidenceKind == PersonalityLearningEvidenceKind.directFeedback) {
      return const _PersonalityLearningTargetMatch();
    }
    final grounded = existingById.values.where((candidate) {
      final subjectMatches = candidate.subjectKey == proposedSubjectKey;
      final overlap = _distinctiveBigramOverlap(
        normalizedUser,
        candidate.proposition,
      );
      return candidate.status != PersonalityLearningStatus.retired &&
          candidate.scope == scope &&
          candidate.contextKey == context.contextKey &&
          (subjectMatches || overlap >= 3) &&
          _isGroundedToTarget(
            normalizedUser: normalizedUser,
            evidenceKind: evidenceKind,
            target: candidate,
            explicitTarget: false,
          );
    }).toList(growable: false);
    final exact = grounded
        .where((candidate) => candidate.subjectKey == proposedSubjectKey)
        .toList(growable: false);
    if (exact.length == 1) {
      return _PersonalityLearningTargetMatch(target: exact.single);
    }
    if (exact.length > 1 || grounded.length > 1) {
      return const _PersonalityLearningTargetMatch(ambiguous: true);
    }
    return grounded.length == 1
        ? _PersonalityLearningTargetMatch(target: grounded.single)
        : const _PersonalityLearningTargetMatch();
  }

  static bool _isGroundedToTarget({
    required String normalizedUser,
    required PersonalityLearningEvidenceKind evidenceKind,
    required PersonalityLearningCandidate target,
    required bool explicitTarget,
  }) {
    if (evidenceKind == PersonalityLearningEvidenceKind.directFeedback) {
      return explicitTarget &&
          _containsAny(normalizedUser, const <String>[
            '你刚才',
            '刚才那句',
            '你那句',
            '这种说法',
            '这样说',
            '这个反应',
            '这种感觉',
          ]) &&
          _containsAny(normalizedUser, const <String>[
            '喜欢',
            '不喜欢',
            '有意思',
            '好玩',
            '不错',
            '自然',
            '别扭',
            '舒服',
            '不舒服',
            '可以',
            '不可以',
            '别',
            '不要',
          ]);
    }
    final overlap = _distinctiveBigramOverlap(
      normalizedUser,
      target.proposition,
    );
    final requiredOverlap =
        evidenceKind == PersonalityLearningEvidenceKind.explicitCorrection ||
                evidenceKind == PersonalityLearningEvidenceKind.boundary
            ? 1
            : 2;
    if (overlap < requiredOverlap) return false;
    return _containsAny(normalizedUser, const <String>[
      '我喜欢',
      '我更喜欢',
      '我真的喜欢',
      '我不喜欢',
      '我讨厌',
      '我希望',
      '我想要',
      '我不想',
      '我宁愿',
      '我接受',
      '我不接受',
      '对，就是',
      '对的',
      '没错',
      '确实',
      '这种',
      '应该',
      '不应该',
      '可以',
      '不可以',
      '别把',
      '不要',
    ]);
  }

  static int _distinctiveBigramOverlap(String left, String right) {
    final leftBigrams = _distinctiveCjkBigrams(left);
    final rightBigrams = _distinctiveCjkBigrams(right);
    return leftBigrams.intersection(rightBigrams).length;
  }

  static Set<String> _distinctiveCjkBigrams(String input) {
    final output = <String>{};
    for (final match in RegExp(r'[\u3400-\u9fff]{2,}').allMatches(input)) {
      final run = match.group(0)!;
      final genericCharacters = List<bool>.filled(run.length, false);
      for (final phrase in _genericBigrams) {
        var start = run.indexOf(phrase);
        while (start >= 0) {
          for (var index = start;
              index < start + phrase.length;
              index += 1) {
            genericCharacters[index] = true;
          }
          start = run.indexOf(phrase, start + 1);
        }
      }
      for (var index = 0; index < run.length - 1; index += 1) {
        // Do not let the edges of a generic phrase manufacture specificity.
        // For example, removing only `喜欢` still leaves `欢在`, which would
        // falsely help merge "海边散步" with "海边拍照".
        if (genericCharacters[index] || genericCharacters[index + 1]) {
          continue;
        }
        output.add(run.substring(index, index + 2));
      }
    }
    return output;
  }

  static bool _containsAny(String input, List<String> cues) =>
      cues.any(input.contains);

  static bool _isContextOnlyPacingReply(String input) {
    final hasPacingLanguage = _containsAny(input, const <String>[
      '慢慢来',
      '慢慢就好',
      '不用着急',
      '不着急',
      '不急',
      '时间还长',
      '以后再说',
    ]);
    if (!hasPacingLanguage) return false;
    return !_containsAny(input, const <String>[
      '我喜欢',
      '我更喜欢',
      '我真的喜欢',
      '我不喜欢',
      '我讨厌',
      '我希望',
      '我想要',
      '我不想',
      '我宁愿',
      '我接受',
      '我不接受',
      '我改一下',
      '我不是说',
      '我的意思',
      '你刚才',
      '刚才那句',
      '这种说法',
      '这样说',
    ]);
  }

  static const Set<String> _genericBigrams = <String>{
    '用户',
    '偏好',
    '喜欢',
    '不喜',
    '关系',
    '表达',
    '交流',
    '方式',
    '自然',
    '这种',
    '觉得',
    '真的',
    '可以',
    '不要',
    '就是',
    '不是',
    '更加',
    '已经',
    '还是',
  };

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

class PersonalityLearningParseResult {
  const PersonalityLearningParseResult.accepted(this.proposal)
      : rejectionReason = null;

  const PersonalityLearningParseResult.rejected(this.rejectionReason)
      : proposal = null;

  final PersonalityLearningProposal? proposal;
  final PersonalityLearningRejectionReason? rejectionReason;
}

class _PersonalityLearningTargetMatch {
  const _PersonalityLearningTargetMatch({this.target, this.ambiguous = false});

  final PersonalityLearningCandidate? target;
  final bool ambiguous;
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
