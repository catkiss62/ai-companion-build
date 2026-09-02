import 'package:ai_companion_localfirst/core/desire/self_drive_engine.dart';
import 'package:ai_companion_localfirst/core/models/proactive_topic_feedback_policy.dart';
import 'package:ai_companion_localfirst/core/models/personality_learning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('self-review fingerprints ignore maintenance timestamps by design', () {
    final first = SelfReviewSourceFingerprint.thread(
      id: 'thread-1',
      topicKey: 'topic.one',
      title: '同一件事',
      detail: '语义没有变化',
      status: 'active',
    );
    final same = SelfReviewSourceFingerprint.thread(
      id: 'thread-1',
      topicKey: 'topic.one',
      title: '同一件事',
      detail: '语义没有变化',
      status: 'active',
    );
    final changed = SelfReviewSourceFingerprint.thread(
      id: 'thread-1',
      topicKey: 'topic.one',
      title: '同一件事',
      detail: '语义已经实质变化',
      status: 'active',
    );
    expect(first, same);
    expect(changed, isNot(first));

    final memoryV1 = SelfReviewSourceFingerprint.memory(
      id: 'memory-1',
      factVersion: 1,
      content: '同一条记忆',
    );
    final memoryV2 = SelfReviewSourceFingerprint.memory(
      id: 'memory-1',
      factVersion: 2,
      content: '同一条记忆',
    );
    expect(memoryV2, isNot(memoryV1));
  });

  test('explicit repetition complaints override topic engagement', () {
    for (final text in <String>[
      '你好像一直在念叨这些事',
      '怎么又是这个话题，翻来覆去的',
      '别再反复说这个了，像复读机一样',
    ]) {
      expect(
        ProactiveTopicFeedbackPolicy.isRepetitionComplaint(text),
        isTrue,
        reason: text,
      );
    }
    for (final text in <String>[
      '你没有一直念叨，我只是顺口提到',
      '这个话题挺有意思的，可以继续',
    ]) {
      expect(
        ProactiveTopicFeedbackPolicy.isRepetitionComplaint(text),
        isFalse,
        reason: text,
      );
    }
  });

  test('v44 keeps evidence but separates colloquial and agency dimensions', () {
    final colloquial = PersonalityLearningEvidenceRepairPolicy.v44Target(
      evidenceText: '我希望你说话更口语化些，不用每件事都解释清楚',
      candidateScope: 'user_preference',
      candidateSubject: 'user.preference.communication.familiarity',
    );
    expect(
      colloquial?.subjectKey,
      'user.preference.communication.colloquial_concise',
    );

    final agency = PersonalityLearningEvidenceRepairPolicy.v44Target(
      evidenceText: '你应该有自己的想法，你累了就可以不回，别只照着我说的做',
      candidateScope: 'user_preference',
      candidateSubject: 'user.preference.communication.familiarity',
    );
    expect(
      agency?.subjectKey,
      'relationship.permission.initiative.self_directed',
    );

    final familiarity = PersonalityLearningEvidenceRepairPolicy.v44Target(
      evidenceText: '越熟悉越不客套，互相斗嘴和说脏话也很可爱',
      candidateScope: 'user_preference',
      candidateSubject: 'user.preference.communication.familiarity',
    );
    expect(familiarity, isNull);
  });
}
