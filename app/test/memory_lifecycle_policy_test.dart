import 'package:ai_companion_localfirst/core/memory/memory_lifecycle_policy.dart';
import 'package:ai_companion_localfirst/core/models/memory_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MemoryLifecyclePolicy explicit state language', () {
    test('accepts an explicit completion report', () {
      expect(
        MemoryLifecyclePolicy.isExplicitCompletion('已经做好了，你忘了吗'),
        isTrue,
      );
      expect(
        MemoryLifecyclePolicy.isExplicitDeferral('已经做好了，你忘了吗'),
        isFalse,
      );
    });

    test('does not invert a negated completion report', () {
      expect(MemoryLifecyclePolicy.isExplicitCompletion('还没做好'), isFalse);
      expect(MemoryLifecyclePolicy.isExplicitDeferral('还没做好'), isTrue);
    });

    test('does not treat a completion question as a completion report', () {
      expect(MemoryLifecyclePolicy.isExplicitCompletion('你做好了吗？'), isFalse);
      expect(MemoryLifecyclePolicy.isExplicitCompletion('是不是已经完成了'), isFalse);
    });

    test('keeps an explicit postponement deferred', () {
      expect(MemoryLifecyclePolicy.isExplicitCompletion('以后再弄'), isFalse);
      expect(MemoryLifecyclePolicy.isExplicitDeferral('以后再弄'), isTrue);
    });

    test('recognizes cancellation separately from completion', () {
      expect(MemoryLifecyclePolicy.isExplicitCancellation('这个不做了'), isTrue);
      expect(MemoryLifecyclePolicy.isExplicitCompletion('这个不做了'), isFalse);
    });
  });

  group('MemoryLifecyclePolicy recall lanes', () {
    test('a meaningful finished shared experience may become reminiscence', () {
      final result = MemoryLifecyclePolicy.derive(
        kind: 'shared_experience',
        semanticType: 'shared_experience',
        temporalScope: 'event',
        content: '我们一起完成了 AI 的 Live2D 呆毛设计',
        importance: 0.88,
      );

      expect(result.factState, 'completed');
      expect(result.attentionState, 'closed');
      expect(result.recallPolicy, 'reminiscence');
      expect(result.spontaneousSalience, greaterThanOrEqualTo(0.68));
    });

    test('routine work stays contextual even when important', () {
      final result = MemoryLifecyclePolicy.derive(
        kind: 'user_profile',
        semanticType: 'current_fact',
        temporalScope: 'ongoing',
        content: '用户正在执行数据库维护工作',
        importance: 0.95,
      );

      expect(result.factState, 'ongoing');
      expect(result.attentionState, 'snoozed');
      expect(result.recallPolicy, 'contextual');
      expect(result.spontaneousSalience, 0.0);
    });

    test('a durable user hobby may seed identity recall', () {
      final result = MemoryLifecyclePolicy.derive(
        kind: 'preference',
        semanticType: 'current_fact',
        temporalScope: 'stable',
        content: '用户的爱好是玩剧情游戏',
        importance: 0.84,
      );

      expect(result.factState, 'stable');
      expect(result.recallPolicy, 'identity');
      expect(result.spontaneousSalience, greaterThanOrEqualTo(0.68));
    });

    test('local meaning gate rejects a model-proposed work reminiscence', () {
      final result = MemoryLifecyclePolicy.derive(
        kind: 'user_profile',
        semanticType: 'current_fact',
        temporalScope: 'ongoing',
        content: '用户正在处理数据库迁移工作',
        importance: 0.98,
        proposedAttentionState: 'closed',
        proposedRecallPolicy: 'reminiscence',
        proposedSpontaneousSalience: 0.99,
      );

      expect(result.recallPolicy, 'contextual');
      expect(result.spontaneousSalience, 0.0);
    });

    test('only a live thread grants the follow-up lane', () {
      final active = MemoryLifecyclePolicy.derive(
        kind: 'user_profile',
        semanticType: 'current_fact',
        temporalScope: 'ongoing',
        content: '用户正在制作模型',
        importance: 0.7,
        proposedRecallPolicy: 'followup',
        hasActiveThread: true,
      );
      final stale = MemoryLifecyclePolicy.derive(
        kind: 'user_profile',
        semanticType: 'current_fact',
        temporalScope: 'ongoing',
        content: '用户正在制作模型',
        importance: 0.7,
        proposedRecallPolicy: 'followup',
        hasActiveThread: false,
      );

      expect((active.attentionState, active.recallPolicy), ('active', 'followup'));
      expect((stale.attentionState, stale.recallPolicy), ('snoozed', 'contextual'));
    });

    test('completed facts cannot remain active follow-ups', () {
      final result = MemoryLifecyclePolicy.derive(
        kind: 'shared_experience',
        semanticType: 'shared_experience',
        temporalScope: 'event',
        content: '已经完成了共同项目',
        importance: 0.8,
        proposedAttentionState: 'active',
        proposedRecallPolicy: 'followup',
        hasActiveThread: true,
      );

      expect(result.factState, 'completed');
      expect(result.attentionState, 'closed');
      expect(result.recallPolicy, 'contextual');
      expect(result.spontaneousSalience, 0.0);
    });

    test('a stale legacy ongoing fact becomes unknown without a live thread', () {
      final now = DateTime(2026, 9, 5);
      final observed = now.subtract(const Duration(days: 20));
      final item = MemoryItem(
        id: 'stale-work',
        kind: 'user_profile',
        content: '用户正在做一项工作',
        importance: 0.9,
        createdAt: observed,
        updatedAt: observed,
        temporalScope: 'ongoing',
        lastEvidenceAt: observed,
      );

      final result = MemoryLifecyclePolicy.forLegacy(item, now: now);

      expect(result.factState, 'unknown');
      expect(result.attentionState, 'snoozed');
      expect(result.recallPolicy, 'contextual');
    });
  });
}
