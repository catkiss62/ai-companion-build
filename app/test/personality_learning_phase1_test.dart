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
    String id = 'candidate-1',
    String contextKey = 'ordinary',
    PersonalityLearningScope scope =
        PersonalityLearningScope.userPreference,
    String? subjectKey,
    String? proposition,
  }) {
    return PersonalityLearningCandidate(
      id: id,
      scope: scope,
      subjectKey: subjectKey ??
          (scope == PersonalityLearningScope.trialPreference
              ? 'trial.preference.forthright.swearing'
              : 'user.preference.communication.less_formal'),
      proposition: proposition ??
          (scope == PersonalityLearningScope.trialPreference
              ? '用户喜欢当前试穿更自然地说脏话'
              : '用户偏好更少客气、更自然直接的交流'),
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

  test('true-device same-direction support rejoins one grounded candidate', () {
    final existing = candidate(
      subjectKey: 'user.preference.communication.familiar_informal',
      proposition: '用户偏好越熟悉越自然的交流方式，用调侃或不客气表达亲近。',
    );
    final userText =
        '那不会的，我真的喜欢这种真正自然而然的关系，而不是刻意的甜蜜，这种越熟说话越不客气的感觉很好。';
    final raw = support(
      subjectKey: 'user.preference.relationship.natural_closeness',
      quote: userText,
    )..['proposition'] = '用户喜欢熟悉以后自然放松、不必维持客套';

    final parsed = PersonalityLearningProposal.parseDetailed(
      raw: raw,
      userText: userText,
      context: ordinary,
      existingById: {existing.id: existing},
    );

    expect(parsed.rejectionReason, isNull);
    expect(parsed.proposal?.targetCandidateId, existing.id);
    expect(parsed.proposal?.subjectKey, existing.subjectKey);
  });

  test('related but distinct preference does not collapse into one candidate', () {
    final existing = candidate(
      subjectKey: 'user.preference.activity.beach_walking',
      proposition: '用户喜欢在海边散步。',
    );
    final raw = support(
      subjectKey: 'user.preference.activity.beach_photography',
      quote: '我喜欢在海边拍照',
    )..['proposition'] = '用户喜欢在海边拍照。';

    final parsed = PersonalityLearningProposal.parseDetailed(
      raw: raw,
      userText: '我喜欢在海边拍照',
      context: ordinary,
      existingById: {existing.id: existing},
    );

    expect(parsed.rejectionReason, isNull);
    expect(parsed.proposal?.targetCandidateId, isNull);
    expect(
      parsed.proposal?.subjectKey,
      'user.preference.activity.beach_photography',
    );
  });

  test('true-device pacing reply cannot borrow the AI context target', () {
    final existing = candidate(
      subjectKey: 'user.preference.communication.familiar_informal',
      proposition: '用户偏好越熟悉越自然的交流方式，用调侃或不客气表达亲近。',
    );
    final raw = support(quote: '慢慢来最好，我们时间还长着，不急')
      ..['target_id'] = existing.id;

    final parsed = PersonalityLearningProposal.parseDetailed(
      raw: raw,
      userText: '慢慢来最好，我们时间还长着，不急',
      context: ordinary,
      existingById: {existing.id: existing},
    );

    expect(parsed.proposal, isNull);
    expect(
      parsed.rejectionReason,
      PersonalityLearningRejectionReason.ungroundedTarget,
    );

    final withoutTarget = Map<String, Object?>.from(raw)
      ..['target_id'] = ''
      ..['subject_key'] = existing.subjectKey;
    final reparsed = PersonalityLearningProposal.parseDetailed(
      raw: withoutTarget,
      userText: '慢慢来最好，我们时间还长着，不急',
      context: ordinary,
      existingById: {existing.id: existing},
    );
    expect(reparsed.proposal, isNull);
    expect(
      reparsed.rejectionReason,
      PersonalityLearningRejectionReason.ungroundedTarget,
    );

    final asNewPacingPreference = Map<String, Object?>.from(raw)
      ..['target_id'] = ''
      ..['subject_key'] = 'user.preference.relationship.pacing'
      ..['proposition'] = '用户偏好让关系慢慢成长，不急于发生变化';
    final newSubjectParsed = PersonalityLearningProposal.parseDetailed(
      raw: asNewPacingPreference,
      userText: '慢慢来最好，我们时间还长着，不急',
      context: ordinary,
      existingById: {existing.id: existing},
    );
    expect(newSubjectParsed.proposal, isNull);
    expect(
      newSubjectParsed.rejectionReason,
      PersonalityLearningRejectionReason.contextOnlyReply,
    );

    final genericPermission = Map<String, Object?>.from(asNewPacingPreference)
      ..['evidence_quote'] = '可以，慢慢来';
    final genericPermissionParsed = PersonalityLearningProposal.parseDetailed(
      raw: genericPermission,
      userText: '可以，慢慢来',
      context: ordinary,
      existingById: {existing.id: existing},
    );
    expect(genericPermissionParsed.proposal, isNull);
    expect(
      genericPermissionParsed.rejectionReason,
      PersonalityLearningRejectionReason.contextOnlyReply,
    );
  });

  test('an explicit first-person pacing preference remains learnable', () {
    final raw = support(
      subjectKey: 'user.preference.relationship.pacing',
      quote: '我更喜欢关系慢慢来，不要一下子改变太多',
    )..['proposition'] = '用户偏好关系逐步变化，不要突然改变太多';

    final parsed = PersonalityLearningProposal.parseDetailed(
      raw: raw,
      userText: '我更喜欢关系慢慢来，不要一下子改变太多',
      context: ordinary,
      existingById: const {},
    );

    expect(parsed.rejectionReason, isNull);
    expect(parsed.proposal?.subjectKey, 'user.preference.relationship.pacing');
  });

  test('pacing elsewhere in the turn does not hide a separate preference', () {
    final raw = support(
      subjectKey: 'user.preference.communication.playful_stubbornness',
      quote: '我希望你偶尔更任性一点',
    )..['proposition'] = '用户喜欢 AI 偶尔更任性地表达自己';

    final parsed = PersonalityLearningProposal.parseDetailed(
      raw: raw,
      userText: '慢慢来就好；另外，我希望你偶尔更任性一点。',
      context: ordinary,
      existingById: const {},
    );

    expect(parsed.rejectionReason, isNull);
    expect(
      parsed.proposal?.subjectKey,
      'user.preference.communication.playful_stubbornness',
    );
  });

  test('explicit direct feedback keeps a model-selected target', () {
    final existing = candidate();
    final raw = support(quote: '你刚才那句滚去睡觉挺有意思的')
      ..['target_id'] = existing.id
      ..['evidence_kind'] = 'direct_feedback';

    final parsed = PersonalityLearningProposal.parseDetailed(
      raw: raw,
      userText: '你刚才那句滚去睡觉挺有意思的',
      context: ordinary,
      existingById: {existing.id: existing},
    );

    expect(parsed.rejectionReason, isNull);
    expect(parsed.proposal?.targetCandidateId, existing.id);
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
