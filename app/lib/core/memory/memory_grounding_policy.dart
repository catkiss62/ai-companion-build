import '../models/memory_item.dart';

/// Bounded entity/time grounding for durable memories.
///
/// This is deliberately smaller than a knowledge graph. Structured keys keep
/// actor, object and ownership attached to a fact, while [lastEvidenceAt]
/// remains the authority for when an ongoing state was last confirmed.
class MemoryGroundingPolicy {
  const MemoryGroundingPolicy._();

  static const Set<String> actorKeys = <String>{
    'user',
    'ai',
    'shared',
    'external',
    'unknown',
  };
  static const Set<String> ownerKeys = actorKeys;
  static const Set<String> temporalScopes = <String>{
    'stable',
    'ongoing',
    'event',
    'scheduled',
    'unknown',
  };

  static final RegExp _ongoingLanguage = RegExp(
    r'(正在|还在|继续|当前在|目前在|眼下在|最近在|着手|调试中|制作中|开发中|等待中)',
    caseSensitive: false,
  );
  static final RegExp _scheduledLanguage = RegExp(
    r'(计划|准备|打算|预计|约定|明天|今晚|稍后|晚点|之后会)',
    caseSensitive: false,
  );

  static String normalizeEntityKey(
    String? value, {
    String fallback = 'unknown',
  }) {
    final normalized = (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._/-]'), '');
    if (normalized.isEmpty) return fallback;
    return normalized.length <= 80 ? normalized : normalized.substring(0, 80);
  }

  static String normalizeActor(String? value) {
    final normalized = normalizeEntityKey(value);
    return actorKeys.contains(normalized) ? normalized : 'unknown';
  }

  static String normalizeOwner(String? value) {
    final normalized = normalizeEntityKey(value);
    return ownerKeys.contains(normalized) ? normalized : 'unknown';
  }

  static String normalizeTemporalScope(String? value) {
    final normalized = normalizeEntityKey(value);
    return temporalScopes.contains(normalized) ? normalized : 'unknown';
  }

  static String effectiveTemporalScope(MemoryItem item) {
    final stored = normalizeTemporalScope(item.temporalScope);
    if (stored != 'unknown') return stored;
    if (item.isSharedExperience) return 'event';
    if (_ongoingLanguage.hasMatch(item.content)) return 'ongoing';
    if (_scheduledLanguage.hasMatch(item.content)) return 'scheduled';
    if (item.kind == 'user_profile' ||
        item.kind == 'preference' ||
        item.kind == 'ai_self') {
      return 'stable';
    }
    return 'unknown';
  }

  static String effectiveActor(MemoryItem item) {
    final stored = normalizeActor(item.actorKey);
    if (stored != 'unknown') return stored;
    final content = item.content.trim();
    if (content.startsWith('用户')) return 'user';
    if (content.startsWith('AI') || content.startsWith('小鲸鱼')) return 'ai';
    if (item.isSharedExperience) return 'shared';
    return 'unknown';
  }

  static String effectiveOwner(MemoryItem item) {
    final stored = normalizeOwner(item.ownerKey);
    if (stored != 'unknown') return stored;
    final content = item.content;
    if (RegExp(r'(AI|小鲸鱼|她)\s*的.{0,18}(模型|立绘|呆毛|耳鳍|尾巴|形象)',
            caseSensitive: false)
        .hasMatch(content)) {
      return 'ai';
    }
    if (RegExp(r'用户的.{0,18}(设备|手机|平板|电脑|账号|偏好|习惯)')
        .hasMatch(content)) {
      return 'user';
    }
    return 'unknown';
  }

  static String formatForPrompt(
    MemoryItem item, {
    DateTime? now,
  }) {
    final instant = now ?? DateTime.now();
    final scope = effectiveTemporalScope(item);
    final actor = effectiveActor(item);
    final owner = effectiveOwner(item);
    final relation = normalizeEntityKey(item.relationKey, fallback: 'unspecified');
    final object = normalizeEntityKey(item.objectKey, fallback: 'unspecified');
    final entity = <String>[
      'actor=$actor',
      if (relation != 'unspecified') 'relation=$relation',
      if (object != 'unspecified') 'object=$object',
      if (owner != 'unknown') 'owner=$owner',
    ].join('; ');

    final temporal = switch (scope) {
      'ongoing' =>
        'last_known_ongoing; ${_evidenceAge(item.lastEvidenceAt, instant)}; current_status=unknown; 禁止改写成“现在/刚才仍在做”',
      'scheduled' =>
        'last_known_plan; ${_evidenceAge(item.lastEvidenceAt, instant)}; current_status=unknown; 计划不等于已经执行',
      'event' => 'historical_event; ${_evidenceAge(item.lastEvidenceAt, instant)}',
      'stable' => 'stable_fact; last_confirmed=${_date(item.lastEvidenceAt)}',
      _ => 'time_unknown; ${_evidenceAge(item.lastEvidenceAt, instant)}; 不得猜测当前状态',
    };
    return '[MEMORY_GROUNDING $entity; temporal=$temporal] ${item.content}';
  }

  static String threadTemporalNote(DateTime updatedAt, {DateTime? now}) =>
      '[THREAD_GROUNDING unresolved_only=true; ${_evidenceAge(updatedAt, now ?? DateTime.now())}; '
      '未结束只表示值得以后承接，不证明正文中的“正在/当前”此刻仍成立]';

  static String summaryTemporalNote(
    DateTime fromAt,
    DateTime toAt, {
    DateTime? now,
  }) =>
      '[SUMMARY_GROUNDING historical_range=${_date(fromAt)}..${_date(toAt)}; '
      '${_evidenceAge(toAt, now ?? DateTime.now())}; 摘要中的“正在/当前”只属于该历史区间]';

  static String recalledThoughtText(MemoryItem item, {DateTime? now}) {
    final instant = now ?? DateTime.now();
    final scope = effectiveTemporalScope(item);
    final stateBoundary = scope == 'ongoing' || scope == 'scheduled'
        ? '；这是当时最后确认的状态，当前是否仍在继续未知'
        : '';
    return '我现在想起一条在 ${_date(item.lastEvidenceAt)}（${_humanAge(item.lastEvidenceAt, instant)}）留下的长期记忆$stateBoundary：'
        '${item.content}';
  }

  static String thoughtTemporalNote({
    required String provenance,
    required DateTime sourceTime,
    DateTime? now,
  }) {
    final memoryBoundary = provenance == 'memory'
        ? '; memory_recall=true; 想起发生在现在不代表被想起的事件发生在刚才'
        : '';
    return '[THOUGHT_GROUNDING provenance=$provenance; '
        '${_evidenceAge(sourceTime, now ?? DateTime.now())}$memoryBoundary]';
  }

  static String _evidenceAge(DateTime source, DateTime now) {
    final safeNow = now.isBefore(source) ? source : now;
    final minutes = safeNow.difference(source).inMinutes;
    final age = minutes < 60
        ? 'age_minutes=$minutes'
        : minutes < 48 * 60
            ? 'age_hours=${(minutes / 60).floor()}'
            : 'age_days=${(minutes / 1440).floor()}';
    return 'last_evidence=${_date(source)}; $age';
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  static String _humanAge(DateTime source, DateTime now) {
    final minutes = (now.isBefore(source) ? source : now)
        .difference(source)
        .inMinutes;
    if (minutes < 60) return '约 $minutes 分钟前';
    if (minutes < 48 * 60) return '约 ${minutes ~/ 60} 小时前';
    return '约 ${minutes ~/ 1440} 天前';
  }
}
