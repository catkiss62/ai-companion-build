import 'package:ai_companion_localfirst/core/models/relationship_event.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';
import 'package:ai_companion_localfirst/core/relationship/relationship_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

CompanionThought thought({
  required String id,
  required String text,
  required String source,
  String topicKey = '',
  String lifecycle = 'active',
  DateTime? snoozedUntil,
}) {
  final now = DateTime(2026, 8, 11, 15);
  return CompanionThought(
    id: id,
    text: text,
    driveKey: 'attachment',
    kind: 'flit',
    strength: 0.8,
    bornAt: now.subtract(const Duration(days: 2)),
    updatedAt: now,
    source: source,
    lifecycleState: lifecycle,
    topicKey: topicKey,
    snoozedUntil: snoozedUntil,
  );
}

void main() {
  test('daily relationship cares hide raw perception thoughts', () {
    final cares = RelationshipPresentation.currentCares([
      thought(
        id: 'perception',
        text: '他最近有一段时间主要在进行游戏相关的活动。',
        source: 'perception/awareness',
      ),
      thought(
        id: 'promise',
        text: '我把这个约定放在心上：今晚回来继续聊。',
        source: 'relationship/promise',
        topicKey: 'promise:tonight',
      ),
    ]);

    expect(cares, hasLength(1));
    expect(cares.single.label, contains('约定'));
    expect(cares.single.text, '今晚回来继续聊。');
  });

  test('snoozed and non-driving thoughts stay out of companion-facing view', () {
    final cares = RelationshipPresentation.currentCares([
      thought(
        id: 'snoozed',
        text: '先不提这件事',
        source: 'conversation_turn:m1',
        snoozedUntil: DateTime.now().add(const Duration(hours: 2)),
      ),
      thought(
        id: 'dormant',
        text: '旧念头',
        source: 'relationship/closeness',
        lifecycle: 'dormant',
      ),
    ]);
    expect(cares, isEmpty);
  });

  test('topic key prevents duplicate relationship themes', () {
    final cares = RelationshipPresentation.currentCares([
      thought(
        id: 'a',
        text: '第一种说法',
        source: 'conversation_turn:m1',
        topicKey: 'same-topic',
      ),
      thought(
        id: 'b',
        text: '第二种说法',
        source: 'relationship/closeness',
        topicKey: 'same-topic',
      ),
    ]);
    expect(cares, hasLength(1));
  });

  test('shared moments expose labels and summaries without numeric scores', () {
    final event = RelationshipEvent(
      id: 'e1',
      kind: 'repair',
      summary: '你们把昨晚的误会说开了。',
      intensity: 0.94,
      valence: 0.72,
      createdAt: DateTime(2026, 8, 11),
    );
    final moments = RelationshipPresentation.sharedMoments([event]);
    expect(moments.single.label, '重新靠近');
    expect(moments.single.summary, contains('误会'));
  });
}
