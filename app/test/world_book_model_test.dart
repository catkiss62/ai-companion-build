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

    expect(byId.keys, containsAll(<String>{
      'builtin.worldbook.natural_dialogue',
      'builtin.worldbook.inference_engine',
      'builtin.worldbook.daily_conversation',
      'builtin.worldbook.personality_spectrum',
      'builtin.worldbook.humor',
    }));
    final daily = byId['builtin.worldbook.daily_conversation']!;
    expect(daily.manualActive, isTrue);
    expect(daily.probability, 100);
    expect(daily.priority, 900);
    expect(worldBookBehaviorPriorityPlanV04141, {
      '角色表达自然化': 1000,
      '推演思维引擎': 950,
      '日常对话规则': 900,
      '性格光谱': 850,
      '造梗能力': 650,
    });
    expect(daily.content, contains('【日常对话边界】'));
    expect(daily.content, contains('【幽默】'));
    expect(daily.content, contains('不解释笑点'));
    expect(daily.content, contains('【动作与神态】'));
    expect(
      byId['builtin.worldbook.natural_dialogue']!.content,
      contains('# 自然对话总则'),
    );
    expect(byId['builtin.worldbook.natural_dialogue']!.priority, 1000);
    expect(
      byId['builtin.worldbook.natural_dialogue']!.content,
      startsWith('#角色思考方式真人化'),
    );
    final inference = byId['builtin.worldbook.inference_engine']!;
    expect(inference.priority, 950);
    expect(inference.scope, 'immersive');
    expect(inference.activationMode, 'always');
    expect(inference.content, startsWith('【推演思维引擎】'));
    expect(
      byId['builtin.worldbook.personality_spectrum']!.content,
      contains('性格光谱一句话印象'),
    );
    expect(byId['builtin.worldbook.personality_spectrum']!.priority, 850);
    expect(
      byId['builtin.worldbook.humor']!.content,
      contains('【造梗与抽象表达】'),
    );
    expect(byId['builtin.worldbook.humor']!.manualActive, isTrue);
    expect(byId['builtin.worldbook.humor']!.priority, 650);
    expect(byId['builtin.worldbook.humor']!.probability, 30);
    expect(
      byId['builtin.worldbook.humor']!.content,
      contains('这不是第二次触发概率，也不代表命中后必须造梗'),
    );
    expect(
      byId['builtin.worldbook.humor']!.content,
      contains('NSFW时不要造梗和抽象'),
    );
    expect(worldBookSystemPresets, hasLength(5));
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
