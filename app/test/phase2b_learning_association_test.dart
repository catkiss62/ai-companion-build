import 'package:ai_companion_localfirst/core/memory/personality_learning_prompt_policy.dart';
import 'package:ai_companion_localfirst/core/memory/phase2b_consolidation_engine.dart';
import 'package:ai_companion_localfirst/core/memory/topic_association_policy.dart';
import 'package:ai_companion_localfirst/core/models/personality_learning.dart';
import 'package:ai_companion_localfirst/core/models/memory_item.dart';
import 'package:flutter_test/flutter_test.dart';

PersonalityLearningCandidate _candidate({
  PersonalityLearningStatus status = PersonalityLearningStatus.established,
  PersonalityLearningScope scope = PersonalityLearningScope.relationshipPermission,
  int supports = 2,
  int contradictions = 0,
  double confidence = 0.92,
  String subject = 'relationship.permission.communication.banter',
  String proposition = '熟悉后可以少客套、自然斗嘴，但仍尊重当下边界',
  String context = 'ordinary',
}) {
  final now = DateTime(2026, 9, 4, 1);
  return PersonalityLearningCandidate(
    id: subject,
    scope: scope,
    subjectKey: subject,
    topicKey: TopicAssociationPolicy.fromSubject(subject),
    proposition: proposition,
    contextKey: context,
    status: status,
    confidence: confidence,
    supportCount: supports,
    contradictionCount: contradictions,
    supportScore: supports.toDouble(),
    contradictionScore: contradictions.toDouble(),
    firstObservedAt: now,
    lastObservedAt: now,
  );
}

MemoryItem _memory(String id, String topic, {double importance = 0.6}) {
  final now = DateTime(2026, 9, 4, 1);
  return MemoryItem(
    id: id,
    kind: 'user_profile',
    content: 'memory $id',
    importance: importance,
    createdAt: now,
    updatedAt: now,
    subjectKey: '$topic.item_$id',
    topicKey: topic,
  );
}

void main() {
  group('stable one-layer topics', () {
    test('derives only a bounded stable hierarchy', () {
      expect(
        TopicAssociationPolicy.fromSubject(
          'relationship.permission.communication.banter',
        ),
        'relationship.permission.communication',
      );
      expect(TopicAssociationPolicy.fromSubject('freeform'), isEmpty);
      expect(TopicAssociationPolicy.fromSubject('用户 喜欢 玩梗'), isEmpty);
    });

    test('rejects an explicit topic outside the subject root', () {
      expect(
        TopicAssociationPolicy.resolve(
          explicit: 'ai.self.identity',
          subjectKey: 'user.preference.communication.direct',
        ),
        'user.preference.communication',
      );
    });

    test('does not expand without a direct topic seed', () {
      expect(
        TopicAssociationPolicy.selectAssociated(
          directSeeds: const <MemoryItem>[],
          candidates: [_memory('a', 'user.work')],
        ),
        isEmpty,
      );
    });

    test('expands only the same topic and never more than three', () {
      final selected = TopicAssociationPolicy.selectAssociated(
        directSeeds: [_memory('seed', 'user.work')],
        candidates: [
          _memory('1', 'user.work', importance: 0.1),
          _memory('2', 'user.work', importance: 0.9),
          _memory('3', 'user.work', importance: 0.8),
          _memory('4', 'user.work', importance: 0.7),
          _memory('other', 'user.sleep', importance: 1.0),
        ],
        limit: 9,
      );
      expect(selected, hasLength(3));
      expect(selected.map((item) => item.id), ['2', '3', '4']);
    });
  });

  group('mature learning prompt gate', () {
    test('admits a mature uncontradicted ordinary preference at low weight', () {
      final result = PersonalityLearningPromptPolicy.select(
        candidates: [_candidate()],
        query: '今天说话别那么客套，来斗嘴',
      );
      expect(result.candidates, hasLength(1));
      expect(result.formatForPrompt(), contains('低权重倾向'));
      expect(result.formatForPrompt(), contains('不得由此伪造用户原话'));
    });

    test('blocks forming, contradicted and trial candidates', () {
      final result = PersonalityLearningPromptPolicy.select(
        candidates: [
          _candidate(status: PersonalityLearningStatus.forming),
          _candidate(contradictions: 1),
          _candidate(
            scope: PersonalityLearningScope.trialPreference,
            context: 'trial:1',
          ),
        ],
        query: '斗嘴',
      );
      expect(result.isEmpty, isTrue);
    });

    test('never selects more than two candidates', () {
      final result = PersonalityLearningPromptPolicy.select(
        candidates: [
          _candidate(subject: 'relationship.permission.communication.one'),
          _candidate(subject: 'relationship.permission.communication.two'),
          _candidate(subject: 'relationship.permission.communication.three'),
        ],
        query: '沟通时自然一点，少客套',
      );
      expect(result.candidates.length, lessThanOrEqualTo(2));
    });
  });

  test('local consolidation runs only at night or after 90 minutes idle', () {
    final noon = DateTime(2026, 9, 4, 12);
    expect(
      Phase2BConsolidationEngine.scheduleEligible(
        now: noon,
        lastUserMessageAt: noon.subtract(const Duration(minutes: 20)),
      ),
      isFalse,
    );
    expect(
      Phase2BConsolidationEngine.scheduleEligible(
        now: noon,
        lastUserMessageAt: noon.subtract(const Duration(minutes: 90)),
      ),
      isTrue,
    );
    expect(
      Phase2BConsolidationEngine.scheduleEligible(
        now: DateTime(2026, 9, 4, 2),
        lastUserMessageAt: DateTime(2026, 9, 4, 1, 50),
      ),
      isTrue,
    );
  });
}
