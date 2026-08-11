import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/reference/reference_import_parser.dart';

void main() {
  test('index-like json imports persona fields but ignores chat history', () {
    final items = ReferenceImportParser().parse(
      raw: '''{
        "persona": {"name":"Yuki", "personality":"偶尔夹杂英文"},
        "messages": [{"content":"这段聊天不应导入"}],
        "reasoning":"也不应导入"
      }''',
      mode: 'json',
    );
    expect(items.any((e) => e.content.contains('偶尔夹杂英文')), isTrue);
    expect(items.any((e) => e.content.contains('这段聊天不应导入')), isFalse);
    expect(items.any((e) => e.content.contains('也不应导入')), isFalse);
  });

  test('plain text becomes bounded reference chunks', () {
    final items = ReferenceImportParser().parse(
      raw: '说话风格\n偶尔使用英语短句。\n\n偏好\n喜欢安静的夜晚。',
      mode: 'text',
    );
    expect(items.length, 2);
    expect(items.first.section, 'speaking_style');
  });
}
