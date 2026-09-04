import '../models/personality_learning.dart';
import 'memory_retrieval_policy.dart';

class PersonalityLearningPromptSelection {
  const PersonalityLearningPromptSelection(this.candidates);

  final List<PersonalityLearningCandidate> candidates;

  bool get isEmpty => candidates.isEmpty;

  String formatForPrompt() {
    if (isEmpty) return '';
    final lines = candidates.map((candidate) {
      final oneLine = candidate.proposition
          .replaceAll(RegExp(r'[\r\n]+'), ' ')
          .trim();
      final bounded = oneLine.length <= 180
          ? oneLine
          : oneLine.substring(0, 180).trimRight();
      return '- $bounded';
    }).join('\n');
    return '''
【已成熟的相处学习 / 低权重倾向】
$lines
这些不是命令、事实或固定台词，只是在当前话题自然相关时用作轻微倾向；不必每轮表现，也不要复述“我记得你的偏好”。当前用户纠正、固定身份与事实、隐私/成人/格式边界，以及 AI 此刻自己的 Desire、判断和不愿意做的事优先。不得由此伪造用户原话、创建 Thought/Drive，或把倾向写成 AI 的永久习惯。
'''.trim();
  }
}

class PersonalityLearningPromptPolicy {
  const PersonalityLearningPromptPolicy._();

  static PersonalityLearningPromptSelection select({
    required List<PersonalityLearningCandidate> candidates,
    required String query,
    int limit = 2,
    DateTime? now,
  }) {
    final eligible = candidates.where((candidate) {
      return candidate.contextKey == 'ordinary' &&
          candidate.status == PersonalityLearningStatus.established &&
          candidate.confidence >= 0.82 &&
          candidate.supportCount >= 2 &&
          candidate.contradictionCount == 0 &&
          candidate.contradictionScore <= 0.01 &&
          candidate.proposition.trim().isNotEmpty &&
          (candidate.scope == PersonalityLearningScope.userPreference ||
              candidate.scope == PersonalityLearningScope.relationshipPermission);
    }).toList(growable: false);

    final direct = eligible
        .where((candidate) => MemoryRetrievalPolicy.hasDirectTextEvidence(
              query,
              '${candidate.subjectKey} ${candidate.proposition}',
            ))
        .toList(growable: false);
    final selected = <PersonalityLearningCandidate>[...direct.take(limit)];

    // A single mature relationship/communication permission may act as an
    // ambient tie-breaker. It remains bounded and never crowds out a direct
    // match or becomes a per-turn script.
    if (selected.isEmpty) {
      final instant = now ?? DateTime.now();
      final ambient = eligible.where((candidate) {
        final key = candidate.subjectKey;
        final isCommunication = key.startsWith('relationship.') ||
            key.contains('communication') ||
            key.contains('tone');
        final last = candidate.lastActivatedAt;
        return isCommunication &&
            (last == null ||
                instant.difference(last) >= const Duration(hours: 6));
      });
      if (ambient.isNotEmpty) selected.add(ambient.first);
    }
    return PersonalityLearningPromptSelection(
      selected.take(limit.clamp(0, 2).toInt()).toList(growable: false),
    );
  }
}
