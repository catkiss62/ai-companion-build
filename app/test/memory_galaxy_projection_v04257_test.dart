import 'dart:convert';

import 'package:ai_companion_localfirst/core/memory/memory_galaxy_projection.dart';
import 'package:ai_companion_localfirst/core/models/memory_item.dart';
import 'package:flutter_test/flutter_test.dart';

MemoryItem _item(
  String id, {
  String content = '曾经的记忆',
  String status = 'active',
  String kind = 'shared_experience',
  double importance = 0.5,
  bool pinned = false,
}) => MemoryItem(
  id: id,
  kind: kind,
  content: content,
  importance: importance,
  createdAt: DateTime.parse('2026-09-30T21:00:00+08:00'),
  updatedAt: DateTime.utc(2026, 10, 1),
  status: status,
  pinned: pinned,
  tags: const ['回忆'],
  recallCount: 19,
  lastRecalledAt: DateTime.utc(2026, 9, 29),
  retentionScore: 0.63,
  topicKey: 'shared.trip',
);

List<Map<String, Object?>> _stars(Iterable<MemoryItem> items) =>
    (MemoryGalaxyProjection.fromItems(items)['stars'] as List)
        .cast<Map<String, Object?>>();

void main() {
  test(
    'empty or inactive memory collections remain empty without examples',
    () {
      expect(_stars(const []), isEmpty);
      expect(
        _stars([
          _item('archived', status: 'archived'),
          _item('superseded', status: 'superseded'),
        ]),
        isEmpty,
      );
    },
  );

  test('every active memory is projected beyond 300 without sampling or state changes', () {
    final items = List<MemoryItem>.unmodifiable([
      for (var index = 0; index < 640; index++) _item('active$index'),
      _item('archived', status: 'archived'),
      _item('superseded', status: 'superseded'),
    ]);
    final originalItems = [...items];
    final before = [
      for (final item in items)
        [
          item.content,
          item.importance,
          item.pinned,
          item.recallCount,
          item.lastRecalledAt,
          item.retentionScore,
          item.topicKey,
          [...item.tags],
        ],
    ];
    final stars = _stars(items);
    expect(stars, hasLength(640));
    expect(stars.map((star) => star['id']), [
      for (var index = 0; index < 640; index++) 'active$index',
    ]);
    expect(items, originalItems);
    for (var index = 0; index < items.length; index++) {
      expect(identical(items[index], originalItems[index]), true);
    }
    expect([
      for (final item in items)
        [
          item.content,
          item.importance,
          item.pinned,
          item.recallCount,
          item.lastRecalledAt,
          item.retentionScore,
          item.topicKey,
          [...item.tags],
        ],
    ], before);
  });

  test('raw HTML NUL quotes emoji and whitespace survive private JSON projection exactly', () {
    const raw =
        '  <img src=x onerror="window.injected=1">😀\u0000\n'
        '第二行 </script> & \\n 尾部  ';
    final original = _item('raw', content: raw, pinned: true);
    final projected = MemoryGalaxyProjection.fromItems([original]);
    final encoded = jsonEncode(projected);
    expect(encoded, contains(r'\u0000'));
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    final star = (decoded['stars'] as List).single as Map<String, dynamic>;
    expect(star['content'], raw);
    expect(star['pinned'], true);
    expect(star['domain'], '共同经历');
    expect(
      DateTime.parse(star['created'] as String),
      original.createdAt.toUtc(),
    );
    final local = original.createdAt.toLocal();
    expect(
      star['displayDate'],
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}',
    );
    expect(original.content, raw);
    expect(original.recallCount, 19);
  });

  test('brightness clamps invalid importance and titles avoid broken emoji code units', () {
    final stars = _stars([
      for (final value in [
        -10.0,
        0.0,
        0.75,
        1.0,
        20.0,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ])
        _item('i$value', importance: value),
      _item('empty', content: ' \n\t\n'),
      _item('emoji', content: '\n  ${List.filled(30, '😀').join()}\n正文'),
      _item('unknown', kind: 'legacy_kind'),
    ]);
    expect(stars.take(8).map((star) => star['importance']), [
      1,
      1,
      7.5,
      10,
      10,
      1,
      1,
      1,
    ]);
    expect(stars[8]['name'], '记忆');
    expect(stars[9]['name'], List.filled(24, '😀').join());
    expect(stars[10]['domain'], '记忆');
    expect(jsonDecode(jsonEncode({'stars': stars})), isA<Map>());
  });
}
