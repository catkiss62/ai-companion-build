import 'package:ai_companion_localfirst/core/memory/memory_grounding_policy.dart';
import 'package:ai_companion_localfirst/core/models/memory_item.dart';
import 'package:flutter_test/flutter_test.dart';

MemoryItem _memory({
  String content = '用户正在调整 AI 的 Live2D 模型的呆毛动画',
  String kind = 'user_profile',
  String semanticType = 'current_fact',
  String actorKey = 'unknown',
  String relationKey = '',
  String objectKey = '',
  String ownerKey = 'unknown',
  String temporalScope = 'unknown',
  DateTime? observedAt,
}) {
  final time = observedAt ?? DateTime.utc(2026, 8, 31, 2);
  return MemoryItem(
    id: 'memory-1',
    kind: kind,
    content: content,
    importance: 0.8,
    createdAt: time,
    updatedAt: time,
    lastEvidenceAt: time,
    semanticType: semanticType,
    actorKey: actorKey,
    relationKey: relationKey,
    objectKey: objectKey,
    ownerKey: ownerKey,
    temporalScope: temporalScope,
  );
}

void main() {
  test('legacy ongoing memory becomes last-known state instead of now', () {
    final rendered = MemoryGroundingPolicy.formatForPrompt(
      _memory(),
      now: DateTime.utc(2026, 9, 4, 17),
    );

    expect(rendered, contains('actor=user'));
    expect(rendered, contains('owner=ai'));
    expect(rendered, contains('temporal=last_known_ongoing'));
    expect(rendered, contains('age_days=4'));
    expect(rendered, contains('current_status=unknown'));
    expect(rendered, contains('禁止改写成“现在/刚才仍在做”'));
    expect(rendered, contains('AI 的 Live2D 模型的呆毛'));
  });

  test('structured entity binding keeps actor object and owner together', () {
    final rendered = MemoryGroundingPolicy.formatForPrompt(
      _memory(
        actorKey: 'user',
        relationKey: 'develops',
        objectKey: 'ai.live2d_model.ahoge',
        ownerKey: 'ai',
        temporalScope: 'ongoing',
      ),
      now: DateTime.utc(2026, 9, 4, 17),
    );

    expect(rendered, contains('actor=user'));
    expect(rendered, contains('relation=develops'));
    expect(rendered, contains('object=ai.live2d_model.ahoge'));
    expect(rendered, contains('owner=ai'));
  });

  test('recalled thought preserves original evidence time', () {
    final rendered = MemoryGroundingPolicy.recalledThoughtText(
      _memory(temporalScope: 'ongoing'),
      now: DateTime.utc(2026, 9, 4, 17),
    );

    expect(rendered, contains('2026-08-31'));
    expect(rendered, contains('当前是否仍在继续未知'));
    expect(rendered, isNot(contains('刚才')));
  });

  test('unresolved thread does not prove that old progress is current', () {
    final note = MemoryGroundingPolicy.threadTemporalNote(
      DateTime.utc(2026, 8, 31, 2),
      now: DateTime.utc(2026, 9, 4, 17),
    );

    expect(note, contains('unresolved_only=true'));
    expect(note, contains('age_days=4'));
    expect(note, contains('不证明'));
  });
}
