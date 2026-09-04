import '../models/memory_item.dart';

class TopicAssociationPolicy {
  const TopicAssociationPolicy._();

  static final RegExp _valid = RegExp(r'^[a-z0-9][a-z0-9_.-]{1,95}$');

  /// Keeps only a stable, bounded hierarchy. Free-form memory text is never
  /// converted into an association key.
  static String normalize(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (!_valid.hasMatch(value)) return '';
    return value;
  }

  static String fromSubject(String? subjectKey) {
    final subject = normalize(subjectKey);
    if (subject.isEmpty) return '';
    final parts = subject.split('.').where((part) => part.isNotEmpty).toList();
    if (parts.length < 2) return '';
    return parts.take(parts.length >= 4 ? 3 : parts.length).join('.');
  }

  static String resolve({String? explicit, String? subjectKey}) {
    final proposed = normalize(explicit);
    final subject = normalize(subjectKey);
    if (proposed.isNotEmpty && subject.isNotEmpty) {
      final root = subject.split('.').take(2).join('.');
      if (proposed == root || proposed.startsWith('$root.')) return proposed;
    }
    return fromSubject(subject);
  }

  static List<MemoryItem> selectAssociated({
    required List<MemoryItem> directSeeds,
    required Iterable<MemoryItem> candidates,
    int limit = 3,
    bool Function(MemoryItem item)? blocked,
  }) {
    final topics = directSeeds
        .map((item) => item.topicKey)
        .where((topic) => topic.isNotEmpty)
        .toSet();
    if (topics.isEmpty || limit <= 0) return const <MemoryItem>[];
    final seedIds = directSeeds.map((item) => item.id).toSet();
    final admitted = candidates
        .where((item) =>
            !seedIds.contains(item.id) &&
            item.isActive &&
            topics.contains(item.topicKey) &&
            !(blocked?.call(item) ?? false))
        .toList();
    admitted.sort((left, right) {
      final leftScore = left.importance * 0.45 +
          left.confidence * 0.30 +
          left.retentionScore * 0.25;
      final rightScore = right.importance * 0.45 +
          right.confidence * 0.30 +
          right.retentionScore * 0.25;
      return rightScore.compareTo(leftScore);
    });
    return admitted.take(limit.clamp(0, 3).toInt()).toList(growable: false);
  }
}
