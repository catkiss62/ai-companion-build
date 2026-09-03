import 'package:ai_companion_localfirst/core/ai/dialogue_expression_plan.dart';
import 'package:ai_companion_localfirst/core/diagnostics/dialogue_expression_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light chat stays short, spoken-only and deterministically routed', () {
    final first = DialogueExpressionPlan.select(
      latestUserText: '我就是抖M',
      turnKey: 'message-42',
    );
    final replay = DialogueExpressionPlan.select(
      latestUserText: '我就是抖M',
      turnKey: 'message-42',
    );

    expect(first.mode, DialogueResponseMode.casual);
    expect(first.humor, replay.humor);
    expect(first.selectionSeed, replay.selectionSeed);
    expect(first.render(), contains('一至三个口语句'));
    expect(first.render(), contains('只输出说出口的话'));
    expect(first.render(), contains('不输出动作、神态、语气说明、镜头或旁白'));
    expect(first.render(), contains('不强迫追加问题'));
  });

  test('technical and deep turns may expand without humor pressure', () {
    final task = DialogueExpressionPlan.select(
      latestUserText: '帮我排查这个数据库报错，给出修复步骤',
      turnKey: 'task-1',
    );
    final deep = DialogueExpressionPlan.select(
      latestUserText: '我想认真聊聊我们的关系和未来',
      turnKey: 'deep-1',
    );

    expect(task.mode, DialogueResponseMode.task);
    expect(task.humor, DialogueHumorDevice.none);
    expect(task.render(), contains('正确完整优先'));
    expect(deep.mode, DialogueResponseMode.deep);
    expect(deep.humor, DialogueHumorDevice.none);
    expect(deep.render(), contains('允许按内容自然变长'));
  });

  test('sensitive content suppresses jokes but not directness', () {
    final plan = DialogueExpressionPlan.select(
      latestUserText: '我现在胸痛而且呼吸困难',
      turnKey: 'risk-1',
    );

    expect(plan.mode, DialogueResponseMode.sensitive);
    expect(plan.humor, DialogueHumorDevice.none);
    expect(plan.render(), contains('别拿痛苦本身造梗'));
    expect(plan.render(), contains('必要信息说全'));
  });

  test('humor devices never claim control over facts or tasks', () {
    for (var i = 0; i < 64; i += 1) {
      final plan = DialogueExpressionPlan.select(
        latestUserText: '你猜我刚刚干了什么',
        turnKey: 'casual-$i',
      );
      final prompt = plan.render();
      expect(prompt, contains('不改写事实'));
      expect(prompt, contains('不虚构共同经历'));
      expect(prompt, contains('不替代任务答案'));
    }
  });

  test('telemetry stores counters without conversation or prompt bodies', () {
    final first = DialogueExpressionTelemetry.nextSnapshot(
      raw: null,
      mode: 'casual',
      humor: 'meaningSwerve',
      now: DateTime.fromMillisecondsSinceEpoch(1000),
    );
    final second = DialogueExpressionTelemetry.nextSnapshot(
      raw: '{"modeCounts":{"casual":1},"humorCounts":{"meaningSwerve":1}}',
      mode: 'task',
      humor: 'none',
      now: DateTime.fromMillisecondsSinceEpoch(2000),
    );

    expect((first['modeCounts']! as Map)['casual'], 1);
    expect((first['humorCounts']! as Map)['meaningSwerve'], 1);
    expect((second['modeCounts']! as Map)['task'], 1);
    expect((second['humorCounts']! as Map)['none'], 1);
    expect(second['lastAt'], 2000);
    expect(second['userTextIncluded'], isFalse);
    expect(second['promptBodiesIncluded'], isFalse);
    expect(second['generatedTextIncluded'], isFalse);
    expect(second['reasoningIncluded'], isFalse);
    expect(second['messageIdsIncluded'], isFalse);
  });
}
