import 'package:ai_companion_localfirst/core/models/reference_document.dart';
import 'package:ai_companion_localfirst/core/reference/world_book_presets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('world-book row keeps activation controls separate', () {
    final document = ReferenceDocument.fromDb({
      'id': 'behavior.humor',
      'name': '幽默',
      'kind': 'behavior',
      'raw_content': '顺手拐一下，不解释笑点。',
      'aliases': '造梗|玩笑',
      'enabled': 1,
      'entry_type': 'behavior',
      'activation_mode': 'manual',
      'priority': 200,
      'activation_probability': 20,
      'scope': 'chat|proactive',
      'manual_active': 1,
      'exclusive_group': '',
      'builtin': 0,
      'created_at': 1,
      'updated_at': 2,
    });

    expect(document.isBehavior, isTrue);
    expect(document.priority, 200);
    expect(document.activationProbability, 20);
    expect(document.manualActive, isTrue);
    expect(document.aliases, ['造梗', '玩笑']);
  });

  test('system presets keep persona optional and experiments editable', () {
    final byId = {for (final preset in worldBookSystemPresets) preset.id: preset};

    expect(byId.keys, contains('builtin.worldbook.daily_conversation'));
    final daily = byId['builtin.worldbook.daily_conversation']!;
    expect(daily.manualActive, isTrue);
    expect(daily.probability, 100);
    expect(daily.content, contains('【日常对话边界】'));
    expect(daily.content, contains('【幽默】'));
    expect(daily.content, contains('不解释笑点'));
    expect(daily.content, contains('【动作与神态】'));
    expect(worldBookSystemPresets, hasLength(1));
  });

  test('roleplay is a first-class entry type, not a behavior module', () {
    final document = ReferenceDocument.fromDb({
      'id': 'builtin.worldbook.special.slime',
      'name': '特殊 · 史莱姆',
      'kind': 'roleplay',
      'raw_content': '临时扮演内容',
      'aliases': '史莱姆',
      'enabled': 1,
      'entry_type': 'roleplay',
      'activation_mode': 'manual',
      'priority': 620,
      'activation_probability': 100,
      'scope': 'all',
      'manual_active': 1,
      'exclusive_group': 'worldbook_roleplay',
      'builtin': 1,
      'created_at': 1,
      'updated_at': 2,
    });

    expect(document.isRoleplay, isTrue);
    expect(document.isBehavior, isFalse);
    expect(document.isKnowledge, isFalse);
  });
}
