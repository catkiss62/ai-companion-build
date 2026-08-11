import '../models/relationship_event.dart';
import '../models/thought.dart';

/// User-facing projection of the durable Relationship + Thought truth sources.
///
/// This layer deliberately contains no new relationship score/state. It only
/// turns existing durable data into companion-facing language and filters out
/// diagnostic/transient sources that do not belong on the daily relationship UI.
class CompanionCareView {
  const CompanionCareView({
    required this.id,
    required this.label,
    required this.text,
    required this.updatedAt,
    required this.source,
    this.topicKey = '',
  });

  final String id;
  final String label;
  final String text;
  final DateTime updatedAt;
  final String source;
  final String topicKey;
}

class RelationshipMomentView {
  const RelationshipMomentView({
    required this.id,
    required this.kind,
    required this.label,
    required this.summary,
    required this.createdAt,
  });

  final String id;
  final String kind;
  final String label;
  final String summary;
  final DateTime createdAt;
}

class RelationshipPresentation {
  const RelationshipPresentation._();

  static List<CompanionCareView> currentCares(
    Iterable<CompanionThought> thoughts, {
    int limit = 3,
  }) {
    final result = <CompanionCareView>[];
    final seen = <String>{};

    for (final thought in thoughts) {
      if (result.length >= limit) break;
      if (!thought.canDriveIntent || thought.isSnoozed) continue;
      if (!_isCompanionFacingSource(thought.source)) continue;

      final text = _cleanThoughtText(thought.text);
      if (text.isEmpty) continue;
      final dedupe = thought.topicKey.trim().isNotEmpty
          ? 'topic:${thought.topicKey.trim().toLowerCase()}'
          : 'text:${_normalizeForDedupe(text)}';
      if (!seen.add(dedupe)) continue;

      result.add(
        CompanionCareView(
          id: thought.id,
          label: _careLabel(thought.source),
          text: text,
          updatedAt: thought.updatedAt,
          source: thought.source,
          topicKey: thought.topicKey,
        ),
      );
    }
    return result;
  }

  static List<RelationshipMomentView> sharedMoments(
    Iterable<RelationshipEvent> events, {
    int limit = 12,
  }) {
    final result = <RelationshipMomentView>[];
    final seen = <String>{};
    for (final event in events) {
      if (result.length >= limit) break;
      final summary = event.summary.trim();
      if (summary.isEmpty) continue;
      final key = '${event.kind}|${_normalizeForDedupe(summary)}';
      if (!seen.add(key)) continue;
      result.add(
        RelationshipMomentView(
          id: event.id,
          kind: event.kind,
          label: relationshipKindLabel(event.kind),
          summary: summary,
          createdAt: event.createdAt,
        ),
      );
    }
    return result;
  }

  static String relationshipKindLabel(String kind) => switch (kind) {
        'closeness' => '靠近彼此',
        'trust' => '建立信任',
        'conflict' => '发生摩擦',
        'repair' => '重新靠近',
        'promise' => '你们的约定',
        'milestone' => '重要的一刻',
        'intimacy' => '亲密经历',
        'boundary' => '认真记住的边界',
        'roleplay' => '一起经历的场景',
        'support' => '彼此支持',
        'shared_discovery' => '一起发现',
        _ => '共同经历',
      };

  static String sessionKindLabel(String kind) => switch (kind) {
        'roleplay' => '角色扮演',
        'intimacy' => '亲密互动',
        'roleplay_intimacy' => '亲密角色扮演',
        _ => '临时互动',
      };

  static bool sameDisplayText(String left, String right) =>
      _normalizeForDedupe(left) == _normalizeForDedupe(right);

  static bool _isCompanionFacingSource(String source) {
    if (source.startsWith('perception/')) return false;
    if (source.startsWith('self_reflection_run:')) return false;
    return source.startsWith('relationship/') ||
        source == 'self_drive/thread' ||
        source == 'self_drive/memory' ||
        source.startsWith('conversation_turn:') ||
        source == 'deferred_followup';
  }

  static String _careLabel(String source) {
    if (source == 'self_drive/thread' || source == 'deferred_followup') {
      return '她还惦记着';
    }
    if (source == 'self_drive/memory') return '她最近又想起';
    if (source.startsWith('relationship/promise')) return '她把这个约定放在心上';
    if (source.startsWith('relationship/conflict')) return '她还在消化';
    if (source.startsWith('relationship/repair')) return '她记得你们重新靠近';
    if (source.startsWith('relationship/boundary')) return '她认真记着';
    if (source.startsWith('relationship/milestone')) return '她觉得这是重要的一刻';
    if (source.startsWith('relationship/intimacy')) return '她还记得这份亲密';
    if (source.startsWith('relationship/')) return '她还放在心上';
    return '她现在在意';
  }

  static String _cleanThoughtText(String raw) {
    var text = raw.trim();
    const prefixes = <String>[
      '我还惦记着这件没结束的事：',
      '我自己又想起了一条长期记忆：',
      '这件事对我们的关系有一点持续影响：',
      '我还在消化这次关系摩擦：',
      '我记得我们刚刚修复/缓和了这件事：',
      '我把这个约定放在心上：',
      '这条边界/约定需要我认真记住：',
      '这像是我们关系里的一个节点：',
      '这次亲密经历留下了关系上的余韵：',
    ];
    for (final prefix in prefixes) {
      if (text.startsWith(prefix)) {
        text = text.substring(prefix.length).trim();
        break;
      }
    }
    return text;
  }

  static String _normalizeForDedupe(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'''[，。！？、；：,.!?;:\-—_~…·“”"'（）()\[\]{}]'''), '');
}
