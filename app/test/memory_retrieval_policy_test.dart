import 'package:flutter_test/flutter_test.dart';

import 'package:ai_companion_localfirst/core/memory/memory_retrieval_policy.dart';
import 'package:ai_companion_localfirst/core/models/memory_item.dart';

MemoryItem memory({
  required String content,
  String kind = 'user_profile',
  String semanticType = 'current_fact',
  bool pinned = false,
  DateTime? lastRecalledAt,
  DateTime? lastExpressedAt,
  double importance = 0.95,
}) {
  final now = DateTime(2026, 8, 24, 12);
  return MemoryItem(
    id: content,
    kind: kind,
    content: content,
    importance: importance,
    confidence: 0.96,
    createdAt: now.subtract(const Duration(days: 30)),
    updatedAt: now.subtract(const Duration(days: 1)),
    pinned: pinned,
    lastRecalledAt: lastRecalledAt,
    lastExpressedAt: lastExpressedAt,
    semanticType: semanticType,
  );
}

void main() {
  final now = DateTime(2026, 8, 24, 12);

  test('unrelated importance and pinning never manufacture relevance', () {
    final unrelated = MemoryRetrievalPolicy.evaluate(
      query: '刚看完一部科幻电影，想聊聊结局',
      item: memory(
        content: '用户昨晚明确说很想我',
        pinned: true,
        importance: 1,
      ),
      now: now,
    );

    expect(unrelated.direct, isFalse);
    expect(unrelated.cooldownBlocked, isFalse);
    expect(unrelated.reason, anyOf('no_direct_seed', 'ambiguous_single_overlap'));
  });

  test('a concrete topic token provides a direct seed', () {
    final result = MemoryRetrievalPolicy.evaluate(
      query: '说说音乐吧',
      item: memory(content: '用户平时喜欢古典音乐'),
      now: now,
    );

    expect(result.direct, isTrue);
    expect(result.cooldownBlocked, isFalse);
    expect(result.overlapCount, greaterThanOrEqualTo(1));
  });

  test('generic affection overlap does not recall a different preference', () {
    final result = MemoryRetrievalPolicy.evaluate(
      query: '我最近很喜欢猫',
      item: memory(content: '用户明确说喜欢我'),
      now: now,
    );

    expect(result.direct, isFalse);
    expect(result.reason, 'ambiguous_single_overlap');
  });

  test('recent weak match cools down but explicit topic can break through', () {
    final recentlyUsed = memory(
      content: '用户喜欢古典音乐',
      lastRecalledAt: now.subtract(const Duration(minutes: 10)),
    );
    final weak = MemoryRetrievalPolicy.evaluate(
      query: '刚看了一部电影，顺便聊聊音乐和画面吧',
      item: recentlyUsed,
      now: now,
    );
    final explicit = MemoryRetrievalPolicy.evaluate(
      query: '继续说古典音乐',
      item: recentlyUsed,
      now: now,
    );

    expect(weak.direct, isTrue);
    expect(weak.cooldownBlocked, isTrue);
    expect(explicit.direct, isTrue);
    expect(explicit.strongEvidence, isTrue);
    expect(explicit.cooldownBlocked, isFalse);
  });

  test('visible expression cursor also participates in cooldown', () {
    final result = MemoryRetrievalPolicy.evaluate(
      query: '刚才那部电影让我想到音乐',
      item: memory(
        content: '用户喜欢古典音乐',
        lastExpressedAt: now.subtract(const Duration(minutes: 20)),
      ),
      now: now,
    );

    expect(result.direct, isTrue);
    expect(result.cooldownBlocked, isTrue);
  });

  test('summary and unfinished-thread text use the same direct gate', () {
    expect(
      MemoryRetrievalPolicy.hasDirectTextEvidence(
        '我们继续讨论 APK 下载',
        '上次停在 APK 下载地址失效的排查',
      ),
      isTrue,
    );
    expect(
      MemoryRetrievalPolicy.hasDirectTextEvidence(
        '我们继续讨论 APK 下载',
        '用户昨天说很想她',
      ),
      isFalse,
    );
  });
}
