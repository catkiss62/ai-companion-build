import 'package:ai_companion_localfirst/core/ai/dialogue_expression_plan.dart';
import 'package:ai_companion_localfirst/core/diagnostics/dialogue_expression_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Regression contract: casual guessing and ordinary games do not become task mode.
  test('casual response focus contains no hard humor selector', () {
    final plan = DialogueExpressionPlan.select(
      latestUserText: '哈哈，今天发生了一件离谱的小事',
    );

    expect(plan.mode, DialogueResponseMode.casual);
    expect(plan.render(), contains('【本轮回应重心】'));
    expect(plan.render(), isNot(contains('本轮造梗')));
    expect(plan.render(), isNot(contains('主造法')));
    expect(plan.render(), isNot(contains('谐音变异')));
    expect(plan.render(), isNot(contains('接梗')));
    expect(plan.render(), isNot(contains('加码')));
    expect(plan.render(), isNot(contains('**')));
  });

  test('feedback changes responsibility without forcing a joke', () {
    for (final sample in <String>[
      '没看到哪里造梗',
      '很无聊，你真没有幽默感？',
      '你又开始反问了',
    ]) {
      final plan = DialogueExpressionPlan.select(
        latestUserText: sample,
      );
      expect(plan.mode, DialogueResponseMode.feedback);
      expect(plan.render(), contains('真实反馈'));
      expect(plan.render(), isNot(contains('强制')));
      expect(plan.render(), isNot(contains('造法')));
    }
  });

  test('riddles and explicit creative challenges use quality-first routing', () {
    for (final sample in <String>['我们来玩猜谜吧', '给我出个谜语', '来一道逻辑谜题']) {
      final plan = DialogueExpressionPlan.select(
        latestUserText: sample,
      );
      expect(plan.mode, DialogueResponseMode.challenge);
      expect(plan.render(), contains('内容质量与明确要求是硬标准'));
      expect(plan.render(), contains('题面没有直接暴露答案'));
    }
  });

  test('technical, deep and sensitive turns keep response responsibilities', () {
    final task = DialogueExpressionPlan.select(
      latestUserText: '帮我排查这个数据库报错，给出修复步骤',
    );
    final deep = DialogueExpressionPlan.select(
      latestUserText: '我想认真聊聊我们的关系和未来',
    );
    final sensitive = DialogueExpressionPlan.select(
      latestUserText: '我现在胸痛而且呼吸困难',
    );

    expect(task.mode, DialogueResponseMode.task);
    expect(task.render(), contains('正确完整优先'));
    expect(deep.mode, DialogueResponseMode.deep);
    expect(deep.render(), contains('允许按内容自然变长'));
    expect(sensitive.mode, DialogueResponseMode.sensitive);
    expect(sensitive.render(), contains('必要信息说全'));
  });

  test('legacy humor telemetry is retired to none without storing bodies', () {
    final snapshot = DialogueExpressionTelemetry.nextSnapshot(
      raw: '{"modeCounts":{"casual":1},"humorCounts":{"semanticSwerve":8}}',
      mode: 'task',
      humor: 'semanticSwerve',
      now: DateTime.fromMillisecondsSinceEpoch(2000),
    );

    expect((snapshot['modeCounts']! as Map)['task'], 1);
    expect((snapshot['humorCounts']! as Map)['none'], 1);
    expect(snapshot['lastHumor'], 'none');
    expect(snapshot['userTextIncluded'], isFalse);
    expect(snapshot['promptBodiesIncluded'], isFalse);
    expect(snapshot['generatedTextIncluded'], isFalse);
    expect(snapshot['reasoningIncluded'], isFalse);
    expect(snapshot['messageIdsIncluded'], isFalse);
  });
}
