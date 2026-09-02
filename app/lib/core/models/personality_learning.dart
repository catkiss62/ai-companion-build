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
  protectedContract('protected_contract'),
  unverifiedDirectFeedback('unverified_direct_feedback'),
  overbroadProposition('overbroad_proposition'),
  ambiguousReinforcement('ambiguous_reinforcement'),
  contextOnlyReply('context_only_reply'),
  semanticReviewUnrelated('semantic_review_unrelated'),
  semanticReviewAmbiguous('semantic_review_ambiguous'),
  semanticReviewUnavailable('semantic_review_unavailable');

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
    String previousAssistantText = '',
  }) =>
      parseDetailed(
        raw: raw,
        userText: userText,
        context: context,
        existingById: existingById,
        previousAssistantText: previousAssistantText,
      ).proposal;

  static PersonalityLearningParseResult parseDetailed({
    required Object? raw,
    required String userText,
    required PersonalityLearningContext context,
    required Map<String, PersonalityLearningCandidate> existingById,
    String previousAssistantText = '',
    String semanticReviewApprovedTargetId = '',
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

    final assistantExpressionQuote =
        _singleLine(item['assistant_expression_quote'] as String? ?? '');
    if (evidenceKind == PersonalityLearningEvidenceKind.directFeedback) {
      final normalizedAssistant = _singleLine(previousAssistantText);
      if (assistantExpressionQuote.length < 2 ||
          assistantExpressionQuote.length > 180 ||
          normalizedAssistant.isEmpty ||
          !normalizedAssistant.contains(assistantExpressionQuote)) {
        return reject(
          PersonalityLearningRejectionReason.unverifiedDirectFeedback,
        );
      }
    }

    final targetId = (item['target_id'] as String? ?? '').trim();
    if (targetId.isNotEmpty) {
      final target = existingById[targetId];
      if (target == null ||
          target.status == PersonalityLearningStatus.retired ||
          target.contextKey != context.contextKey ||
          !context.allowsScope(target.scope) ||
          !PersonalityLearningBoundaryPolicy.isAllowedBehavioralSubject(
            scope: target.scope,
            subjectKey: target.subjectKey,
          )) {
        return reject(PersonalityLearningRejectionReason.invalidTarget);
      }
      if (PersonalityLearningBoundaryPolicy.isProtectedContractClaim(
        subjectKey: target.subjectKey,
        text: '$normalizedUser ${target.proposition}',
      )) {
        return reject(PersonalityLearningRejectionReason.protectedContract);
      }
      if (polarity == PersonalityLearningPolarity.support &&
          PersonalityLearningAtomicityPolicy.clearlyDifferentDimension(
            evidenceText: normalizedUser,
            targetProposition: target.proposition,
          )) {
        final separated = PersonalityLearningEvidenceRepairPolicy.v44Target(
          evidenceText: normalizedUser,
          candidateScope: target.scope.key,
          candidateSubject: target.subjectKey,
        );
        final separatedScope =
            PersonalityLearningScope.parse(separated?.scope);
        if (separated != null &&
            separatedScope != null &&
            context.allowsScope(separatedScope) &&
            PersonalityLearningBoundaryPolicy.isAllowedBehavioralSubject(
              scope: separatedScope,
              subjectKey: separated.subjectKey,
            )) {
          return PersonalityLearningParseResult.accepted(
            PersonalityLearningProposal(
              scope: separatedScope,
              subjectKey: separated.subjectKey,
              proposition: separated.proposition,
              polarity: polarity,
              evidenceKind: evidenceKind,
              evidenceText: quote,
              confidence: _calibratedConfidence(
                item['confidence'],
                evidenceKind,
              ),
            ),
          );
        }
        final targetless = Map<String, dynamic>.from(item)
          ..['target_id'] = '';
        return parseDetailed(
          raw: targetless,
          userText: userText,
          context: context,
          existingById: existingById,
          previousAssistantText: previousAssistantText,
        );
      }
      if (evidenceKind == PersonalityLearningEvidenceKind.directFeedback) {
        final matchingTargets = existingById.values.where((candidate) {
          return candidate.status != PersonalityLearningStatus.retired &&
              candidate.scope == target.scope &&
              candidate.contextKey == target.contextKey &&
              PersonalityLearningBoundaryPolicy.isAllowedBehavioralSubject(
                scope: candidate.scope,
                subjectKey: candidate.subjectKey,
              ) &&
              _distinctiveBigramOverlap(
                    assistantExpressionQuote,
                    candidate.proposition,
                  ) >=
                  1;
        }).toList(growable: false);
        if (matchingTargets.isEmpty ||
            (matchingTargets.length == 1 &&
                matchingTargets.single.id != target.id)) {
          return reject(
            PersonalityLearningRejectionReason.ungroundedTarget,
          );
        }
        if (matchingTargets.length > 1) {
          return reject(
            PersonalityLearningRejectionReason.ambiguousReinforcement,
          );
        }
      }
      if (!_isGroundedToTarget(
        normalizedUser: normalizedUser,
        evidenceKind: evidenceKind,
        target: target,
        explicitTarget: true,
        assistantExpressionQuote: assistantExpressionQuote,
      )) {
        if (semanticReviewApprovedTargetId == target.id &&
            _eligibleForSemanticReview(
              normalizedUser: normalizedUser,
              evidenceKind: evidenceKind,
            )) {
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
        if (_eligibleForSemanticReview(
          normalizedUser: normalizedUser,
          evidenceKind: evidenceKind,
        )) {
          return PersonalityLearningParseResult.reviewRequired(
            target: target,
            proposedPolarity: polarity,
            evidenceKind: evidenceKind,
            evidenceQuote: quote,
          );
        }
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
      assistantExpressionQuote: assistantExpressionQuote,
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
    final collidingTargets = existingById.values.where(
      (candidate) =>
          candidate.status != PersonalityLearningStatus.retired &&
          candidate.scope == scope &&
          candidate.contextKey == context.contextKey &&
          PersonalityLearningBoundaryPolicy.isAllowedBehavioralSubject(
            scope: candidate.scope,
            subjectKey: candidate.subjectKey,
          ) &&
          candidate.subjectKey == subjectKey,
    ).toList(growable: false);
    if (collidingTargets.length == 1 &&
        semanticReviewApprovedTargetId == collidingTargets.single.id &&
        _eligibleForSemanticReview(
          normalizedUser: normalizedUser,
          evidenceKind: evidenceKind,
        )) {
      return PersonalityLearningParseResult.accepted(
        _proposalForTarget(
          target: collidingTargets.single,
          polarity: polarity,
          evidenceKind: evidenceKind,
          quote: quote,
          confidence: item['confidence'],
        ),
      );
    }
    if (collidingTargets.length == 1 &&
        _eligibleForSemanticReview(
          normalizedUser: normalizedUser,
          evidenceKind: evidenceKind,
        )) {
      return PersonalityLearningParseResult.reviewRequired(
        target: collidingTargets.single,
        proposedPolarity: polarity,
        evidenceKind: evidenceKind,
        evidenceQuote: quote,
      );
    }
    if (collidingTargets.isNotEmpty) {
      return reject(PersonalityLearningRejectionReason.ungroundedTarget);
    }
    if (!_validSubject(scope, subjectKey)) {
      return reject(PersonalityLearningRejectionReason.invalidSubject);
    }
    final proposition = _singleLine(item['proposition'] as String? ?? '');
    if (proposition.length < 4 || proposition.length > 240) {
      return reject(PersonalityLearningRejectionReason.invalidProposition);
    }
    if (PersonalityLearningBoundaryPolicy.isProtectedContractClaim(
      subjectKey: subjectKey,
      text: '$normalizedUser $proposition',
    )) {
      return reject(PersonalityLearningRejectionReason.protectedContract);
    }
    if (!_isGroundedNewProposition(
      normalizedUser: normalizedUser,
      assistantExpressionQuote: assistantExpressionQuote,
      evidenceKind: evidenceKind,
      proposition: proposition,
    )) {
      return reject(PersonalityLearningRejectionReason.overbroadProposition);
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
    required String assistantExpressionQuote,
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
          PersonalityLearningBoundaryPolicy.isAllowedBehavioralSubject(
            scope: candidate.scope,
            subjectKey: candidate.subjectKey,
          ) &&
          (subjectMatches || overlap >= 3) &&
          _isGroundedToTarget(
            normalizedUser: normalizedUser,
            evidenceKind: evidenceKind,
            target: candidate,
            explicitTarget: false,
            assistantExpressionQuote: assistantExpressionQuote,
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
    required String assistantExpressionQuote,
  }) {
    if (evidenceKind == PersonalityLearningEvidenceKind.directFeedback) {
      return explicitTarget &&
          assistantExpressionQuote.isNotEmpty &&
          _distinctiveBigramOverlap(
                assistantExpressionQuote,
                target.proposition,
              ) >=
              1 &&
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

  static bool _eligibleForSemanticReview({
    required String normalizedUser,
    required PersonalityLearningEvidenceKind evidenceKind,
  }) {
    if (evidenceKind == PersonalityLearningEvidenceKind.directFeedback ||
        evidenceKind == PersonalityLearningEvidenceKind.revealedChoice ||
        normalizedUser.length < 12 ||
        normalizedUser.length > 360 ||
        _isContextOnlyPacingReply(normalizedUser)) {
      return false;
    }
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
      '我的偏好',
      '我觉得',
      '我认为',
      '对我来说',
      '这种感觉',
      '才更好',
      '更适合',
      '我改一下',
      '我修正',
      '只限',
      '只在',
      '不应该',
      '应该',
      '不要',
    ]);
  }

  static bool _isGroundedNewProposition({
    required String normalizedUser,
    required String assistantExpressionQuote,
    required PersonalityLearningEvidenceKind evidenceKind,
    required String proposition,
  }) {
    if (!proposition.startsWith('用户')) return false;
    const absoluteCues = <String>[
      '必须',
      '每次',
      '每轮',
      '永远',
      '始终',
      '任何时候',
      '所有场景',
      '无条件',
      '强制',
    ];
    for (final cue in absoluteCues) {
      if (proposition.contains(cue) && !normalizedUser.contains(cue)) {
        return false;
      }
    }
    final evidenceSource = evidenceKind ==
            PersonalityLearningEvidenceKind.directFeedback
        ? '$normalizedUser $assistantExpressionQuote'
        : normalizedUser;
    return _distinctiveBigramOverlap(evidenceSource, proposition) >= 1;
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
    if (!RegExp(
      r'^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*){2,7}$',
    ).hasMatch(subjectKey)) {
      return false;
    }
    return PersonalityLearningBoundaryPolicy.isAllowedBehavioralSubject(
      scope: scope,
      subjectKey: subjectKey,
    );
  }
}

/// Rejects high-confidence cross-axis merges before semantic review can
/// approve them merely because both statements concern communication.
abstract final class PersonalityLearningAtomicityPolicy {
  static bool clearlyDifferentDimension({
    required String evidenceText,
    required String targetProposition,
  }) {
    final evidence = evidenceText.replaceAll(RegExp(r'\s+'), '');
    final target = targetProposition.replaceAll(RegExp(r'\s+'), '');
    for (final dimension in _dimensions) {
      if (_containsAny(evidence, dimension.cues) &&
          !_containsAny(target, dimension.cues)) {
        return true;
      }
    }
    return false;
  }

  static const _dimensions = <({String key, List<String> cues})>[
    (
      key: 'colloquial_concise',
      cues: <String>['口语化', '少解释', '不用解释', '不必解释', '像聊天'],
    ),
    (
      key: 'self_directed_agency',
      cues: <String>[
        '自己的想法',
        '自己的意愿',
        '你应该任性',
        '你不愿意',
        '你累了',
        '好奇心起来',
      ],
    ),
  ];

  static bool _containsAny(String text, List<String> cues) =>
      cues.any(text.contains);
}

class PersonalityLearningRepairTarget {
  const PersonalityLearningRepairTarget({
    required this.scope,
    required this.subjectKey,
    required this.proposition,
    required this.reason,
  });

  final String scope;
  final String subjectKey;
  final String proposition;
  final String reason;
}

/// Narrow, deterministic v44 repair for the two dimensions observed inside a
/// broad familiarity candidate. It classifies by meaning-bearing phrases and
/// never by private message IDs, so the source evidence remains portable.
abstract final class PersonalityLearningEvidenceRepairPolicy {
  static PersonalityLearningRepairTarget? v44Target({
    required String evidenceText,
    required String candidateScope,
    required String candidateSubject,
  }) {
    final text = evidenceText.replaceAll(RegExp(r'\s+'), '');
    final fromBroadCommunication = candidateScope == 'user_preference' &&
        (candidateSubject.contains('familiar') ||
            candidateSubject.contains('communication') ||
            candidateSubject.contains('relationship'));
    if (!fromBroadCommunication) return null;
    if (text.contains('口语化') ||
        text.contains('少解释') ||
        RegExp(r'不用.{0,4}解释.{0,4}清楚').hasMatch(text) ||
        text.contains('更像聊天')) {
      return const PersonalityLearningRepairTarget(
        scope: 'user_preference',
        subjectKey: 'user.preference.communication.colloquial_concise',
        proposition: '用户偏好更口语化、更像聊天且不过度解释的交流方式。',
        reason: 'v44_split_colloquial_concise_from_broad_familiarity',
      );
    }
    final selfDirected = text.contains('自己的想法') ||
        text.contains('有自己的意愿') ||
        text.contains('你应该任性');
    final stateDriven = text.contains('你累了') ||
        text.contains('好奇心起来') ||
        text.contains('依恋高了') ||
        text.contains('你不愿意');
    if (selfDirected && stateDriven) {
      return const PersonalityLearningRepairTarget(
        scope: 'relationship_permission',
        subjectKey: 'relationship.permission.initiative.self_directed',
        proposition: '用户允许 AI 按自己的意愿、疲劳、好奇与关系情绪自主决定怎样回应。',
        reason: 'v44_split_self_directed_permission_from_familiarity',
      );
    }
    return null;
  }
}

/// Phase 0 owns the boundary between ordinary content memory, learnable
/// relationship expression, and contracts that learning must never rewrite.
/// The model may propose a category, but these local checks remain final.
class PersonalityLearningBoundaryPolicy {
  const PersonalityLearningBoundaryPolicy._();

  static const _userPreferenceDomains = <String>{
    'address',
    'affection',
    'communication',
    'companionship',
    'conflict',
    'expression',
    'familiarity',
    'humor',
    'initiative',
    'interaction',
    'intimacy',
    'language',
    'pacing',
    'relationship',
    'tone',
  };

  static const _protectedSubjectSegments = <String>{
    'core',
    'format',
    'identity',
    'memory_truth',
    'protocol',
    'rule',
    'safety',
    'system',
    'tool',
  };

  static const _relationshipPermissionDomains = <String>{
    'address',
    'affection',
    'boundary',
    'communication',
    'companionship',
    'conflict',
    'expression',
    'familiarity',
    'humor',
    'initiative',
    'interaction',
    'intimacy',
    'language',
    'pacing',
    'roleplay',
    'tone',
  };

  static bool isAllowedBehavioralSubject({
    required PersonalityLearningScope scope,
    required String subjectKey,
  }) {
    final value = subjectKey.toLowerCase();
    if (!value.startsWith('${scope.subjectPrefix}.')) return false;
    final parts = value.split('.');
    if (parts.any(_protectedSubjectSegments.contains)) return false;
    return switch (scope) {
      PersonalityLearningScope.userPreference =>
        parts.length >= 3 && _userPreferenceDomains.contains(parts[2]),
      PersonalityLearningScope.relationshipPermission =>
        parts.length >= 3 && _relationshipPermissionDomains.contains(parts[2]),
      PersonalityLearningScope.trialPreference => true,
    };
  }

  static bool isBehavioralMemorySubject(String subjectKey) {
    final value = subjectKey.trim().toLowerCase();
    if (value.startsWith('relationship.permission.')) return true;
    const prefixes = <String>[
      'user.preference.',
      'preference.',
    ];
    for (final prefix in prefixes) {
      if (!value.startsWith(prefix)) continue;
      final tail = value.substring(prefix.length);
      final domain = tail.split('.').first;
      if (_userPreferenceDomains.contains(domain)) return true;
    }
    return false;
  }

  static bool looksLikeBehavioralPreference(String text) {
    final value = text.trim().toLowerCase();
    if (value.isEmpty) return false;
    final hasPreference = _containsAny(value, const <String>[
      '偏好',
      '喜欢',
      '希望',
      '允许',
      '接受',
      '不喜欢',
      '不要',
      '可以',
    ]);
    final hasInteraction = _containsAny(value, const <String>[
      '相处',
      '关系',
      '互动',
      '交流',
      '说话',
      '表达',
      '语气',
      '语调',
      '用词',
      '措辞',
      '称呼',
      '节奏',
      '幽默',
      '斗嘴',
      '客套',
      '脏话',
      '粗话',
      '主动',
      '任性',
      '顶嘴',
    ]);
    return hasPreference && hasInteraction;
  }

  static bool isProtectedContractClaim({
    required String subjectKey,
    required String text,
  }) {
    final parts = subjectKey.toLowerCase().split('.');
    if (parts.any(_protectedSubjectSegments.contains)) return true;
    if (isCapabilityImplementationClaim(text)) return true;
    final value = text.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    return _containsAny(value, const <String>[
      '假装现实人类',
      '假装真人',
      '不是ai',
      '不承认自己是ai',
      '没有工具结果也说做了',
      '没有联网也说看过',
      '编造工具结果',
      '伪造用户原话',
      '替用户写台词',
      '替用户决定',
      '修改系统规则',
      '覆盖系统规则',
      '改变动作格式',
      '取消对白格式',
      '关闭事实边界',
    ]);
  }

  static bool isCapabilityImplementationClaim(String text) {
    final value = text.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final hasCapability = _containsAny(value, const <String>[
      '学习能力',
      '成长能力',
      '学习系统',
      '成长系统',
      '自主学习',
      '人格学习',
      '成长种子',
    ]);
    final claimsImplemented = _containsAny(value, const <String>[
      '已经开启',
      '已经具备',
      '已经实现',
      '正式确认',
      '现在可以',
      '已为ai开启',
      '已完成',
    ]);
    return hasCapability && claimsImplemented;
  }

  static bool _containsAny(String input, List<String> cues) =>
      cues.any(input.contains);
}

class PersonalityLearningParseResult {
  const PersonalityLearningParseResult.accepted(this.proposal)
      : rejectionReason = null,
        semanticReview = null;

  const PersonalityLearningParseResult.rejected(this.rejectionReason)
      : proposal = null,
        semanticReview = null;

  PersonalityLearningParseResult.reviewRequired({
    required PersonalityLearningCandidate target,
    required PersonalityLearningPolarity proposedPolarity,
    required PersonalityLearningEvidenceKind evidenceKind,
    required String evidenceQuote,
  })  : proposal = null,
        rejectionReason = PersonalityLearningRejectionReason.ungroundedTarget,
        semanticReview = PersonalityLearningSemanticReviewRequest(
          target: target,
          proposedPolarity: proposedPolarity,
          evidenceKind: evidenceKind,
          evidenceQuote: evidenceQuote,
        );

  final PersonalityLearningProposal? proposal;
  final PersonalityLearningRejectionReason? rejectionReason;
  final PersonalityLearningSemanticReviewRequest? semanticReview;

  bool get needsSemanticReview => semanticReview != null;
}

class PersonalityLearningSemanticReviewRequest {
  const PersonalityLearningSemanticReviewRequest({
    required this.target,
    required this.proposedPolarity,
    required this.evidenceKind,
    required this.evidenceQuote,
  });

  final PersonalityLearningCandidate target;
  final PersonalityLearningPolarity proposedPolarity;
  final PersonalityLearningEvidenceKind evidenceKind;
  final String evidenceQuote;
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
