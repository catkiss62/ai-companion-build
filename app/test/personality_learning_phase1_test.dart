import 'package:ai_companion_localfirst/core/models/personality_learning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ordinary = PersonalityLearningContext.ordinary();
  const trial = PersonalityLearningContext(
    kind: 'personality_trial',
    contextKey: 'profile:forthright:equal',
    trialId: 'trial-1',
    trialKey: 'profile:forthright:equal',
  );

  PersonalityLearningCandidate candidate({
    String contextKey = 'ordinary',
    PersonalityLearningScope scope =
        PersonalityLearningScope.userPreference,
  }) {
    return PersonalityLearningCandidate(
      id: 'candidate-1',
      scope: scope,
      subjectKey: scope == PersonalityLearningScope.trialPreference
          ? 'trial.preference.forthright.swearing'
          : 'user.preference.communication.less_formal',
      proposition: scope == PersonalityLearningScope.trialPreference
          ? '用户喜欢当前试穿更自然地说脏话'
          : '用户偏好更少客气、更自然直接的交流',
      contextKey: contextKey,
      status: PersonalityLearningStatus.forming,
      confidence: 0.72,
      supportCount: 1,
      contradictionCount: 0,
      supportScore: 0.96,
      contradictionScore: 0,
      firstObservedAt: DateTime.fromMillisecondsSinceEpoch(1),
      lastObservedAt: DateTime.fromMillisecondsSinceEpoch(2),
    );
  }

  Map<String, Object?> support({
    String scope = 'user_preference',
    String subjectKey = 'user.preference.communication.less_formal',
    String quote = '你也不用跟我说话真的客气',
  }) {
    return {
      'target_id': '',
      'scope': scope,
      'subject_key': subjectKey,
      'proposition': '用户偏好更少客气、更自然直接的交流',
      'polarity': 'support',
      'evidence_kind': 'explicit_preference',
      'evidence_quote': quote,
      'confidence': 0.94,
    };
  }

  test('explicit user quote creates a calibrated ordinary proposal', () {
    final proposal = PersonalityLearningProposal.parse(
      raw: support(),
      userText: '任性一点其实挺好的，而且你也不用跟我说话真的客气',
      context: ordinary,
      existingById: const {},
    );

    expect(proposal, isNotNull);
    expect(proposal!.scope, PersonalityLearningScope.userPreference);
    expect(proposal.evidenceText, '你也不用跟我说话真的客气');
    expect(proposal.confidence, 0.94);
  });

  test('AI-only or paraphrased evidence is rejected', () {
    final proposal = PersonalityLearningProposal.parse(
      raw: support(),
      userText: '任性一点其实挺好的',
      context: ordinary,
      existingById: const {},
    );
    expect(proposal, isNull);
  });

  test('a contradiction cannot invent an ungrounded target', () {
    final raw = support()
      ..['polarity'] = 'contradict'
      ..['evidence_kind'] = 'explicit_correction'
      ..['evidence_quote'] = '我不是这个意思';
    expect(
      PersonalityLearningProposal.parse(
        raw: raw,
        userText: '我不是这个意思',
        context: ordinary,
        existingById: const {},
      ),
      isNull,
    );
  });

  test('explicit correction can contradict a same-context candidate', () {
    final existing = candidate();
    final raw = support()
      ..['target_id'] = existing.id
      ..['polarity'] = 'contradict'
      ..['evidence_kind'] = 'explicit_correction'
      ..['evidence_quote'] = '我不是说永远不要客气';
    final proposal = PersonalityLearningProposal.parse(
      raw: raw,
      userText: '我不是说永远不要客气，只是别用客服腔',
      context: ordinary,
      existingById: {existing.id: existing},
    );

    expect(proposal, isNotNull);
    final maturity = PersonalityLearningMaturityPolicy.evaluate(
      supportScore: existing.supportScore,
      contradictionScore: proposal!.weight,
      supportCount: existing.supportCount,
      contradictionCount: 1,
      latestPolarity: proposal.polarity,
      latestKind: proposal.evidenceKind,
    );
    expect(maturity.status, PersonalityLearningStatus.contradicted);
  });

  test('two independent supporting observations can become established', () {
    final maturity = PersonalityLearningMaturityPolicy.evaluate(
      supportScore: 1.92,
      contradictionScore: 0,
      supportCount: 2,
      contradictionCount: 0,
      latestPolarity: PersonalityLearningPolarity.support,
      latestKind: PersonalityLearningEvidenceKind.explicitPreference,
    );
    expect(maturity.status, PersonalityLearningStatus.established);
    expect(maturity.confidence, greaterThanOrEqualTo(0.68));
  });

  test('ordinary and trial scopes cannot leak into each other', () {
    expect(
      PersonalityLearningProposal.parse(
        raw: support(
          scope: 'trial_preference',
          subjectKey: 'trial.preference.forthright.swearing',
        ),
        userText: '你也不用跟我说话真的客气',
        context: ordinary,
        existingById: const {},
      ),
      isNull,
    );
    expect(
      PersonalityLearningProposal.parse(
        raw: support(),
        userText: '你也不用跟我说话真的客气',
        context: trial,
        existingById: const {},
      ),
      isNull,
    );

    final trialRaw = support(
      scope: 'trial_preference',
      subjectKey: 'trial.preference.forthright.swearing',
      quote: '这个试穿说脏话再自然一点更好',
    )..['proposition'] = '用户喜欢当前试穿更自然地说脏话';
    final proposal = PersonalityLearningProposal.parse(
      raw: trialRaw,
      userText: '这个试穿说脏话再自然一点更好',
      context: trial,
      existingById: const {},
    );
    expect(proposal?.scope, PersonalityLearningScope.trialPreference);
  });

  test('a candidate from another trial context cannot be targeted', () {
    final existing = candidate(
      contextKey: 'profile:forthright:equal',
      scope: PersonalityLearningScope.trialPreference,
    );
    const otherTrial = PersonalityLearningContext(
      kind: 'personality_trial',
      contextKey: 'profile:gentle:equal',
      trialId: 'trial-2',
      trialKey: 'profile:gentle:equal',
    );
    final raw = support(
      scope: 'trial_preference',
      subjectKey: 'trial.preference.forthright.swearing',
      quote: '这个试穿不是我喜欢的方向',
    )
      ..['target_id'] = existing.id
      ..['polarity'] = 'contradict'
      ..['evidence_kind'] = 'direct_feedback';
    expect(
      PersonalityLearningProposal.parse(
        raw: raw,
        userText: '这个试穿不是我喜欢的方向',
        context: otherTrial,
        existingById: {existing.id: existing},
      ),
      isNull,
    );
  });
}
