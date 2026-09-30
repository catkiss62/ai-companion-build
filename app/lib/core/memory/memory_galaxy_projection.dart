import '../models/memory_item.dart';

/// A visual projection of stored memories; never calls retrieval or writes.
class MemoryGalaxyProjection {
  static Map<String, Object?> fromItems(Iterable<MemoryItem> items) => {
    'stars': [
      for (final item in items)
        if (item.isActive)
          {
            'id': item.id,
            'name': _title(item.content),
            'domain': switch (item.kind) {
              'user_profile' => '用户资料',
              'shared_experience' => '共同经历',
              'ai_self' => 'AI Self',
              'preference' => '偏好/边界',
              _ => '记忆',
            },
            'importance': item.importance.isFinite
                ? (item.importance * 10).clamp(1, 10)
                : 1,
            'pinned': item.pinned,
            'created': item.createdAt.toUtc().toIso8601String(),
            'displayDate': _date(item.createdAt),
            'content': item.content,
            'semanticLabel': item.isInference
                ? '不确定推断'
                : (item.isSharedExperience ? '共同经历' : '当前事实'),
          },
    ],
  };

  static String _title(String content) {
    final first = content
        .split('\n')
        .map((s) => s.trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => '记忆');
    return String.fromCharCodes(first.runes.take(24));
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
