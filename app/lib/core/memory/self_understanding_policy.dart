import '../models/memory_item.dart';

/// Existing semantic keys identify expression observations. Never infer a
/// personality from the words of an individual generated reply.
class SelfUnderstandingPolicy {
  static bool isExpressionObservation(MemoryItem item) => isExpressionSubject(
    item.kind, item.subjectKey);

  static bool isExpressionSubject(String kind, String subject) {
    if (kind != 'ai_self') return false;
    final parts = subject.toLowerCase().split('.');
    return parts.any(const {
      'communication', 'communication_style', 'care_style', 'expression',
      'expression_style', 'interaction_style', 'speaking_style',
      'conversation_style', 'sensory_playfulness', 'tone',
    }.contains);
  }
}
