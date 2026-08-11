import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/models/reference_item.dart';

void main() {
  test('reference item stays explicitly separate from durable memory', () {
    final item = ReferenceItem.fromDb({
      'id': 'r1',
      'source_name': 'index',
      'section': 'persona_reference',
      'title': '性格',
      'content': '偶尔说英文',
      'tags': '语言|参考',
      'weight': 0.62,
      'enabled': 1,
      'created_at': 1000,
      'updated_at': 2000,
    });
    expect(item.sourceName, 'index');
    expect(item.enabled, isTrue);
    expect(item.tags, contains('参考'));
  });
}
