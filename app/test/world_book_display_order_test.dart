import 'package:ai_companion_localfirst/core/models/reference_document.dart';
import 'package:ai_companion_localfirst/core/reference/world_book_display_order.dart';
import 'package:flutter_test/flutter_test.dart';

ReferenceDocument _document(String id, String name) => ReferenceDocument(
      id: id,
      name: name,
      kind: 'behavior',
      rawContent: name,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
    );

void main() {
  test('special styles appear after personality and relationship posture', () {
    final special = _document('builtin.worldbook.special.playful', '特殊');
    final knowledge = _document('custom.knowledge', '知识');
    final personality =
        _document('builtin.worldbook.personality.gentle', '性格');
    final posture = _document('builtin.worldbook.posture.equal', '相处');
    final arranged = WorldBookDisplayOrder.arrange(
      <ReferenceDocument>[special, knowledge, personality, posture],
    );
    expect(
      arranged.map((item) => item.id),
      <String>[
        knowledge.id,
        personality.id,
        posture.id,
        special.id,
      ],
    );
  });
}
